import 'package:drift/drift.dart';

import '../../../domain/enums/enums.dart';
import '../converters.dart';
import 'catalog_tables.dart';

/// Vente validée (ticket).
@DataClassName('SaleRow')
@TableIndex(name: 'idx_sales_date', columns: {#date})
class Sales extends Table {
  IntColumn get id => integer().autoIncrement()();

  DateTimeColumn get date => dateTime()();

  /// Mode de vente : détail ou gros.
  TextColumn get mode => textEnum<SaleMode>()();

  /// Somme des lignes avant remise.
  IntColumn get subtotal => integer().map(const MoneyConverter())();

  /// Remise accordée sur le sous-total.
  IntColumn get discount =>
      integer().map(const MoneyConverter()).withDefault(const Constant(0))();

  /// Montant payé par le client.
  IntColumn get total => integer().map(const MoneyConverter())();

  /// Coût total des marchandises vendues (prix d'achat).
  IntColumn get totalCost => integer().map(const MoneyConverter())();

  /// Bénéfice net de la vente.
  IntColumn get profit => integer().map(const MoneyConverter())();

  /// Vente annulée (le stock a été remis automatiquement).
  BoolColumn get isCancelled => boolean().withDefault(const Constant(false))();

  DateTimeColumn get cancelledAt => dateTime().nullable()();

  TextColumn get note => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();
}

/// Ligne de vente.
///
/// La quantité est stockée à la fois en **unité de base** (pour le stock) et
/// dans le **conditionnement vendu** (pour la réimpression fidèle du ticket).
@DataClassName('SaleItemRow')
@TableIndex(name: 'idx_sale_items_sale', columns: {#saleId})
@TableIndex(name: 'idx_sale_items_product', columns: {#productId})
class SaleItems extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get saleId => integer()
      .references(Sales, #id, onDelete: KeyAction.cascade)();

  IntColumn get productId => integer()
      .references(Products, #id, onDelete: KeyAction.restrict)();

  /// Conditionnement vendu (pièce, carton, kilo ou sac).
  TextColumn get packagingUnit => textEnum<PackagingUnit>()();

  /// Quantité convertie en unité de base (sert au journal de stock).
  IntColumn get quantityBase => integer().map(const QtyConverter())();

  /// Quantité telle que saisie dans le conditionnement (pour le ticket).
  IntColumn get quantityInPackaging => integer().map(const QtyConverter())();

  /// Prix de vente unitaire appliqué (par unité de base).
  IntColumn get unitPrice => integer().map(const MoneyConverter())();

  /// Coût unitaire (par unité de base) pour le calcul du bénéfice.
  IntColumn get unitCost => integer().map(const MoneyConverter())();

  IntColumn get lineTotal => integer().map(const MoneyConverter())();

  IntColumn get lineProfit => integer().map(const MoneyConverter())();
}
