import 'package:drift/drift.dart';

import '../../domain/entities/catalog.dart';
import '../../domain/repositories/supplier_repository.dart';
import '../local/database.dart';
import '../local/mappers/catalog_mappers.dart';

/// Implémentation Drift du contrat [SupplierRepository].
class DriftSupplierRepository implements SupplierRepository {
  DriftSupplierRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<List<Supplier>> watchAll() {
    final stmt = _db.select(_db.suppliers)
      ..orderBy([
        (t) => OrderingTerm.asc(t.companyName),
        (t) => OrderingTerm.asc(t.name),
      ]);
    return stmt.watch().map(
          (rows) => rows.map((r) => r.toEntity()).toList(growable: false),
        );
  }

  @override
  Future<List<Supplier>> getAll({String? query}) async {
    final stmt = _db.select(_db.suppliers);
    if (query != null && query.trim().isNotEmpty) {
      final like = '%${query.trim()}%';
      stmt.where(
        (t) =>
            t.name.like(like) |
            t.companyName.like(like) |
            t.phone.like(like),
      );
    }
    stmt.orderBy([
      (t) => OrderingTerm.asc(t.companyName),
      (t) => OrderingTerm.asc(t.name),
    ]);
    final rows = await stmt.get();
    return rows.map((r) => r.toEntity()).toList(growable: false);
  }

  @override
  Future<Supplier?> getById(int id) async {
    final row = await (_db.select(_db.suppliers)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row?.toEntity();
  }

  @override
  Future<int> create(Supplier supplier) =>
      _db.into(_db.suppliers).insert(supplier.toCompanion());

  @override
  Future<void> update(Supplier supplier) async {
    final id = supplier.id;
    if (id == null) {
      throw ArgumentError('Identifiant de fournisseur manquant.');
    }
    await (_db.update(_db.suppliers)..where((t) => t.id.equals(id)))
        .write(supplier.toCompanion());
  }

  @override
  Future<void> delete(int id) async {
    // Les produits rattachés sont détachés (`supplier_id` → NULL) par la
    // contrainte `ON DELETE SET NULL` définie sur la table.
    await (_db.delete(_db.suppliers)..where((t) => t.id.equals(id))).go();
  }

  @override
  Future<int> countProducts(int supplierId) async {
    final count = _db.products.id.count();
    final stmt = _db.selectOnly(_db.products)
      ..addColumns([count])
      ..where(_db.products.supplierId.equals(supplierId));
    final row = await stmt.getSingle();
    return row.read(count) ?? 0;
  }
}
