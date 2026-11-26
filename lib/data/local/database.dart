import 'package:drift/drift.dart';

import '../../domain/enums/enums.dart';
import 'connection.dart';
import 'tables/catalog_tables.dart';
import 'tables/purchase_tables.dart';
import 'tables/sale_tables.dart';
import 'tables/settings_table.dart';
import 'tables/stock_movement_table.dart';
import 'tables/users_table.dart';

part 'database.g.dart';

/// Base de données locale de l'application (SQLite / SQLCipher).
///
/// Regroupe les 10 tables du domaine :
/// `users`, `categories`, `suppliers`, `products`, `purchases`,
/// `purchase_items`, `sales`, `sale_items`, `stock_movements`, `settings`.
@DriftDatabase(
  tables: <Type>[
    Users,
    Categories,
    Suppliers,
    Products,
    Purchases,
    PurchaseItems,
    Sales,
    SaleItems,
    StockMovements,
    Settings,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Ouvre la base persistante (avec chiffrement optionnel).
  AppDatabase({
    QueryExecutor? executor,
    String? encryptionKey,
  }) : super(executor ?? openDatabaseConnection(encryptionKey: encryptionKey));

  /// Base en mémoire, réservée aux tests.
  AppDatabase.memory() : super(openInMemoryConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
          await _seed();
        },
        beforeOpen: (OpeningDetails details) async {
          // Les clés étrangères doivent être activées à chaque ouverture.
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  /// Insère la ligne unique de paramètres au premier lancement.
  Future<void> _seed() async {
    await into(settings).insert(
      SettingsCompanion.insert(
        id: const Value<int>(1),
        themeMode: const Value<AppThemeMode>(AppThemeMode.system),
        updatedAt: DateTime.now(),
      ),
      mode: InsertMode.insertOrIgnore,
    );
  }
}
