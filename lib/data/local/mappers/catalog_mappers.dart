import 'package:drift/drift.dart';

import '../../../core/money/money.dart';
import '../../../core/quantity/quantity.dart';
import '../../../domain/entities/catalog.dart';
import '../../../domain/enums/enums.dart';
import '../../../domain/units/units.dart';
import '../database.dart';

/// Conversions entre les lignes Drift du catalogue et les entités du domaine.
///
/// Les mappers isolent totalement la couche base de données du domaine :
/// aucune entité métier ne connaît Drift, et aucune ligne générée ne fuit
/// vers l'interface.

/// `categories` ↔ [Category]
extension CategoryRowMapper on CategoryRow {
  Category toEntity() => Category(
        id: id,
        name: name,
        colorHex: colorHex,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}

extension CategoryMapper on Category {
  CategoriesCompanion toCompanion({bool includeId = false}) =>
      CategoriesCompanion(
        id: includeId && id != null ? Value<int>(id!) : const Value.absent(),
        name: Value<String>(name),
        colorHex: Value<String?>(colorHex),
        createdAt: Value<DateTime>(createdAt ?? DateTime.now()),
        updatedAt: Value<DateTime>(DateTime.now()),
      );
}

/// `suppliers` ↔ [Supplier]
extension SupplierRowMapper on SupplierRow {
  Supplier toEntity() => Supplier(
        id: id,
        name: name,
        companyName: companyName,
        phone: phone,
        notes: notes,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}

extension SupplierMapper on Supplier {
  SuppliersCompanion toCompanion({bool includeId = false}) =>
      SuppliersCompanion(
        id: includeId && id != null ? Value<int>(id!) : const Value.absent(),
        name: Value<String>(name),
        companyName: Value<String?>(companyName),
        phone: Value<String?>(phone),
        notes: Value<String?>(notes),
        createdAt: Value<DateTime>(createdAt ?? DateTime.now()),
        updatedAt: Value<DateTime>(DateTime.now()),
      );
}

/// `products` ↔ [Product]
///
/// Le conditionnement stocké (unité de base + pièces/carton + kg/sac) est
/// reconstruit via [PackagingConfig.fromColumns].
extension ProductRowMapper on ProductRow {
  Product toEntity() => Product(
        id: id,
        name: name,
        barcode: barcode,
        categoryId: categoryId,
        supplierId: supplierId,
        packaging: PackagingConfig.fromColumns(
          baseUnit: baseUnit,
          piecesPerCarton: piecesPerCarton,
          kgPerSackMilli: kgPerSackMilli,
        ),
        quantityOnHand: quantityOnHand,
        purchasePrice: purchasePrice,
        retailPrice: retailPrice,
        wholesalePrice: wholesalePrice,
        lowStockThreshold: lowStockThreshold,
        imagePath: imagePath,
        isActive: isActive,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}

extension ProductMapper on Product {
  ProductsCompanion toCompanion({bool includeId = false}) => ProductsCompanion(
        id: includeId && id != null ? Value<int>(id!) : const Value.absent(),
        name: Value<String>(name),
        barcode: Value<String>(barcode),
        categoryId: Value<int?>(categoryId),
        supplierId: Value<int?>(supplierId),
        baseUnit: Value<StockBaseUnit>(packaging.baseUnit),
        piecesPerCarton: Value<int?>(packaging.piecesPerCarton),
        kgPerSackMilli: Value<int?>(packaging.kgPerSackMilli),
        quantityOnHand: Value<Qty>(quantityOnHand),
        purchasePrice: Value<Money>(purchasePrice),
        retailPrice: Value<Money>(retailPrice),
        wholesalePrice: Value<Money>(wholesalePrice),
        lowStockThreshold: Value<Qty>(lowStockThreshold),
        imagePath: Value<String?>(imagePath),
        isActive: Value<bool>(isActive),
        createdAt: Value<DateTime>(createdAt ?? DateTime.now()),
        updatedAt: Value<DateTime>(DateTime.now()),
      );
}
