import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/entities/app_settings.dart';
import '../domain/enums/enums.dart';
import '../l10n/generated/app_localizations.dart';
import 'providers/settings_providers.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

/// Racine de l'application : thème clair/sombre, langue (arabe RTL /
/// français) et routeur avec garde d'authentification.
class GestionStockApp extends ConsumerWidget {
  const GestionStockApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppSettings settings =
        ref.watch(settingsProvider).valueOrNull ?? AppSettings.defaults;
    final GoRouter router = ref.watch(routerProvider);

    return MaterialApp.router(
      onGenerateTitle: (BuildContext context) =>
          AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _themeMode(settings.themeMode),
      locale: Locale(settings.language.code),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: router,
    );
  }

  static ThemeMode _themeMode(AppThemeMode mode) => switch (mode) {
        AppThemeMode.system => ThemeMode.system,
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
      };
}
