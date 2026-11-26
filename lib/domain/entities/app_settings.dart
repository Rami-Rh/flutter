import 'package:meta/meta.dart';

import '../../core/constants/app_constants.dart';
import '../enums/enums.dart';

/// Paramètres de l'application (ligne unique).
///
/// Regroupe la langue, le thème, la devise, l'identité du magasin,
/// l'imprimante thermique et les options d'alerte / de chiffrement.
@immutable
class AppSettings {
  const AppSettings({
    this.language = AppLanguage.fr,
    this.themeMode = AppThemeMode.system,
    this.currencyCode = AppConstants.defaultCurrencyCode,
    this.currencySymbol = AppConstants.defaultCurrencySymbol,
    this.currencyDecimalDigits = AppConstants.defaultCurrencyDecimalDigits,
    this.storeName,
    this.storeLogoPath,
    this.printerAddress,
    this.printerName,
    this.paperWidthMm = 58,
    this.barcodeEanPrefix = '200',
    this.lowStockNotificationsEnabled = true,
    this.encryptionEnabled = false,
    this.updatedAt,
  });

  /// Paramètres par défaut (premier lancement).
  static const AppSettings defaults = AppSettings();

  final AppLanguage language;
  final AppThemeMode themeMode;

  final String currencyCode;
  final String currencySymbol;
  final int currencyDecimalDigits;

  /// Nom du magasin affiché sur les tickets et rapports.
  final String? storeName;

  /// Chemin local du logo du magasin.
  final String? storeLogoPath;

  /// Imprimante thermique Bluetooth mémorisée.
  final String? printerAddress;
  final String? printerName;

  /// Largeur du papier thermique (mm) : 58 ou 80.
  final int paperWidthMm;

  /// Préfixe GS1 des codes-barres internes générés (200–299).
  final String barcodeEanPrefix;

  final bool lowStockNotificationsEnabled;

  /// Chiffrement de la base activé (SQLCipher).
  final bool encryptionEnabled;

  final DateTime? updatedAt;

  /// Vrai si une imprimante a été mémorisée.
  bool get hasPrinter =>
      printerAddress != null && printerAddress!.trim().isNotEmpty;

  AppSettings copyWith({
    AppLanguage? language,
    AppThemeMode? themeMode,
    String? currencyCode,
    String? currencySymbol,
    int? currencyDecimalDigits,
    String? storeName,
    String? storeLogoPath,
    String? printerAddress,
    String? printerName,
    int? paperWidthMm,
    String? barcodeEanPrefix,
    bool? lowStockNotificationsEnabled,
    bool? encryptionEnabled,
    DateTime? updatedAt,
  }) =>
      AppSettings(
        language: language ?? this.language,
        themeMode: themeMode ?? this.themeMode,
        currencyCode: currencyCode ?? this.currencyCode,
        currencySymbol: currencySymbol ?? this.currencySymbol,
        currencyDecimalDigits:
            currencyDecimalDigits ?? this.currencyDecimalDigits,
        storeName: storeName ?? this.storeName,
        storeLogoPath: storeLogoPath ?? this.storeLogoPath,
        printerAddress: printerAddress ?? this.printerAddress,
        printerName: printerName ?? this.printerName,
        paperWidthMm: paperWidthMm ?? this.paperWidthMm,
        barcodeEanPrefix: barcodeEanPrefix ?? this.barcodeEanPrefix,
        lowStockNotificationsEnabled:
            lowStockNotificationsEnabled ?? this.lowStockNotificationsEnabled,
        encryptionEnabled: encryptionEnabled ?? this.encryptionEnabled,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSettings &&
          other.language == language &&
          other.themeMode == themeMode &&
          other.currencyCode == currencyCode &&
          other.currencySymbol == currencySymbol &&
          other.currencyDecimalDigits == currencyDecimalDigits &&
          other.storeName == storeName &&
          other.storeLogoPath == storeLogoPath &&
          other.printerAddress == printerAddress &&
          other.printerName == printerName &&
          other.paperWidthMm == paperWidthMm &&
          other.barcodeEanPrefix == barcodeEanPrefix &&
          other.lowStockNotificationsEnabled == lowStockNotificationsEnabled &&
          other.encryptionEnabled == encryptionEnabled);

  @override
  int get hashCode => Object.hash(
        language,
        themeMode,
        currencyCode,
        currencySymbol,
        currencyDecimalDigits,
        storeName,
        storeLogoPath,
        printerAddress,
        printerName,
        paperWidthMm,
        barcodeEanPrefix,
        lowStockNotificationsEnabled,
        encryptionEnabled,
      );
}
