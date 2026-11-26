import 'package:drift/drift.dart';

import '../../../domain/enums/enums.dart';
import '../converters.dart';

/// Catégories de produits (CRUD complet + recherche).
@DataClassName('CategoryRow')
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text().withLength(min: 1, max: 80).unique()();

  /// Couleur d'accent optionnelle (hex `#RRGGBB`) pour l'interface.
  TextColumn get colorHex => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();
}

/// Fournisseurs.
@DataClassName('SupplierRow')
class Suppliers extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Nom de la personne de contact.
  TextColumn get name => text().withLength(min: 1, max: 120)();

  /// Raison sociale / société (ex. « Lilas »).
  TextColumn get companyName => text().nullable()();

  /// Téléphone (appel direct depuis l'application).
  TextColumn get phone => text().nullable()();

  TextColumn get notes => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();
}

/// Produits.
///
/// Le stock ([quantityOnHand]) est un **cache** du journal des mouvements
/// (`stock_movements`) et est toujours exprimé en **unité de base**.
/// Les prix sont eux aussi exprimés par unité de base (pièce ou kilo).
@DataClassName('ProductRow')
@TableIndex(name: 'idx_products_category', columns: {#categoryId})
@TableIndex(name: 'idx_products_supplier', columns: {#supplierId})
class Products extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text().withLength(min: 1, max: 160)();

  /// Code-barres unique : scanné tel quel ou généré automatiquement.
  TextColumn get barcode => text().withLength(min: 4, max: 64).unique()();

  IntColumn get categoryId => integer()
      .nullable()
      .references(Categories, #id, onDelete: KeyAction.restrict)();

  IntColumn get supplierId => integer()
      .nullable()
      .references(Suppliers, #id, onDelete: KeyAction.setNull)();

  /// Unité de base dans laquelle le stock est conservé.
  TextColumn get baseUnit => textEnum<StockBaseUnit>()();

  /// Nombre de pièces par carton (`null` si vendu uniquement à la pièce).
  IntColumn get piecesPerCarton => integer().nullable()();

  /// Nombre de kilos par sac, en **milli-unités** (`50000` = 50 kg).
  IntColumn get kgPerSackMilli => integer().nullable()();

  /// Quantité disponible, en unité de base (cache du journal des mouvements).
  IntColumn get quantityOnHand =>
      integer().map(const QtyConverter()).withDefault(const Constant(0))();

  /// Prix d'achat unitaire (par unité de base).
  IntColumn get purchasePrice => integer().map(const MoneyConverter())();

  /// Prix de vente au détail (par unité de base).
  IntColumn get retailPrice => integer().map(const MoneyConverter())();

  /// Prix de vente en gros (par unité de base).
  IntColumn get wholesalePrice => integer().map(const MoneyConverter())();

  /// Seuil d'alerte de stock, en unité de base.
  IntColumn get lowStockThreshold =>
      integer().map(const QtyConverter()).withDefault(const Constant(0))();

  /// Chemin local de la photo du produit (optionnel).
  TextColumn get imagePath => text().nullable()();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();
}
