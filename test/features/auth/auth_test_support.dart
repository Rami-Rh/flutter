import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_stock/core/security/biometric_authenticator.dart';
import 'package:gestion_stock/domain/repositories/user_repository.dart';
import 'package:gestion_stock/l10n/generated/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

/// Dépôt utilisateur espionné (aucun accès base dans les tests d'interface).
class MockUserRepository extends Mock implements UserRepository {}

/// Vérification biométrique contrôlée.
class MockBiometricAuthenticator extends Mock
    implements BiometricAuthenticator {}

/// Monte un écran d'authentification isolé, en français, avec les délégations
/// de traduction de l'application.
Future<void> pumpAuthScreen(
  WidgetTester tester,
  Widget screen, {
  List<Override> overrides = const <Override>[],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        locale: const Locale('fr'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: screen,
      ),
    ),
  );
  await tester.pumpAndSettle();
}
