import 'package:drift/drift.dart';

import '../../core/errors/failures.dart';
import '../../core/money/money.dart';
import '../../core/quantity/quantity.dart';
import '../../domain/entities/purchase.dart';
import '../../domain/entities/stock_movement.dart';
import '../../domain/enums/enums.dart';
import '../../domain/repositories/purchase_repository.dart';
import '../local/database.dart';
import '../local/mappers/purchase_mappers.dart';
import '../local/mappers/stock_mapper.dart';

/// Implémentation Drift du contrat [PurchaseRepository].
///
/// Le réapprovisionnement est **atomique** : achat, lignes, entrées de stock
/// et cache de stock sont écrits dans une seule transaction ; le prix d'achat
/// de référence du produit est éventuellement mis à jour.
class DriftPurchaseRepository implements PurchaseRepository {
  DriftPurchaseRepository(this._db);

  final AppDatabase _db;

  @override
  Future<Purchase> register(PurchaseDraft draft) {
    if (draft.isEmpty) {
      throw const AppFailure(
        FailureCode.validation,
        debugMessage: 'Aucune ligne à enregistrer.',
      );
    }
    return _db.transaction(() async {
      final now = draft.date ?? DateTime.now();
      final draftPurchase = Purchase(
        supplierId: draft.supplierId,
        date: now,
        totalAmount: draft.totalAmount,
        note: draft.note,
        createdAt: now,
      );
      final purchaseId =
          await _db.into(_db.purchases).insert(draftPurchase.toCompanion());

      final items = <PurchaseItem>[];
      for (final line in draft.lines) {
        final item = PurchaseItem(
          purchaseId: purchaseId,
          productId: line.productId,
          quantity: line.quantity,
          unitPurchasePrice: line.unitPurchasePrice,
          lineTotal: line.lineTotal,
        );
        await _db.into(_db.purchaseItems).insert(item.toCompanion());
        items.add(item);

        final product = await _requireProduct(line.productId);
        final movement = StockMovement.apply(
          productId: line.productId,
          type: StockMovementType.purchaseIn,
          quantity: line.quantity,
          previousBalance: product.quantityOnHand,
          unitCost: line.unitPurchasePrice,
          referenceType: MovementReferenceType.purchase,
          referenceId: purchaseId,
          createdAt: now,
        );
        await _db.into(_db.stockMovements).insert(movement.toCompanion());

        await (_db.update(_db.products)
              ..where((t) => t.id.equals(line.productId)))
            .write(
          ProductsCompanion(
            quantityOnHand: Value<Qty>(movement.balanceAfter),
            updatedAt: Value<DateTime>(now),
            purchasePrice: draft.updateProductCost
                ? Value<Money>(line.unitPurchasePrice)
                : const Value.absent(),
          ),
        );
      }
      return draftPurchase.copyWith(id: purchaseId, items: items);
    });
  }

  @override
  Future<Purchase?> getById(int purchaseId) async {
    final row = await (_db.select(_db.purchases)
          ..where((t) => t.id.equals(purchaseId)))
        .getSingleOrNull();
    if (row == null) return null;
    final items = await _itemsOf(purchaseId);
    return row.toEntity(items: items);
  }

  @override
  Future<List<Purchase>> getBySupplier(int supplierId) async {
    final rows = await (_db.select(_db.purchases)
          ..where((t) => t.supplierId.equals(supplierId))
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .get();
    return rows.map((r) => r.toEntity()).toList(growable: false);
  }

  @override
  Future<List<Purchase>> getBetween(DateTime from, DateTime to) async {
    final rows = await (_db.select(_db.purchases)
          ..where((t) =>
              t.date.isBiggerOrEqualValue(from) &
              t.date.isSmallerThanValue(to))
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .get();
    return rows.map((r) => r.toEntity()).toList(growable: false);
  }

  @override
  Stream<List<Purchase>> watchBetween(DateTime from, DateTime to) {
    final stmt = _db.select(_db.purchases)
      ..where((t) =>
          t.date.isBiggerOrEqualValue(from) & t.date.isSmallerThanValue(to))
      ..orderBy([(t) => OrderingTerm.desc(t.date)]);
    return stmt.watch().map(
          (rows) => rows.map((r) => r.toEntity()).toList(growable: false),
        );
  }

  // --- Aides internes -------------------------------------------------------

  Future<List<PurchaseItem>> _itemsOf(int purchaseId) async {
    final query = _db.select(_db.purchaseItems).join([
      innerJoin(
        _db.products,
        _db.products.id.equalsExp(_db.purchaseItems.productId),
      ),
    ])
      ..where(_db.purchaseItems.purchaseId.equals(purchaseId));
    final rows = await query.get();
    return rows
        .map(
          (r) => r.readTable(_db.purchaseItems).toEntity(
                productName: r.readTable(_db.products).name,
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
}
