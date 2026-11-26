import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_stock/app/providers/auth_providers.dart';
import 'package:gestion_stock/domain/entities/user.dart';
import 'package:gestion_stock/features/auth/presentation/forgot_password_screen.dart';
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

  testWidgets('code de récupération valide puis définition du mot de passe',
      (WidgetTester tester) async {
    when(() => repository.verifyRecoveryCode(
          email: any(named: 'email'),
          recoveryCode: any(named: 'recoveryCode'),
        )).thenAnswer((_) async => true);
    when(() => repository.resetPassword(
          email: any(named: 'email'),
          newPassword: any(named: 'newPassword'),
        )).thenAnswer((_) async {});

    await pumpAuthScreen(
      tester,
      const ForgotPasswordScreen(),
      overrides: overrides(),
    );

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'ABCD-EFGH-JKLM-NPQR',
    );
    await tester.tap(find.text('Vérifier le code'));
    await tester.pumpAndSettle();

    expect(find.text('Nouveau mot de passe'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'nouveau123');
    await tester.enterText(find.byType(TextFormField).at(1), 'nouveau123');
    await tester.tap(find.text('Définir le mot de passe'));
    await tester.pumpAndSettle();

    verify(
      () => repository.resetPassword(
        email: 'boutique@example.tn',
        newPassword: 'nouveau123',
      ),
    ).called(1);
    expect(find.textContaining('Mot de passe mis à jour'), findsOneWidget);
  });

  testWidgets('code invalide : message d\'erreur, pas de changement d\'étape',
      (WidgetTester tester) async {
    when(() => repository.verifyRecoveryCode(
          email: any(named: 'email'),
          recoveryCode: any(named: 'recoveryCode'),
        )).thenAnswer((_) async => false);

    await pumpAuthScreen(
      tester,
      const ForgotPasswordScreen(),
      overrides: overrides(),
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'AAAA-BBBB-CCCC-DDDD');
    await tester.tap(find.text('Vérifier le code'));
    await tester.pumpAndSettle();

    expect(find.text('Le code de récupération est incorrect.'), findsOneWidget);
    expect(find.text('Nouveau mot de passe'), findsNothing);
  });

  testWidgets('question secrète bloquée : bandeau et bouton désactivé',
      (WidgetTester tester) async {
    when(() => repository.recoveryStatus()).thenAnswer(
      (_) async => RecoveryLockStatus(
        remainingAttempts: 0,
        lockLevel: 1,
        lockedUntil: DateTime.now().add(const Duration(minutes: 15)),
      ),
    );

    await pumpAuthScreen(
      tester,
      const ForgotPasswordScreen(),
      overrides: overrides(),
    );

    await tester.tap(find.text('Question secrète'));
    await tester.pumpAndSettle();

    expect(find.text('Accès temporairement bloqué'), findsOneWidget);

    final FilledButton button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Vérifier la réponse'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('question secrète : essais restants affichés',
      (WidgetTester tester) async {
    when(() => repository.recoveryStatus()).thenAnswer(
      (_) async => const RecoveryLockStatus(
        remainingAttempts: 3,
        lockLevel: 0,
      ),
    );

    await pumpAuthScreen(
      tester,
      const ForgotPasswordScreen(),
      overrides: overrides(),
    );

    await tester.tap(find.text('Question secrète'));
    await tester.pumpAndSettle();

    expect(find.text('Essais restants avant blocage : 3'), findsOneWidget);
    expect(find.text('Ville de naissance ?'), findsOneWidget);
  });
}
