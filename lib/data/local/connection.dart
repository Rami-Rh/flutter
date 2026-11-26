import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';

import '../../core/constants/app_constants.dart';

/// Ouvre (ou crée) la base de données locale.
///
/// - 100 % hors-ligne : le fichier vit dans le dossier de support de l'app.
/// - Chiffrement optionnel : si [encryptionKey] est fourni, la base est
///   ouverte avec SQLCipher via `PRAGMA key` (AES-256). Sans clé, la base
///   reste une base SQLite standard (les données déjà chiffrées ne seraient
///   alors plus lisibles : la clé doit être la même qu'à la création).
QueryExecutor openDatabaseConnection({
  String fileName = AppConstants.databaseFileName,
  String? encryptionKey,
}) {
  return LazyDatabase(() async {
    // Contournement nécessaire sur les anciennes versions d'Android pour que
    // la bibliothèque SQLCipher soit correctement chargée.
    if (Platform.isAndroid) {
      await applyWorkaroundToOpenSqlCipherOnOldAndroidVersions();
    }

    final directory = await getApplicationSupportDirectory();
    final file = File(p.join(directory.path, fileName));

    return NativeDatabase.createInBackground(
      file,
      setup: (rawDatabase) {
        rawDatabase.execute('PRAGMA foreign_keys = ON;');
        if (encryptionKey != null && encryptionKey.isNotEmpty) {
          // `PRAGMA key` n'accepte pas de paramètre lié : la valeur est
          // échappée manuellement (guillemets simples doublés).
          rawDatabase.execute(
            "PRAGMA key = '${_escapePragmaValue(encryptionKey)}';",
          );
        }
      },
    );
  });
}

/// Ouvre une base **en mémoire** (tests unitaires, aperçus).
QueryExecutor openInMemoryConnection() => NativeDatabase.memory();

String _escapePragmaValue(String value) => value.replaceAll("'", "''");
