import 'package:drift/drift.dart';

import '../../../core/money/money.dart';
import '../../../core/quantity/quantity.dart';
import '../../../domain/entities/purchase.dart';
import '../database.dart';

/// `purchases` / `purchase_items` ↔ [Purchase] / [PurchaseItem]

extension PurchaseRowMapper on PurchaseRow {
  Purchase toEntity({List<PurchaseItem> items = const <PurchaseItem>[]}) =>
      Purchase(
        id: id,
        supplierId: supplierId,
        date: date,
        totalAmount: totalAmount,
        note: note,
        createdAt: createdAt,
        items: items,
      );
}

extension PurchaseMapper on Purchase {
  PurchasesCompanion toCompanion({bool includeId = false}) =>
      PurchasesCompanion(
        id: includeId && id != null ? Value<int>(id!) : const Value.absent(),
        supplierId: Value<int?>(supplierId),
        date: Value<DateTime>(date),
        totalAmount: Value<Money>(totalAmount),
        note: Value<String?>(note),
        createdAt: Value<DateTime>(createdAt ?? DateTime.now()),
      );
}

extension PurchaseItemRowMapper on PurchaseItemRow {
  PurchaseItem toEntity({String? productName}) => PurchaseItem(
        id: id,
        purchaseId: purchaseId,
        productId: productId,
        quantity: quantity,
        unitPurchasePrice: unitPurchasePrice,
        lineTotal: lineTotal,
        productName: productName,
      );
}

extension PurchaseItemMapper on PurchaseItem {
  PurchaseItemsCompanion toCompanion({
    bool includeId = false,
    int? purchaseIdOverride,
  }) =>
      PurchaseItemsCompanion(
        id: includeId && id != null ? Value<int>(id!) : const Value.absent(),
        purchaseId: Value<int>(purchaseIdOverride ?? purchaseId!),
        productId: Value<int>(productId),
        quantity: Value<Qty>(quantity),
        unitPurchasePrice: Value<Money>(unitPurchasePrice),
        lineTotal: Value<Money>(lineTotal),
      );
}
