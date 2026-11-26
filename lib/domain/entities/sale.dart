import 'package:meta/meta.dart';

import '../../core/money/money.dart';
import '../../core/quantity/quantity.dart';
import '../enums/enums.dart';
import 'cart_line.dart';

/// Ligne d'une vente enregistrée.
///
/// La quantité est conservée à la fois en **unité de base** ([quantityBase],
/// pour le journal de stock) et dans le **conditionnement vendu**
/// ([quantityInPackaging], pour réimprimer le ticket à l'identique).
@immutable
class SaleItem {
  const SaleItem({
    this.id,
    this.saleId,
    required this.productId,
    required this.packagingUnit,
    required this.quantityBase,
    required this.quantityInPackaging,
    required this.unitPrice,
    required this.unitCost,
    required this.lineTotal,
    required this.lineProfit,
    this.productName,
    this.barcode,
  });

  final int? id;
  final int? saleId;
  final int productId;

  /// Conditionnement réellement vendu (pièce, carton, kilo ou sac).
  final PackagingUnit packagingUnit;

  /// Quantité en unité de base (pièce ou kilo).
  final Qty quantityBase;

  /// Quantité saisie dans [packagingUnit].
  final Qty quantityInPackaging;

  /// Prix de vente appliqué, par unité de base.
  final Money unitPrice;

  /// Coût unitaire, par unité de base.
  final Money unitCost;

  final Money lineTotal;
  final Money lineProfit;

  /// Nom du produit (issu d'une jointure, non stocké sur la ligne).
  final String? productName;

  /// Code-barres du produit (issu d'une jointure, non stocké sur la ligne).
  final String? barcode;

  /// Construit une ligne de vente prête à être enregistrée à partir d'une
  /// ligne de panier.
  factory SaleItem.fromCartLine(CartLine line, {int? saleId}) => SaleItem(
        saleId: saleId,
        productId: line.productId,
        packagingUnit: line.packagingUnit,
        quantityBase: line.baseQuantity,
        quantityInPackaging: line.quantity,
        unitPrice: line.unitPrice,
        unitCost: line.unitCost,
        lineTotal: line.lineTotal,
        lineProfit: line.lineProfit,
        productName: line.productName,
        barcode: line.barcode,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is SaleItem && other.id == id);

  @override
  int get hashCode => id.hashCode;
}

/// Vente validée (ticket).
@immutable
class Sale {
  const Sale({
    this.id,
    required this.date,
    required this.mode,
    required this.subtotal,
    this.discount = Money.zero,
    required this.total,
    required this.totalCost,
    required this.profit,
    this.isCancelled = false,
    this.cancelledAt,
    this.note,
    this.createdAt,
    this.items = const <SaleItem>[],
  });

  /// `null` tant que la vente n'a pas été enregistrée en base.
  final int? id;

  final DateTime date;
  final SaleMode mode;

  /// Somme des lignes avant remise.
  final Money subtotal;
  final Money discount;
  final Money total;
  final Money totalCost;
  final Money profit;

  final bool isCancelled;
  final DateTime? cancelledAt;
  final String? note;
  final DateTime? createdAt;

  /// Lignes de la vente (vides si non chargées).
  final List<SaleItem> items;

  /// Nombre d'articles (lignes) de la vente.
  int get itemCount => items.length;

  /// Quantité totale vendue, en unité de base.
  Qty get totalBaseQuantity =>
      Qty.fromMilliUnits(items.fold(0, (sum, i) => sum + i.quantityBase.milliUnits));

  /// Construit une vente validée à partir des totaux d'un panier.
  factory Sale.fromTotals({
    required DateTime date,
    required SaleMode mode,
    required CartTotals totals,
    List<SaleItem> items = const <SaleItem>[],
    String? note,
  }) =>
      Sale(
        date: date,
        mode: mode,
        subtotal: totals.subtotal,
        discount: totals.discount,
        total: totals.total,
        totalCost: totals.cost,
        profit: totals.profit,
        note: note,
        createdAt: date,
        items: items,
      );

  Sale copyWith({
    int? id,
    bool? isCancelled,
    DateTime? cancelledAt,
    String? note,
    List<SaleItem>? items,
  }) =>
      Sale(
        id: id ?? this.id,
        date: date,
        mode: mode,
        subtotal: subtotal,
        discount: discount,
        total: total,
        totalCost: totalCost,
        profit: profit,
        isCancelled: isCancelled ?? this.isCancelled,
        cancelledAt: cancelledAt ?? this.cancelledAt,
        note: note ?? this.note,
        createdAt: createdAt,
        items: items ?? this.items,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Sale && other.id == id);

  @override
  int get hashCode => id.hashCode;
}

/// Panier prêt à être validé : lignes + remise + mode de vente.
///
/// C'est l'objet transmis au repository de ventes pour un encaissement ; le
/// repository calcule les totaux, enregistre la vente et déduit le stock de
/// façon atomique.
@immutable
class SaleDraft {
  const SaleDraft({
    required this.mode,
    required this.lines,
    this.discount = Money.zero,
    this.note,
    this.date,
  });

  final SaleMode mode;
  final List<CartLine> lines;
  final Money discount;
  final String? note;

  /// Date de la vente (`null` = maintenant).
  final DateTime? date;

  bool get isEmpty => lines.isEmpty;

  CartTotals get totals => CartCalculator.compute(lines, discount: discount);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is SaleDraft && other.lines == lines);

  @override
  int get hashCode => Object.hash(mode, lines, discount, note, date);
}

/// Agrégat statistique sur un ensemble de ventes (rapports, tableau de bord).
@immutable
class SalesSummary {
  const SalesSummary({
    required this.saleCount,
    required this.cancelledCount,
    required this.totalSales,
    required this.totalDiscount,
    required this.totalCost,
    required this.totalProfit,
    required this.quantitySold,
  });

  /// Nombre de ventes (hors annulées).
  final int saleCount;

  /// Nombre de ventes annulées sur la période.
  final int cancelledCount;

  /// Chiffre d'affaires encaissé (total payé).
  final Money totalSales;

  /// Total des remises accordées.
  final Money totalDiscount;

  /// Coût des marchandises vendues.
  final Money totalCost;

  /// Bénéfice net.
  final Money totalProfit;

  /// Quantité totale vendue, en unité de base.
  final Qty quantitySold;

  static const SalesSummary empty = SalesSummary(
    saleCount: 0,
    cancelledCount: 0,
    totalSales: Money.zero,
    totalDiscount: Money.zero,
    totalCost: Money.zero,
    totalProfit: Money.zero,
    quantitySold: Qty.zero,
  );

  /// Panier moyen (0 si aucune vente).
  Money get averageBasket => saleCount == 0
      ? Money.zero
      : Money.fromMillimes(totalSales.millimes ~/ saleCount);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SalesSummary &&
          other.saleCount == saleCount &&
          other.cancelledCount == cancelledCount &&
          other.totalSales == totalSales &&
          other.totalDiscount == totalDiscount &&
          other.totalCost == totalCost &&
          other.totalProfit == totalProfit &&
          other.quantitySold == quantitySold);

  @override
  int get hashCode => Object.hash(
        saleCount,
        cancelledCount,
        totalSales,
        totalDiscount,
        totalCost,
        totalProfit,
        quantitySold,
      );
}
