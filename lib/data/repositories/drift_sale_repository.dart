import 'package:drift/drift.dart';

import '../../core/errors/failures.dart';
import '../../core/money/money.dart';
import '../../core/quantity/quantity.dart';
import '../../domain/entities/sale.dart';
import '../../domain/entities/stock_movement.dart';
import '../../domain/enums/enums.dart';
import '../../domain/repositories/sale_repository.dart';
import '../local/database.dart';
import '../local/mappers/sale_mappers.dart';
import '../local/mappers/stock_mapper.dart';

/// Implémentation Drift du contrat [SaleRepository].
///
/// Chaque encaissement / annulation s'exécute dans **une seule transaction** :
/// la vente, ses lignes, le journal de stock et le cache de stock sont écrits
/// atomiquement, garantissant la cohérence même en cas d'interruption.
class DriftSaleRepository implements SaleRepository {
  DriftSaleRepository(this._db);

  final AppDatabase _db;

  @override
  Future<Sale> checkout(SaleDraft draft) {
    if (draft.isEmpty) {
      throw const AppFailure(
        FailureCode.validation,
        debugMessage: 'Le panier est vide.',
      );
    }
    return _db.transaction(() async {
      final now = draft.date ?? DateTime.now();
      final draftSale = Sale.fromTotals(
        date: now,
        mode: draft.mode,
        totals: draft.totals,
        note: draft.note,
      );
      final saleId = await _db.into(_db.sales).insert(draftSale.toCompanion());

      final items = <SaleItem>[];
      for (final line in draft.lines) {
        final item = SaleItem.fromCartLine(line, saleId: saleId);
        await _db.into(_db.saleItems).insert(item.toCompanion());
        items.add(item);

        final product = await _requireProduct(line.productId);
        final movement = StockMovement.apply(
          productId: line.productId,
          type: StockMovementType.saleOut,
          quantity: line.baseQuantity,
          previousBalance: product.quantityOnHand,
          unitCost: product.purchasePrice,
          referenceType: MovementReferenceType.sale,
          referenceId: saleId,
          createdAt: now,
        );
        await _db.into(_db.stockMovements).insert(movement.toCompanion());
        await _updateProductBalance(
          productId: line.productId,
          balance: movement.balanceAfter,
          at: now,
        );
      }
      return draftSale.copyWith(id: saleId, items: items);
    });
  }

  @override
  Future<Sale> cancel(int saleId) {
    return _db.transaction(() async {
      final row = await (_db.select(_db.sales)
            ..where((t) => t.id.equals(saleId)))
          .getSingleOrNull();
      if (row == null) {
        throw const AppFailure(
          FailureCode.notFound,
          debugMessage: 'Vente introuvable.',
        );
      }
      if (row.isCancelled) {
        throw const AppFailure(
          FailureCode.validation,
          debugMessage: 'Cette vente a déjà été annulée.',
        );
      }

      final now = DateTime.now();
      final itemRows = await (_db.select(_db.saleItems)
            ..where((t) => t.saleId.equals(saleId)))
          .get();

      for (final item in itemRows) {
        final product = await _requireProduct(item.productId);
        final movement = StockMovement.apply(
          productId: item.productId,
          type: StockMovementType.saleCancellation,
          quantity: item.quantityBase,
          previousBalance: product.quantityOnHand,
          unitCost: product.purchasePrice,
          referenceType: MovementReferenceType.sale,
          referenceId: saleId,
          createdAt: now,
        );
        await _db.into(_db.stockMovements).insert(movement.toCompanion());
        await _updateProductBalance(
          productId: item.productId,
          balance: movement.balanceAfter,
          at: now,
        );
      }

      await (_db.update(_db.sales)..where((t) => t.id.equals(saleId))).write(
        SalesCompanion(
          isCancelled: const Value<bool>(true),
          cancelledAt: Value<DateTime>(now),
        ),
      );

      final updated = await _loadSale(saleId);
      return updated!;
    });
  }

  @override
  Future<Sale?> getById(int saleId) => _loadSale(saleId);

  @override
  Future<List<Sale>> getBetween(DateTime from, DateTime to) async {
    final rows = await (_db.select(_db.sales)
          ..where((t) =>
              t.date.isBiggerOrEqualValue(from) &
              t.date.isSmallerThanValue(to))
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .get();
    return rows.map((r) => r.toEntity()).toList(growable: false);
  }

  @override
  Stream<List<Sale>> watchBetween(DateTime from, DateTime to) {
    final stmt = _db.select(_db.sales)
      ..where((t) =>
          t.date.isBiggerOrEqualValue(from) & t.date.isSmallerThanValue(to))
      ..orderBy([(t) => OrderingTerm.desc(t.date)]);
    return stmt.watch().map(
          (rows) => rows.map((r) => r.toEntity()).toList(growable: false),
        );
  }

  @override
  Stream<List<Sale>> watchToday() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    return watchBetween(start, end);
  }

  @override
  Future<SalesSummary> summaryBetween(DateTime from, DateTime to) async {
    final rows = await (_db.select(_db.sales)
          ..where((t) =>
              t.date.isBiggerOrEqualValue(from) &
              t.date.isSmallerThanValue(to)))
        .get();
    final active = rows.where((r) => !r.isCancelled).toList(growable: false);
    final activeIds = active.map((r) => r.id).toList(growable: false);

    var quantitySold = Qty.zero;
    if (activeIds.isNotEmpty) {
      final itemRows = await (_db.select(_db.saleItems)
            ..where((t) => t.saleId.isIn(activeIds)))
          .get();
      quantitySold = Qty.fromMilliUnits(
        itemRows.fold(0, (sum, i) => sum + i.quantityBase.milliUnits),
      );
    }

    return SalesSummary(
      saleCount: active.length,
      cancelledCount: rows.length - active.length,
      totalSales: Money.sum(active.map((r) => r.total)),
      totalDiscount: Money.sum(active.map((r) => r.discount)),
      totalCost: Money.sum(active.map((r) => r.totalCost)),
      totalProfit: Money.sum(active.map((r) => r.profit)),
      quantitySold: quantitySold,
    );
  }

  @override
  Future<List<SaleItem>> itemsBetween(DateTime from, DateTime to) async {
    final query = _db.select(_db.saleItems).join([
      innerJoin(
        _db.sales,
        _db.sales.id.equalsExp(_db.saleItems.saleId),
      ),
      innerJoin(
        _db.products,
        _db.products.id.equalsExp(_db.saleItems.productId),
      ),
    ])
      ..where(
        _db.sales.date.isBiggerOrEqualValue(from) &
            _db.sales.date.isSmallerThanValue(to) &
            _db.sales.isCancelled.equals(false),
      );
    final rows = await query.get();
    return rows
        .map(
          (r) => r.readTable(_db.saleItems).toEntity(
                productName: r.readTable(_db.products).name,
              ),
        )
        .toList(growable: false);
  }

  // --- Aides internes -------------------------------------------------------

  Future<Sale?> _loadSale(int saleId) async {
    final row = await (_db.select(_db.sales)..where((t) => t.id.equals(saleId)))
        .getSingleOrNull();
    if (row == null) return null;
    final items = await _itemsOf(saleId);
    return row.toEntity(items: items);
  }

  /// Lignes d'une vente, jointes au produit pour afficher nom et code-barres.
  Future<List<SaleItem>> _itemsOf(int saleId) async {
    final query = _db.select(_db.saleItems).join([
      innerJoin(
        _db.products,
        _db.products.id.equalsExp(_db.saleItems.productId),
      ),
    ])
      ..where(_db.saleItems.saleId.equals(saleId));
    final rows = await query.get();
    return rows
        .map(
          (r) => r.readTable(_db.saleItems).toEntity(
                productName: r.readTable(_db.products).name,
                barcode: r.readTable(_db.products).barcode,
              ),
        )
        .toList(growable: false);
  }

  Future<ProductRow> _requireProduct(int productId) async {
    final row = await (_db.select(_db.products)
          ..where((t) => t.id.equals(productId)))
        .getSingleOrNull();
    if (row == null) {
      throw AppFailure(
        FailureCode.notFound,
        debugMessage: 'Produit $productId introuvable.',
      );
    }
    return row;
  }

  Future<void> _updateProductBalance({
    required int productId,
    required Qty balance,
    required DateTime at,
  }) {
    return (_db.update(_db.products)..where((t) => t.id.equals(productId))).write(
      ProductsCompanion(
        quantityOnHand: Value<Qty>(balance),
        updatedAt: Value<DateTime>(at),
      ),
    );
  }
}
