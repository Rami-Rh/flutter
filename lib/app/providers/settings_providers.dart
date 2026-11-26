import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/app_settings.dart';
import '../../domain/enums/enums.dart';
import '../../domain/repositories/settings_repository.dart';
import 'repository_providers.dart';

/// Paramètres courants (langue, thème, devise…), émis à chaque enregistrement.
final StreamProvider<AppSettings> settingsProvider =
    StreamProvider<AppSettings>(
  (Ref ref) => ref.watch(settingsRepositoryProvider).watch(),
  name: 'settingsProvider',
);

/// Écriture des paramètres (l'affichage passe par [settingsProvider]).
final Provider<SettingsController> settingsControllerProvider =
    Provider<SettingsController>(
  SettingsController.new,
  name: 'settingsControllerProvider',
);

/// Modifie et enregistre les paramètres (langue, thème…).
class SettingsController {
  SettingsController(this._ref);

  final Ref _ref;

  SettingsRepository get _repository => _ref.read(settingsRepositoryProvider);

  /// Applique [transform] aux paramètres courants puis les enregistre.
  Future<void> update(AppSettings Function(AppSettings current) transform) async {
    final current = await _repository.get();
    await _repository.save(transform(current));
  }

  /// Change la langue de l'interface (arabe RTL / français).
  Future<void> setLanguage(AppLanguage language) =>
      update((current) => current.copyWith(language: language));

  /// Change le thème (système / clair / sombre).
  Future<void> setThemeMode(AppThemeMode mode) =>
      update((current) => current.copyWith(themeMode: mode));
}
