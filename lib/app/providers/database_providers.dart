import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/database.dart';

/// Base de données locale de l'application, ouverte une seule fois.
///
/// En production elle est persistante (SQLite / SQLCipher) ; dans les tests
/// elle est remplacée par une base en mémoire :
///
/// ```dart
/// ProviderScope(overrides: [
///   databaseProvider.overrideWithValue(AppDatabase.memory()),
/// ])
/// ```
///
/// La clé de chiffrement (Phase 9) sera fournie à l'ouverture ; elle n'est
/// pas nécessaire pour la phase actuelle.
final Provider<AppDatabase> databaseProvider = Provider<AppDatabase>(
  (Ref ref) {
    final db = AppDatabase();
    ref.onDispose(db.close);
    return db;
  },
  name: 'databaseProvider',
);
