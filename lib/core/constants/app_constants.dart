/// Constantes globales de l'application (valeurs non traduisibles).
abstract final class AppConstants {
  /// Nom du fichier de base de données locale.
  static const String databaseFileName = 'gestion_stock.sqlite';

  /// Clé de stockage sécurisé pour la clé de chiffrement de la base.
  static const String secureStorageDbKeyName = 'db_encryption_key';

  /// Clé de stockage sécurisé pour l'option biometrie.
  static const String secureStorageBiometricFlag = 'biometric_enabled';

  /// Nombre de décimales monétaires par défaut (millimes).
  static const int defaultCurrencyDecimalDigits = 3;

  /// Devise par défaut (modifiable dans les paramètres).
  static const String defaultCurrencyCode = 'TND';
  static const String defaultCurrencySymbol = 'DT';

  /// Longueur du code de récupération hors-ligne.
  static const int recoveryCodeLength = 16;

  /// Locales supportées.
  static const List<String> supportedLanguageCodes = <String>['ar', 'fr'];

  static const String defaultLanguageCode = 'fr';

  /// Longueurs d'impression thermique supportées (mm).
  static const List<int> supportedPaperWidthsMm = <int>[58, 80];
}
