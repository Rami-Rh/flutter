import 'package:drift/drift.dart';

import '../../../domain/enums/enums.dart';
import '../converters.dart';
import 'catalog_tables.dart';

/// Journal **immuable** des mouvements de stock (ajout seul).
///
/// Aucune ligne n'est jamais modifiée ni supprimée : le solde d'un produit est
/// la somme signée de ses mouvements. Cette approche garantit la traçabilité
/// complète (qui a modifié quoi, quand) et permet un audit/une reconstruction
/// du stock à tout moment.
@DataClassName('StockMovementRow')
@TableIndex(name: 'idx_movements_product', columns: {#productId})
@TableIndex(name: 'idx_movements_date', columns: {#createdAt})
class StockMovements extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get productId => integer()
      .references(Products, #id, onDelete: KeyAction.restrict)();

  /// Nature du mouvement (entrée/sortie).
  TextColumn get type => textEnum<StockMovementType>()();

  /// Quantité du mouvement, en unité de base.
  /// Le sens (+/−) est déduit du [type] ; seule exception, le type
  /// `adjustment` peut porter une quantité directement signée.
  IntColumn get quantity => integer().map(const QtyConverter())();

  /// Coût unitaire associé (utile pour valoriser les entrées d'achat).
  IntColumn get unitCost => integer().map(const MoneyConverter()).nullable()();

  /// Type d'objet à l'origine du mouvement (vente, achat, manuel).
  TextColumn get referenceType => textEnum<MovementReferenceType>()();

  /// Identifiant de l'objet référencé (ex. `sales.id`), si applicable.
  IntColumn get referenceId => integer().nullable()();

  /// Solde du produit **après** ce mouvement (contrôle de cohérence).
  IntColumn get balanceAfter => integer().map(const QtyConverter())();

  TextColumn get note => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();
}
