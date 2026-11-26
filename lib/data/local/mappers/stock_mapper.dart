import 'package:drift/drift.dart';

import '../../../core/money/money.dart';
import '../../../core/quantity/quantity.dart';
import '../../../domain/entities/stock_movement.dart';
import '../../../domain/enums/enums.dart';
import '../database.dart';

/// `stock_movements` ↔ [StockMovement]

extension StockMovementRowMapper on StockMovementRow {
  StockMovement toEntity() => StockMovement(
        id: id,
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
}

extension StockMovementMapper on StockMovement {
  StockMovementsCompanion toCompanion({bool includeId = false}) =>
      StockMovementsCompanion(
        id: includeId && id != null ? Value<int>(id!) : const Value.absent(),
        productId: Value<int>(productId),
        type: Value<StockMovementType>(type),
        quantity: Value<Qty>(quantity),
        unitCost: Value<Money?>(unitCost),
        referenceType: Value<MovementReferenceType>(referenceType),
        referenceId: Value<int?>(referenceId),
        balanceAfter: Value<Qty>(balanceAfter),
        note: Value<String?>(note),
        createdAt: Value<DateTime>(createdAt ?? DateTime.now()),
      );
}
