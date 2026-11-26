import 'package:drift/drift.dart';

import '../../core/barcode/barcode_generator.dart';
import '../../core/errors/failures.dart';
import '../../core/money/money.dart';
import '../../core/quantity/quantity.dart';
import '../../domain/entities/catalog.dart';
import '../../domain/entities/stock_movement.dart';
import '../../domain/enums/enums.dart';
import '../../domain/repositories/product_repository.dart';
import '../../domain/services/stock_calculator.dart';
import '../local/database.dart';
import '../local/mappers/catalog_mappers.dart';
import '../local/mappers/settings_mapper.dart';
import '../local/mappers/stock_mapper.dart';

/// Implémentation Drift du contrat [ProductRepository].
///
/// La création d'un produit génère un code-barres EAN-13 unique si aucun
/// n'est fourni, et journalise le stock initial comme premier mouvement.
class DriftProductRepository implements ProductRepository {
  DriftProductRepository(this._db, {BarcodeGenerator? barcodeGenerator})
      : _barcodeGenerator = barcodeGenerator ?? BarcodeGenerator();

  final AppDatabase _db;
  final BarcodeGenerator _barcodeGenerator;

  @override
  Stream<List<Product>> watchAll({
    String? query,
    int? categoryId,
    int? supplierId,
    bool onlyActive = true,
  }) {
    final stmt = _db.select(_db.products);
    _applyFilters(
      stmt,
      query: query,
      categoryId: categoryId,
      supplierId: supplierId,
      onlyActive: onlyActive,
    );
    stmt.orderBy([(t) => OrderingTerm.asc(t.name)]);
    return stmt.watch().map(
          (rows) => rows.map((r) => r.toEntity()).toList(growable: false),
        );
  }

  @override
  Future<List<Product>> getAll({
    String? query,
    int? categoryId,
    int? supplierId,
    bool onlyActive = true,
  }) async {
    final stmt = _db.select(_db.products);
    _applyFilters(
      stmt,
      query: query,
      categoryId: categoryId,
      supplierId: supplierId,
      onlyActive: onlyActive,
    );
    stmt.orderBy([(t) => OrderingTerm.asc(t.name)]);
    final rows = await stmt.get();
    return rows.map((r) => r.toEntity()).toList(growable: false);
  }

  @override
  Future<Product?> getById(int id) async {
    final row = await (_db.select(_db.products)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row?.toEntity();
  }

  @override
  Future<Product?> getByBarcode(String barcode) async {
    final trimmed = barcode.trim();
    if (trimmed.isEmpty) return null;
    final row = await (_db.select(_db.products)
          ..where((t) => t.barcode.equals(trimmed)))
        .getSingleOrNull();
    return row?.toEntity();
  }

  @override
  Future<bool> isBarcodeTaken(String barcode, {int? exceptId}) async {
    final trimmed = barcode.trim();
    if (trimmed.isEmpty) return false;
    final stmt = _db.select(_db.products)
      ..where((t) => t.barcode.equals(trimmed));
    if (exceptId != null) {
      stmt.where((t) => t.id.equals(exceptId).not());
    }
    return await stmt.getSingleOrNull() != null;
  }

  @override
  Future<int> create(Product product) {
    return _db.transaction(() async {
      final barcode = await _resolveBarcode(product.barcode);
      final id = await _db
          .into(_db.products)
          .insert(product.copyWith(barcode: barcode).toCompanion());

      // Stock initial éventuel : premier mouvement du journal.
      if (product.quantityOnHand > Qty.zero) {
        final movement = StockMovement.apply(
          productId: id,
          type: StockMovementType.initial,
          quantity: product.quantityOnHand,
          previousBalance: Qty.zero,
          unitCost: product.purchasePrice,
        );
        await _db.into(_db.stockMovements).insert(movement.toCompanion());
      }
      return id;
    });
  }

  @override
  Future<void> update(Product product) async {
    final id = product.id;
    if (id == null) {
      throw const AppFailure(
        FailureCode.validation,
        debugMessage: 'Identifiant de produit manquant.',
      );
    }
    if (product.barcode.trim().isNotEmpty &&
        await isBarcodeTaken(product.barcode, exceptId: id)) {
      throw const AppFailure(
        FailureCode.duplicateBarcode,
        debugMessage: 'Ce code-barres est déjà utilisé par un autre produit.',
      );
    }
    await (_db.update(_db.products)..where((t) => t.id.equals(id)))
        .write(product.toCompanion());
  }

  @override
  Future<void> setActive(int id, bool isActive) async {
    await (_db.update(_db.products)..where((t) => t.id.equals(id))).write(
      ProductsCompanion(
        isActive: Value<bool>(isActive),
        updatedAt: Value<DateTime>(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> delete(int id) async {
    try {
      await (_db.delete(_db.products)..where((t) => t.id.equals(id))).go();
    } catch (e) {
      throw AppFailure(
        FailureCode.database,
        debugMessage:
            'Produit référencé par une vente, un achat ou un mouvement : '
            'désactivez-le au lieu de le supprimer.',
        cause: e,
      );
    }
  }

  @override
  Future<List<Product>> lowStock({bool includeOutOfStock = true}) async {
    final rows = await (_db.select(_db.products)
          ..where((t) => t.isActive.equals(true)))
        .get();
    return rows
        .map((r) => r.toEntity())
        .where(
          (p) => includeOutOfStock
              ? p.needsRestock
              : p.stockStatus == StockStatus.low,
        )
        .toList(growable: false);
  }

  @override
  Future<Money> stockValue({bool atPurchasePrice = true}) async {
    final products = await getAll(onlyActive: false);
    return StockCalculator.totalValue(
      products.map(
        (p) => (
          quantity: p.quantityOnHand,
          pricePerBaseUnit: atPurchasePrice ? p.purchasePrice : p.retailPrice,
        ),
      ),
    );
  }

  @override
  Future<int> count({bool onlyActive = true}) async {
    final countExpr = _db.products.id.count();
    final stmt = _db.selectOnly(_db.products)
      ..addColumns([countExpr]);
    if (onlyActive) {
      stmt.where(_db.products.isActive.equals(true));
    }
    final row = await stmt.getSingle();
    return row.read(countExpr) ?? 0;
  }

  // --- Aides internes -------------------------------------------------------

  void _applyFilters(
    SimpleSelectStatement<$ProductsTable, ProductRow> stmt, {
    String? query,
    int? categoryId,
    int? supplierId,
    required bool onlyActive,
  }) {
    if (onlyActive) {
      stmt.where((t) => t.isActive.equals(true));
    }
    if (categoryId != null) {
      stmt.where((t) => t.categoryId.equals(categoryId));
    }
    if (supplierId != null) {
      stmt.where((t) => t.supplierId.equals(supplierId));
    }
    if (query != null && query.trim().isNotEmpty) {
      final like = '%${query.trim()}%';
      stmt.where((t) => t.name.like(like) | t.barcode.like(like));
    }
  }

  /// Renvoie le code-barres à enregistrer : celui fourni s'il est valide et
  /// libre, sinon un EAN-13 unique généré automatiquement.
  Future<String> _resolveBarcode(String provided) async {
    final candidate = provided.trim();
    if (candidate.isNotEmpty) {
      if (await isBarcodeTaken(candidate)) {
        throw const AppFailure(
          FailureCode.duplicateBarcode,
          debugMessage: 'Ce code-barres est déjà utilisé par un autre produit.',
        );
      }
      return candidate;
    }
    return _generateUniqueBarcode();
  }

  /// Génère un EAN-13 unique (préfixe GS1 interne, ex. `200`) en excluant les
  /// codes déjà présents en base.
  Future<String> _generateUniqueBarcode() async {
    final rows = await _db.select(_db.products).get();
    final taken = rows.map((r) => r.barcode).toSet();
    final prefix = await _eanPrefix();
    return _barcodeGenerator.generateEan13(
      isTaken: taken.contains,
      prefix: prefix,
    );
  }

  Future<String> _eanPrefix() async {
    final row = await (_db.select(_db.settings)
          ..where((t) => t.id.equals(kSettingsRowId)))
        .getSingleOrNull();
    return row?.barcodeEanPrefix ?? '200';
  }
}
