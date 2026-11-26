import 'package:drift/drift.dart';

import '../../../core/money/money.dart';
import '../../../core/quantity/quantity.dart';
import '../../../domain/entities/sale.dart';
import '../../../domain/enums/enums.dart';
import '../database.dart';

/// `sales` / `sale_items` ↔ [Sale] / [SaleItem]

extension SaleRowMapper on SaleRow {
  /// Convertit la vente ; [items] permet d'y rattacher ses lignes déjà mappées.
  Sale toEntity({List<SaleItem> items = const <SaleItem>[]}) => Sale(
        id: id,
        date: date,
        mode: mode,
        subtotal: subtotal,
        discount: discount,
        total: total,
        totalCost: totalCost,
        profit: profit,
        isCancelled: isCancelled,
        cancelledAt: cancelledAt,
        note: note,
        createdAt: createdAt,
        items: items,
      );
}

extension SaleMapper on Sale {
  SalesCompanion toCompanion({bool includeId = false}) => SalesCompanion(
        id: includeId && id != null ? Value<int>(id!) : const Value.absent(),
        date: Value<DateTime>(date),
        mode: Value<SaleMode>(mode),
        subtotal: Value<Money>(subtotal),
        discount: Value<Money>(discount),
        total: Value<Money>(total),
        totalCost: Value<Money>(totalCost),
        profit: Value<Money>(profit),
        isCancelled: Value<bool>(isCancelled),
        cancelledAt: Value<DateTime?>(cancelledAt),
        note: Value<String?>(note),
        createdAt: Value<DateTime>(createdAt ?? DateTime.now()),
      );
}

extension SaleItemRowMapper on SaleItemRow {
  /// Convertit la ligne ; [productName] et [barcode] proviennent d'une
  /// jointure sur `products` (non stockés sur la ligne elle-même).
  SaleItem toEntity({String? productName, String? barcode}) => SaleItem(
        id: id,
        saleId: saleId,
        productId: productId,
        packagingUnit: packagingUnit,
        quantityBase: quantityBase,
        quantityInPackaging: quantityInPackaging,
        unitPrice: unitPrice,
        unitCost: unitCost,
        lineTotal: lineTotal,
        lineProfit: lineProfit,
        productName: productName,
        barcode: barcode,
      );
}

extension SaleItemMapper on SaleItem {
  SaleItemsCompanion toCompanion({
    bool includeId = false,
    int? saleIdOverride,
  }) =>
      SaleItemsCompanion(
        id: includeId && id != null ? Value<int>(id!) : const Value.absent(),
        saleId: Value<int>(saleIdOverride ?? saleId!),
        productId: Value<int>(productId),
        packagingUnit: Value<PackagingUnit>(packagingUnit),
        quantityBase: Value<Qty>(quantityBase),
        quantityInPackaging: Value<Qty>(quantityInPackaging),
        unitPrice: Value<Money>(unitPrice),
        unitCost: Value<Money>(unitCost),
        lineTotal: Value<Money>(lineTotal),
        lineProfit: Value<Money>(lineProfit),
      );
}
