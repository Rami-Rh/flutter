import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

import '../../core/errors/failures.dart';
import '../../core/money/money.dart';
import '../../core/quantity/quantity.dart';
import '../../domain/entities/cart_line.dart';
import '../../domain/entities/catalog.dart';
import '../../domain/entities/sale.dart';
import '../../domain/enums/enums.dart';
import '../../domain/repositories/product_repository.dart';
import '../../domain/repositories/sale_repository.dart';
import '../../domain/units/units.dart';
import 'repository_providers.dart';

/// État du **panier** en cours de composition (avant encaissement).
///
/// Les lignes sont des `CartLine` ; le prix unitaire appliqué dépend du mode
/// (détail / gros) et les totaux sont recalculés à chaque modification.
@immutable
class CartState {
  const CartState({
    this.mode = SaleMode.retail,
    this.lines = const <CartLine>[],
    this.discount = Money.zero,
    this.note,
  });

  final SaleMode mode;
  final List<CartLine> lines;

  /// Remise accordée sur le sous-total.
  final Money discount;

  /// Note libre attachée à la vente.
  final String? note;

  bool get isEmpty => lines.isEmpty;
  int get lineCount => lines.length;

  /// Totaux exacts (sous-total, remise, total, coût, bénéfice).
  CartTotals get totals => CartCalculator.compute(lines, discount: discount);

  /// Brouillon transmis au dépôt de ventes lors de l'encaissement.
  SaleDraft toDraft() => SaleDraft(
        mode: mode,
        lines: lines,
        discount: discount,
        note: note,
      );

  CartState copyWith({
    SaleMode? mode,
    List<CartLine>? lines,
    Money? discount,
  }) =>
      CartState(
        mode: mode ?? this.mode,
        lines: lines ?? this.lines,
        discount: discount ?? this.discount,
        note: note,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CartState &&
          other.mode == mode &&
          other.discount == discount &&
          other.note == note &&
          listEquals(other.lines, lines));

  @override
  int get hashCode =>
      Object.hash(mode, discount, note, Object.hashAll(lines));
}

/// Notifier du panier : ajout, modification, mode de vente et remise.
class CartNotifier extends Notifier<CartState> {
  /// Produits mémorisés par identifiant : sert à réévaluer les prix lors d'un
  /// changement de mode et à contrôler le stock disponible.
  final Map<int, Product> _catalog = <int, Product>{};

  @override
  CartState build() {
    _catalog.clear();
    return const CartState();
  }

  /// Produit mémorisé pour une ligne (ou `null` si inconnu).
  Product? productOf(int productId) => _catalog[productId];

  /// Ajoute un produit au panier, en fusionnant avec une ligne identique
  /// (même produit, même conditionnement).
  void addProduct(
    Product product, {
    PackagingUnit packagingUnit = PackagingUnit.base,
    Qty quantity = const Qty.fromMilliUnits(Qty.scale),
  }) {
    final int? id = product.id;
    if (id == null) {
      throw const AppFailure(
        FailureCode.validation,
        debugMessage: 'Produit non enregistré : impossible de le vendre.',
      );
    }
    _catalog[id] = product;
    final CartLine line = product.toCartLine(
      mode: state.mode,
      packagingUnit: packagingUnit,
      quantity: quantity,
    );
    state = state.copyWith(lines: CartCalculator.addOrMerge(state.lines, line));
  }

  /// Change le mode de vente et réévalue le prix unitaire de chaque ligne.
  void setMode(SaleMode mode) {
    final List<CartLine> repriced = state.lines.map((CartLine line) {
      final Product? product = _catalog[line.productId];
      if (product == null) return line;
      return line.copyWith(unitPrice: product.pricing.priceFor(mode));
    }).toList(growable: false);
    state = state.copyWith(mode: mode, lines: repriced);
  }

  /// Modifie une ligne (conditionnement et/ou quantité). Une quantité nulle
  /// retire la ligne.
  void updateLine(
    int index, {
    PackagingUnit? packagingUnit,
    Qty? quantity,
  }) {
    if (index < 0 || index >= state.lines.length) return;
    final List<CartLine> lines = List<CartLine>.of(state.lines);
    CartLine line = lines[index];
    if (packagingUnit != null) {
      line = line.copyWith(packagingUnit: packagingUnit);
    }
    if (quantity != null) {
      line = line.copyWith(quantity: quantity);
    }
    if (line.quantity.isZero) {
      lines.removeAt(index);
    } else {
      lines[index] = line;
    }
    state = state.copyWith(lines: lines);
  }

  /// Incrémente ([direction] > 0) ou décrémente la quantité d'une ligne.
  void stepQuantity(int index, int direction) {
    if (index < 0 || index >= state.lines.length) return;
    final CartLine line = state.lines[index];
    final Qty step = line.packagingUnit == PackagingUnit.base
        ? _stepForBaseUnit(line.packaging.baseUnit)
        : const Qty.fromMilliUnits(Qty.scale);
    final Qty next =
        direction >= 0 ? line.quantity + step : line.quantity - step;
    updateLine(index, quantity: next.isNegative ? Qty.zero : next);
  }

  void removeLine(int index) {
    if (index < 0 || index >= state.lines.length) return;
    final List<CartLine> lines = List<CartLine>.of(state.lines)
      ..removeAt(index);
    state = state.copyWith(lines: lines);
  }

  void setDiscount(Money discount) => state = CartState(
        mode: state.mode,
        lines: state.lines,
        discount: discount.isNegative ? Money.zero : discount,
        note: state.note,
      );

  void setNote(String? note) => state = CartState(
        mode: state.mode,
        lines: state.lines,
        discount: state.discount,
        note: note,
      );

  /// Vide le panier (après encaissement ou abandon).
  void clear() {
    _catalog.clear();
    state = const CartState();
  }
}

/// Pas d'incrémentation selon l'unité de base (1 pièce ou 0,5 kg).
Qty _stepForBaseUnit(StockBaseUnit unit) => switch (unit) {
      StockBaseUnit.piece => const Qty.fromMilliUnits(Qty.scale),
      StockBaseUnit.kilogram => const Qty.fromMilliUnits(Qty.scale ~/ 2),
    };

/// Panier courant de l'application.
final NotifierProvider<CartNotifier, CartState> cartProvider =
    NotifierProvider<CartNotifier, CartState>(
  CartNotifier.new,
  name: 'cartProvider',
);

/// Ventes du jour, mises à jour en temps réel.
final StreamProvider<List<Sale>> todaySalesProvider = StreamProvider<List<Sale>>(
  (Ref ref) => ref.watch(saleRepositoryProvider).watchToday(),
  name: 'todaySalesProvider',
);

/// Produits correspondant à une recherche (ajout au panier), en temps réel.
///
/// Une requête vide renvoie tous les produits actifs.
final saleProductsProvider = StreamProvider.family<List<Product>, String>(
  (Ref ref, String query) {
    final String trimmed = query.trim();
    return ref.watch(productRepositoryProvider).watchAll(
          query: trimmed.isEmpty ? null : trimmed,
        );
  },
  name: 'saleProductsProvider',
);

/// Vente détaillée accompagnée des produits de ses lignes.
///
/// Les lignes de vente ne mémorisent que le conditionnement vendu ; le produit
/// fournit l'unité de base (pièce / kilo) nécessaire à l'affichage.
@immutable
class SaleWithProducts {
  const SaleWithProducts({required this.sale, required this.products});

  final Sale sale;

  /// Produits indexés par identifiant (partiel si un produit a été supprimé
  /// après la vente).
  final Map<int, Product> products;

  Product? productOf(int productId) => products[productId];
}

/// Vente détaillée (lignes incluses) et produits associés, par identifiant.
final FutureProviderFamily<SaleWithProducts?, int> saleDetailProvider =
    FutureProvider.family<SaleWithProducts?, int>(
  (Ref ref, int saleId) async {
    final Sale? sale = await ref.watch(saleRepositoryProvider).getById(saleId);
    if (sale == null) return null;
    final ProductRepository products = ref.watch(productRepositoryProvider);
    final Map<int, Product> catalog = <int, Product>{};
    for (final SaleItem item in sale.items) {
      final Product? product = await products.getById(item.productId);
      if (product != null) catalog[item.productId] = product;
    }
    return SaleWithProducts(sale: sale, products: catalog);
  },
  name: 'saleDetailProvider',
);

/// Point d'entrée unique des écritures de ventes.
final Provider<SaleController> saleControllerProvider =
    Provider<SaleController>(
  SaleController.new,
  name: 'saleControllerProvider',
);

/// Encaissement (avec vidage du panier) et annulation d'une vente.
class SaleController {
  SaleController(this._ref);

  final Ref _ref;

  SaleRepository get _sales => _ref.read(saleRepositoryProvider);

  /// Encaisse le panier : enregistre la vente, déduit le stock puis vide le
  /// panier. Une erreur (ex. stock insuffisant) laisse le panier intact.
  Future<Sale> checkout(SaleDraft draft) async {
    final Sale sale = await _sales.checkout(draft);
    _ref.read(cartProvider.notifier).clear();
    return sale;
  }

  /// Annule une vente : remet automatiquement les articles en stock.
  Future<Sale> cancel(int saleId) => _sales.cancel(saleId);
}
