import 'package:drift/drift.dart';

import '../converters.dart';
import 'catalog_tables.dart';

/// Achat / réapprovisionnement chez un fournisseur.
@DataClassName('PurchaseRow')
@TableIndex(name: 'idx_purchases_supplier', columns: {#supplierId})
@TableIndex(name: 'idx_purchases_date', columns: {#date})
class Purchases extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get supplierId => integer()
      .nullable()
      .references(Suppliers, #id, onDelete: KeyAction.setNull)();

  DateTimeColumn get date => dateTime()();

  /// Montant total de l'achat.
  IntColumn get totalAmount => integer().map(const MoneyConverter())();

  TextColumn get note => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();
}

/// Ligne d'achat (un produit, une quantité, un prix d'achat).
@DataClassName('PurchaseItemRow')
@TableIndex(name: 'idx_purchase_items_product', columns: {#productId})
class PurchaseItems extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get purchaseId => integer()
      .references(Purchases, #id, onDelete: KeyAction.cascade)();

  IntColumn get productId => integer()
      .references(Products, #id, onDelete: KeyAction.restrict)();

  /// Quantité reçue, en unité de base du produit.
  IntColumn get quantity => integer().map(const QtyConverter())();

  /// Prix d'achat unitaire (par unité de base) au moment de l'achat.
  IntColumn get unitPurchasePrice => integer().map(const MoneyConverter())();

  IntColumn get lineTotal => integer().map(const MoneyConverter())();
}
