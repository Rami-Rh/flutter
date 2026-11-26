import 'package:drift/drift.dart';

import '../../core/errors/failures.dart';
import '../../domain/entities/catalog.dart';
import '../../domain/repositories/category_repository.dart';
import '../local/database.dart';
import '../local/mappers/catalog_mappers.dart';

/// Implémentation Drift du contrat [CategoryRepository].
class DriftCategoryRepository implements CategoryRepository {
  DriftCategoryRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<List<Category>> watchAll() {
    final stmt = _db.select(_db.categories)
      ..orderBy([(t) => OrderingTerm.asc(t.name)]);
    return stmt.watch().map(
          (rows) => rows.map((r) => r.toEntity()).toList(growable: false),
        );
  }

  @override
  Future<List<Category>> getAll({String? query}) async {
    final stmt = _db.select(_db.categories);
    if (query != null && query.trim().isNotEmpty) {
      stmt.where((t) => t.name.like('%${query.trim()}%'));
    }
    stmt.orderBy([(t) => OrderingTerm.asc(t.name)]);
    final rows = await stmt.get();
    return rows.map((r) => r.toEntity()).toList(growable: false);
  }

  @override
  Future<Category?> getById(int id) async {
    final row = await (_db.select(_db.categories)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row?.toEntity();
  }

  @override
  Future<int> create(Category category) async {
    await _ensureNameAvailable(category.name);
    return _db.into(_db.categories).insert(category.toCompanion());
  }

  @override
  Future<void> update(Category category) async {
    final id = category.id;
    if (id == null) {
      throw const AppFailure(
        FailureCode.validation,
        debugMessage: 'Identifiant de catégorie manquant.',
      );
    }
    await _ensureNameAvailable(category.name, exceptId: id);
    await (_db.update(_db.categories)..where((t) => t.id.equals(id)))
        .write(category.toCompanion());
  }

  @override
  Future<void> delete(int id) async {
    final products = await countProducts(id);
    if (products > 0) {
      throw AppFailure(
        FailureCode.categoryInUse,
        debugMessage: 'La catégorie contient $products produit(s).',
      );
    }
    await (_db.delete(_db.categories)..where((t) => t.id.equals(id))).go();
  }

  @override
  Future<int> countProducts(int categoryId) async {
    final count = _db.products.id.count();
    final stmt = _db.selectOnly(_db.products)
      ..addColumns([count])
      ..where(_db.products.categoryId.equals(categoryId));
    final row = await stmt.getSingle();
    return row.read(count) ?? 0;
  }

  /// Refuse une catégorie portant déjà ce nom (hors [exceptId]).
  Future<void> _ensureNameAvailable(String name, {int? exceptId}) async {
    final stmt = _db.select(_db.categories)
      ..where((t) => t.name.equals(name.trim()));
    if (exceptId != null) {
      stmt.where((t) => t.id.equals(exceptId).not());
    }
    final existing = await stmt.getSingleOrNull();
    if (existing != null) {
      throw const AppFailure(
        FailureCode.duplicateCategoryName,
        debugMessage: 'Une catégorie porte déjà ce nom.',
      );
    }
  }
}
