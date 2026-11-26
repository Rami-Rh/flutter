import '../entities/app_settings.dart';

/// Contrat d'accès aux paramètres de l'application (ligne unique).
abstract interface class SettingsRepository {
  /// Flux des paramètres : émet à chaque enregistrement.
  Stream<AppSettings> watch();

  /// Paramètres courants (ou valeurs par défaut si absents).
  Future<AppSettings> get();

  /// Enregistre les paramètres (langue, thème, devise, magasin, imprimante…).
  Future<void> save(AppSettings settings);
}
