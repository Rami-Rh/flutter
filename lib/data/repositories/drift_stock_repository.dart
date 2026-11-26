import 'package:drift/drift.dart';

import '../../core/errors/failures.dart';
import '../../core/money/money.dart';
import '../../core/quantity/quantity.dart';
import '../../domain/entities/catalog.dart';
import '../../domain/entities/stock_movement.dart';
import '../../domain/enums/enums.dart';
import '../../domain/repositories/stock_repository.dart';
import '../../domain/services/stock_calculator.dart';
import '../local/database.dart';
import '../local/mappers/catalog_mappers.dart';
import '../local/mappers/stock_mapper.dart';

/// Implémentation Drift du contrat [StockRepository].
///
/// Le journal `stock_movements` est la source de vérité : lecture et ajout
/// seul. L'ajustement manuel écrit un mouvement puis met à jour le cache
/// `products.quantity_on_hand` dans la même transaction.
class DriftStockRepository implements StockRepository {
  DriftStockRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<List<StockMovement>> watchMovementsOf(int productId) {
    final stmt = _db.select(_db.stockMovements)
      ..where((t) => t.productId.equals(productId))
      ..orderBy([
        (t) => OrderingTerm.desc(t.createdAt),
        (t) => OrderingTerm.desc(t.id),
      ]);
    return stmt.watch().map(
          (rows) => rows.map((r) => r.toEntity()).toList(growable: false),
        );
  }

  @override
  Future<List<StockMovement>> movementsOf(int productId, {int? limit}) async {
    final stmt = _db.select(_db.stockMovements)
      ..where((t) => t.productId.equals(productId))
      ..orderBy([
        (t) => OrderingTerm.desc(t.createdAt),
        (t) => OrderingTerm.desc(t.id),
      ]);
    if (limit != null) {
      stmt.limit(limit);
    }
    final rows = await stmt.get();
    return rows.map((r) => r.toEntity()).toList(growable: false);
  }

  @override
  Future<Qty> balanceOf(int productId) async {
    final rows = await (_db.select(_db.stockMovements)
          ..where((t) => t.productId.equals(productId)))
        .get();
    return StockCalculator.balance(
      rows.map((r) => (type: r.type, quantity: r.quantity)),
    );
  }

  @override
  Future<StockMovement> adjustTo({
    required int productId,
    required Qty newBalance,
    String? note,
  }) {
    return _db.transaction(() async {
      final product = await (_db.select(_db.products)
            ..where((t) => t.id.equals(productId)))
          .getSingleOrNull();
      if (product == null) {
        throw const AppFailure(
          FailureCode.notFound,
          debugMessage: 'Produit introuvable.',
        );
      }
      final delta = newBalance - product.quantityOnHand;
      if (delta.isZero) {
        throw const AppFailure(
          FailureCode.validation,
          debugMessage: 'Le nouveau stock est identique au stock actuel.',
        );
      }
      final movement = StockMovement.apply(
        productId: productId,
        type: StockMovementType.adjustment,
        quantity: delta,
        previousBalance: product.quantityOnHand,
        referenceType: MovementReferenceType.manual,
        note: note,
      );
      final id = await _db.into(_db.stockMovements).insert(movement.toCompanion());
      await (_db.update(_db.products)..where((t) => t.id.equals(productId)))
          .write(
        ProductsCompanion(
          quantityOnHand: Value<Qty>(newBalance),
          updatedAt: Value<DateTime>(DateTime.now()),
        ),
      );
      return movement.copyWith(id: id);
    });
  }

  @override
  Future<List<Product>> lowStockProducts() async {
    final rows = await (_db.select(_db.products)
          ..where((t) => t.isActive.equals(true)))
        .get();
    return rows
        .map((r) => r.toEntity())
        .where((p) => p.needsRestock)
        .toList(growable: false);
  }

  @override
  Future<Money> totalStockValue({bool atPurchasePrice = true}) async {
    final rows = await _db.select(_db.products).get();
    return StockCalculator.totalValue(
      rows.map(
        (r) => (
          quantity: r.quantityOnHand,
          pricePerBaseUnit: atPurchasePrice ? r.purchasePrice : r.retailPrice,
        ),
      ),
    );
  }
}
