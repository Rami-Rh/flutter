import 'package:meta/meta.dart';

import '../../core/money/money.dart';
import '../../core/quantity/quantity.dart';

/// Ligne d'achat : un produit, une quantité, un prix d'achat unitaire.
@immutable
class PurchaseItem {
  const PurchaseItem({
    this.id,
    this.purchaseId,
    required this.productId,
    required this.quantity,
    required this.unitPurchasePrice,
    required this.lineTotal,
    this.productName,
  });

  final int? id;
  final int? purchaseId;
  final int productId;

  /// Quantité reçue, en unité de base du produit.
  final Qty quantity;

  /// Prix d'achat unitaire (par unité de base).
  final Money unitPurchasePrice;

  final Money lineTotal;

  /// Nom du produit (issu d'une jointure).
  final String? productName;

  /// Total de la ligne recalculé (quantité × prix unitaire).
  static Money computeLineTotal(Qty quantity, Money unitPurchasePrice) =>
      unitPurchasePrice.timesQuantity(quantity);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is PurchaseItem && other.id == id);

  @override
  int get hashCode => id.hashCode;
}

/// Achat / réapprovisionnement chez un fournisseur.
@immutable
class Purchase {
  const Purchase({
    this.id,
    this.supplierId,
    required this.date,
    required this.totalAmount,
    this.note,
    this.createdAt,
    this.items = const <PurchaseItem>[],
  });

  final int? id;

  /// Fournisseur (facultatif : un achat peut être saisi sans fournisseur).
  final int? supplierId;

  final DateTime date;

  /// Montant total de l'achat.
  final Money totalAmount;

  final String? note;
  final DateTime? createdAt;

  /// Lignes de l'achat (vides si non chargées).
  final List<PurchaseItem> items;

  /// Nombre de lignes de l'achat.
  int get itemCount => items.length;

  Purchase copyWith({
    int? id,
    int? supplierId,
    String? note,
    List<PurchaseItem>? items,
  }) =>
      Purchase(
        id: id ?? this.id,
        supplierId: supplierId ?? this.supplierId,
        date: date,
        totalAmount: totalAmount,
        note: note ?? this.note,
        createdAt: createdAt,
        items: items ?? this.items,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Purchase && other.id == id);

  @override
  int get hashCode => id.hashCode;
}

/// Ligne d'un réapprovisionnement en cours de saisie.
///
/// [quantity] est exprimée en **unité de base** du produit (la conversion
/// carton/sac est faite par l'appelant via `UnitConverter`).
@immutable
class PurchaseLineDraft {
  const PurchaseLineDraft({
    required this.productId,
    required this.quantity,
    required this.unitPurchasePrice,
  });

  final int productId;
  final Qty quantity;
  final Money unitPurchasePrice;

  Money get lineTotal =>
      PurchaseItem.computeLineTotal(quantity, unitPurchasePrice);
}

/// Achat prêt à être enregistré.
///
/// Le repository enregistre l'achat et **alimente le stock** de chaque produit
/// de façon atomique ; il peut aussi mettre à jour le prix d'achat de
/// référence des produits concernés ([updateProductCost]).
@immutable
class PurchaseDraft {
  const PurchaseDraft({
    required this.lines,
    this.supplierId,
    this.note,
    this.date,
    this.updateProductCost = true,
  });

  final List<PurchaseLineDraft> lines;
  final int? supplierId;
  final String? note;

  /// Date de l'achat (`null` = maintenant).
  final DateTime? date;

  /// Met à jour `products.purchasePrice` avec le prix saisi.
  final bool updateProductCost;

  bool get isEmpty => lines.isEmpty;

  /// Montant total de l'achat.
  Money get totalAmount =>
      Money.sum(lines.map((l) => l.lineTotal));

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is PurchaseDraft && other.lines == lines);

  @override
  int get hashCode => Object.hash(lines, supplierId, note, date);
}
