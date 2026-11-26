import 'package:drift/drift.dart';

import '../../domain/entities/app_settings.dart';
import '../../domain/repositories/settings_repository.dart';
import '../local/database.dart';
import '../local/mappers/settings_mapper.dart';

/// Implémentation Drift du contrat [SettingsRepository].
///
/// Une seule ligne (`id = 1`) porte tous les paramètres ; [save] fait un
/// « upsert » (insertion ou mise à jour).
class DriftSettingsRepository implements SettingsRepository {
  DriftSettingsRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<AppSettings> watch() {
    final stmt = _db.select(_db.settings)
      ..where((t) => t.id.equals(kSettingsRowId));
    return stmt.watchSingleOrNull().map(
          (row) => row?.toEntity() ?? AppSettings.defaults,
        );
  }

  @override
  Future<AppSettings> get() async {
    final row = await (_db.select(_db.settings)
          ..where((t) => t.id.equals(kSettingsRowId)))
        .getSingleOrNull();
    return row?.toEntity() ?? AppSettings.defaults;
  }

  @override
  Future<void> save(AppSettings settings) async {
    await _db
        .into(_db.settings)
        .insertOnConflictUpdate(settings.toCompanion());
  }
}
