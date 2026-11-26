import 'package:meta/meta.dart';

import '../../core/money/money.dart';
import '../../core/quantity/quantity.dart';
import '../enums/enums.dart';

/// Mouvement de stock — **journal immuable, en ajout seul**.
///
/// [quantity] est exprimée en unité de base ; le sens (entrée ou sortie) se
/// déduit de [type] via [StockMovementTypeX.sign]. Exception : le type
/// `adjustment` porte une quantité directement **signée**.
/// Le solde d'un produit est la somme signée de ses mouvements.
@immutable
class StockMovement {
  const StockMovement({
    this.id,
    required this.productId,
    required this.type,
    required this.quantity,
    this.unitCost,
    this.referenceType = MovementReferenceType.none,
    this.referenceId,
    required this.balanceAfter,
    this.note,
    this.createdAt,
  });

  /// Crée un mouvement en calculant automatiquement le solde résultant.
  factory StockMovement.apply({
    int? productId,
    required StockMovementType type,
    required Qty quantity,
    required Qty previousBalance,
    Money? unitCost,
    MovementReferenceType referenceType = MovementReferenceType.none,
    int? referenceId,
    String? note,
    DateTime? createdAt,
  }) =>
      StockMovement(
        productId: productId!,
        type: type,
        quantity: quantity,
        unitCost: unitCost,
        referenceType: referenceType,
        referenceId: referenceId,
        balanceAfter: type.isInbound
            ? previousBalance + quantity
            : previousBalance - quantity,
        note: note,
        createdAt: createdAt,
      );

  final int? id;
  final int productId;

  final StockMovementType type;

  /// Quantité en valeur absolue, en unité de base.
  final Qty quantity;

  /// Coût unitaire associé (utile pour valoriser les entrées d'achat).
  final Money? unitCost;

  final MovementReferenceType referenceType;

  /// Identifiant de l'objet référencé (ex. `sales.id`).
  final int? referenceId;

  /// Solde du produit après ce mouvement (contrôle de cohérence).
  final Qty balanceAfter;

  final String? note;
  final DateTime? createdAt;

  /// Variation signée du stock (positive en entrée, négative en sortie).
  Qty get signedQuantity =>
      type.isInbound ? quantity : Qty.fromMilliUnits(-quantity.milliUnits);

  StockMovement copyWith({int? id}) => StockMovement(
        id: id ?? this.id,
        productId: productId,
        type: type,
        quantity: quantity,
        unitCost: unitCost,
        referenceType: referenceType,
        referenceId: referenceId,
        balanceAfter: balanceAfter,
        note: note,
        createdAt: createdAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is StockMovement && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
