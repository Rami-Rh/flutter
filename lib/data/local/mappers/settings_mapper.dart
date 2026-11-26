import 'package:drift/drift.dart';

import '../../../domain/entities/app_settings.dart';
import '../../../domain/enums/enums.dart';
import '../database.dart';

/// Ligne unique de paramètres : identifiant fixe.
const int kSettingsRowId = 1;

/// `settings` ↔ [AppSettings]

extension SettingRowMapper on SettingRow {
  AppSettings toEntity() => AppSettings(
        language: AppLanguageX.fromCode(languageCode),
        themeMode: themeMode,
        currencyCode: currencyCode,
        currencySymbol: currencySymbol,
        currencyDecimalDigits: currencyDecimalDigits,
        storeName: storeName,
        storeLogoPath: storeLogoPath,
        printerAddress: printerAddress,
        printerName: printerName,
        paperWidthMm: paperWidthMm,
        barcodeEanPrefix: barcodeEanPrefix,
        lowStockNotificationsEnabled: lowStockNotificationsEnabled,
        encryptionEnabled: encryptionEnabled,
        updatedAt: updatedAt,
      );
}

extension AppSettingsMapper on AppSettings {
  SettingsCompanion toCompanion() => SettingsCompanion(
        id: const Value<int>(kSettingsRowId),
        languageCode: Value<String>(language.code),
        themeMode: Value<AppThemeMode>(themeMode),
        currencyCode: Value<String>(currencyCode),
        currencySymbol: Value<String>(currencySymbol),
        currencyDecimalDigits: Value<int>(currencyDecimalDigits),
        storeName: Value<String?>(storeName),
        storeLogoPath: Value<String?>(storeLogoPath),
        printerAddress: Value<String?>(printerAddress),
        printerName: Value<String?>(printerName),
        paperWidthMm: Value<int>(paperWidthMm),
        barcodeEanPrefix: Value<String>(barcodeEanPrefix),
        lowStockNotificationsEnabled: Value<bool>(lowStockNotificationsEnabled),
        encryptionEnabled: Value<bool>(encryptionEnabled),
        updatedAt: Value<DateTime>(updatedAt ?? DateTime.now()),
      );
}
