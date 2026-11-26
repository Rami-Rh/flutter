import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_stock/app/providers/auth_providers.dart';
import 'package:gestion_stock/core/errors/failures.dart';
import 'package:gestion_stock/domain/entities/user.dart';
import 'package:gestion_stock/features/auth/presentation/login_screen.dart';
import 'package:mocktail/mocktail.dart';

import 'auth_test_support.dart';

void main() {
  late MockUserRepository repository;

  const AppUser user = AppUser(
    id: 1,
    email: 'boutique@example.tn',
    secretQuestion: 'Ville de naissance ?',
  );

  setUp(() {
    repository = MockUserRepository();
    when(() => repository.hasUser()).thenAnswer((_) async => true);
    when(() => repository.getUser()).thenAnswer((_) async => user);
  });

  List<Override> overrides() => <Override>[
        userRepositoryProvider.overrideWithValue(repository),
      ];

  testWidgets('identifiants invalides : le message d\'erreur est affiché',
      (WidgetTester tester) async {
    when(() => repository.authenticate(
          email: any(named: 'email'),
          password: any(named: 'password'),
        )).thenThrow(const AppFailure(FailureCode.invalidCredentials));

    await pumpAuthScreen(
      tester,
      const LoginScreen(),
      overrides: overrides(),
    );

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'boutique@example.tn',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'mauvais');
    await tester.tap(find.text('Se connecter'));
    await tester.pumpAndSettle();

    expect(find.text('E-mail ou mot de passe incorrect.'), findsOneWidget);
    verify(
      () => repository.authenticate(
        email: 'boutique@example.tn',
        password: 'mauvais',
      ),
    ).called(1);
  });

  testWidgets('formulaire vide : erreurs de validation, dépôt non appelé',
      (WidgetTester tester) async {
    await pumpAuthScreen(
      tester,
      const LoginScreen(),
      overrides: overrides(),
    );

    await tester.tap(find.text('Se connecter'));
    await tester.pumpAndSettle();

    expect(find.text('Ce champ est obligatoire.'), findsNWidgets(2));
    verifyNever(
      () => repository.authenticate(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    );
  });

  testWidgets('bouton biométrie masqué quand l\'option est désactivée',
      (WidgetTester tester) async {
    await pumpAuthScreen(
      tester,
      const LoginScreen(),
      overrides: overrides(),
    );

    expect(find.text('Connexion biométrique'), findsNothing);
  });

  testWidgets('bouton biométrie affiché et fonctionnel quand activée',
      (WidgetTester tester) async {
    when(() => repository.getUser()).thenAnswer(
      (_) async => user.copyWith(biometricEnabled: true),
    );
    when(() => repository.recordLogin()).thenAnswer((_) async {});

    final MockBiometricAuthenticator biometric = MockBiometricAuthenticator();
    when(() => biometric.authenticate(reason: any(named: 'reason')))
        .thenAnswer((_) async => true);

    await pumpAuthScreen(
      tester,
      const LoginScreen(),
      overrides: <Override>[
        userRepositoryProvider.overrideWithValue(repository),
        biometricAuthenticatorProvider.overrideWithValue(biometric),
      ],
    );

    expect(find.text('Connexion biométrique'), findsOneWidget);

    await tester.tap(find.text('Connexion biométrique'));
    await tester.pumpAndSettle();

    verify(
      () => biometric.authenticate(reason: any(named: 'reason')),
    ).called(1);
  });
}
