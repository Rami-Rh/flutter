import 'package:meta/meta.dart';

import '../../core/money/money.dart';
import '../../core/quantity/quantity.dart';
import '../enums/enums.dart';
import '../units/units.dart';

/// Ligne d'un panier de vente (avant validation).
///
/// [quantity] est exprimée dans [packagingUnit] (pièce, carton, kilo ou sac).
/// Les prix [unitPrice] et [unitCost] sont **par unité de base** ; toutes les
/// conversions vers le conditionnement choisi sont automatiques et exactes.
@immutable
class CartLine {
  const CartLine({
    required this.productId,
    required this.productName,
    required this.barcode,
    required this.packaging,
    required this.packagingUnit,
    required this.quantity,
    required this.unitPrice,
    required this.unitCost,
  });

  final int productId;
  final String productName;
  final String barcode;

  final PackagingConfig packaging;
  final PackagingUnit packagingUnit;

  /// Quantité saisie, dans [packagingUnit].
  final Qty quantity;

  /// Prix de vente appliqué, par unité de base.
  final Money unitPrice;

  /// Prix d'achat, par unité de base (sert au calcul du bénéfice).
  final Money unitCost;

  /// Quantité convertie dans l'unité de base (pièce ou kg).
  Qty get baseQuantity =>
      UnitConverter.toBaseUnit(quantity, packagingUnit, packaging);

  /// Quantité décomposée en conditionnements entiers + reste (affichage).
  PackagingBreakdown get breakdown =>
      UnitConverter.breakdown(baseQuantity, packagingUnit, packaging);

  Money get lineTotal => unitPrice.timesQuantity(baseQuantity);
  Money get lineCost => unitCost.timesQuantity(baseQuantity);
  Money get lineProfit => lineTotal - lineCost;

  CartLine copyWith({
    Qty? quantity,
    PackagingUnit? packagingUnit,
    Money? unitPrice,
    Money? unitCost,
  }) =>
      CartLine(
        productId: productId,
        productName: productName,
        barcode: barcode,
        packaging: packaging,
        packagingUnit: packagingUnit ?? this.packagingUnit,
        quantity: quantity ?? this.quantity,
        unitPrice: unitPrice ?? this.unitPrice,
        unitCost: unitCost ?? this.unitCost,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CartLine &&
          other.productId == productId &&
          other.packagingUnit == packagingUnit &&
          other.quantity == quantity &&
          other.unitPrice == unitPrice &&
          other.unitCost == unitCost);

  @override
  int get hashCode =>
      Object.hash(productId, packagingUnit, quantity, unitPrice, unitCost);
}

/// Résultat du calcul d'un panier.
@immutable
class CartTotals {
  const CartTotals({
    required this.subtotal,
    required this.discount,
    required this.total,
    required this.cost,
    required this.profit,
    required this.itemCount,
  });

  /// Somme des lignes avant remise.
  final Money subtotal;

  /// Remise appliquée sur le sous-total.
  final Money discount;

  /// Montant à payer par le client.
  final Money total;

  /// Coût total des marchandises vendues.
  final Money cost;

  /// Bénéfice net de la vente.
  final Money profit;

  /// Nombre de lignes du panier.
  final int itemCount;

  static const CartTotals empty = CartTotals(
    subtotal: Money.zero,
    discount: Money.zero,
    total: Money.zero,
    cost: Money.zero,
    profit: Money.zero,
    itemCount: 0,
  );
}

/// Calcul des totaux d'un panier. Logique **pure** et testable unitairement.
abstract final class CartCalculator {
  static CartTotals compute(
    List<CartLine> lines, {
    Money discount = Money.zero,
  }) {
    final subtotal = Money.sum(lines.map((l) => l.lineTotal));
    final cost = Money.sum(lines.map((l) => l.lineCost));
    final total = subtotal - discount;
    return CartTotals(
      subtotal: subtotal,
      discount: discount,
      total: total,
      cost: cost,
      profit: total - cost,
      itemCount: lines.length,
    );
  }

  /// Fusionne une nouvelle ligne avec une ligne existante du même produit et
  /// du même conditionnement (cas du scan répété du même article).
  static List<CartLine> addOrMerge(List<CartLine> lines, CartLine incoming) {
    final index = lines.indexWhere(
      (l) =>
          l.productId == incoming.productId &&
          l.packagingUnit == incoming.packagingUnit,
    );
    if (index == -1) return <CartLine>[...lines, incoming];
    final merged = List<CartLine>.of(lines);
    final existing = merged[index];
    merged[index] = existing.copyWith(
      quantity: Qty.fromMilliUnits(
        existing.quantity.milliUnits + incoming.quantity.milliUnits,
      ),
      unitPrice: incoming.unitPrice,
      unitCost: incoming.unitCost,
    );
    return merged;
  }
}
