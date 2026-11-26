import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_stock/app/providers/auth_providers.dart';
import 'package:gestion_stock/domain/entities/user.dart';
import 'package:gestion_stock/features/auth/presentation/setup_screen.dart';
import 'package:mocktail/mocktail.dart';

import 'auth_test_support.dart';

void main() {
  late MockUserRepository repository;

  const AppUser registered = AppUser(
    id: 1,
    email: 'a@b.com',
    secretQuestion: 'Ville de naissance ?',
  );

  setUpAll(() {
    registerFallbackValue(
      const UserRegistration(
        email: 'fallback@example.com',
        password: 'secret123',
        recoveryCode: 'ABCD-EFGH-JKLM-NPQR',
        secretQuestion: 'Question',
        secretAnswer: 'Réponse',
      ),
    );
  });

  setUp(() {
    repository = MockUserRepository();
    when(() => repository.hasUser()).thenAnswer((_) async => false);
    when(() => repository.getUser()).thenAnswer((_) async => null);
  });

  List<Override> overrides() => <Override>[
        userRepositoryProvider.overrideWithValue(repository),
      ];

  testWidgets('formulaire vide : erreurs de validation, dépôt non appelé',
      (WidgetTester tester) async {
    await pumpAuthScreen(
      tester,
      const SetupScreen(),
      overrides: overrides(),
    );

    await tester.tap(find.text('Créer le compte'));
    await tester.pumpAndSettle();

    expect(find.text('Ce champ est obligatoire.'), findsWidgets);
    verifyNever(() => repository.register(any()));
  });

  testWidgets('mots de passe différents : erreur dédiée', (WidgetTester tester) async {
    await pumpAuthScreen(
      tester,
      const SetupScreen(),
      overrides: overrides(),
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'a@b.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'secret123');
    await tester.enterText(find.byType(TextFormField).at(2), 'secret124');
    await tester.enterText(find.byType(TextFormField).at(3), 'Ville ?');
    await tester.enterText(find.byType(TextFormField).at(4), 'Tunis');

    await tester.tap(find.text('Créer le compte'));
    await tester.pumpAndSettle();

    expect(find.text('Les mots de passe ne correspondent pas.'), findsOneWidget);
    verifyNever(() => repository.register(any()));
  });

  testWidgets('formulaire valide : le compte est créé', (WidgetTester tester) async {
    when(() => repository.register(any())).thenAnswer((_) async => registered);

    await pumpAuthScreen(
      tester,
      const SetupScreen(),
      overrides: overrides(),
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'a@b.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'secret123');
    await tester.enterText(find.byType(TextFormField).at(2), 'secret123');
    await tester.enterText(find.byType(TextFormField).at(3), 'Ville de naissance ?');
    await tester.enterText(find.byType(TextFormField).at(4), 'Tunis');
    await tester.enterText(find.byType(TextFormField).at(5), 'Carnet rouge');

    await tester.tap(find.text('Créer le compte'));
    await tester.pumpAndSettle();

    final UserRegistration captured =
        verify(() => repository.register(captureAny())).captured.single
            as UserRegistration;
    expect(captured.email, 'a@b.com');
    expect(captured.secretQuestion, 'Ville de naissance ?');
    expect(captured.secretAnswer, 'Tunis');
    expect(captured.recoveryCodeHint, 'Carnet rouge');
    // Le code de récupération est généré par le contrôleur, jamais saisi.
    expect(captured.recoveryCode, isNotEmpty);
  });
}
