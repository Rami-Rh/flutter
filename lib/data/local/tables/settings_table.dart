import 'package:drift/drift.dart';

import '../../../domain/enums/enums.dart';

/// Paramètres de l'application (ligne unique, `id = 1`).
@DataClassName('SettingRow')
class Settings extends Table {
  /// Toujours `1` : une seule ligne de paramètres.
  IntColumn get id => integer()();

  /// Langue de l'interface (`ar` / `fr`).
  TextColumn get languageCode =>
      text().withDefault(const Constant('fr'))();

  /// Thème (`system` / `light` / `dark`).
  TextColumn get themeMode => textEnum<AppThemeMode>()();

  /// Devise.
  TextColumn get currencyCode =>
      text().withDefault(const Constant('TND'))();

  TextColumn get currencySymbol =>
      text().withDefault(const Constant('DT'))();

  IntColumn get currencyDecimalDigits => integer().withDefault(const Constant(3))();

  /// Identité du magasin (affichée sur les tickets et rapports).
  TextColumn get storeName => text().nullable()();

  TextColumn get storeLogoPath => text().nullable()();

  /// Imprimante thermique Bluetooth mémorisée.
  TextColumn get printerAddress => text().nullable()();

  TextColumn get printerName => text().nullable()();

  /// Largeur du papier thermique (mm) : 58 ou 80.
  IntColumn get paperWidthMm => integer().withDefault(const Constant(58))();

  /// Préfixe GS1 des codes-barres internes générés (200–299).
  TextColumn get barcodeEanPrefix =>
      text().withDefault(const Constant('200'))();

  /// Notifications locales d'alerte de stock.
  BoolColumn get lowStockNotificationsEnabled =>
      boolean().withDefault(const Constant(true))();

  /// Chiffrement de la base activé (SQLCipher).
  BoolColumn get encryptionEnabled =>
      boolean().withDefault(const Constant(false))();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
