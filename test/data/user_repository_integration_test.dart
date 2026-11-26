import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_stock/core/errors/failures.dart';
import 'package:gestion_stock/core/security/password_hasher.dart';
import 'package:gestion_stock/data/local/database.dart';
import 'package:gestion_stock/data/repositories/drift_user_repository.dart';
import 'package:gestion_stock/domain/entities/user.dart';

void main() {
  late AppDatabase db;
  late DriftUserRepository users;

  // Peu d'itérations pour garder les tests rapides.
  const hasher = PasswordHasher(iterations: 1000);

  setUp(() {
    db = AppDatabase.memory();
    users = DriftUserRepository(db, hasher: hasher);
  });

  tearDown(() async {
    await db.close();
  });

  UserRegistration registration({
    String email = 'Boutique@Example.TN',
    String password = 'pass123',
    String recoveryCode = 'ABCD-EFGH-JKLM-NPQR',
    String? hint = 'Carnet rouge',
    String question = 'Ville de naissance ?',
    String answer = 'Tunis',
  }) =>
      UserRegistration(
        email: email,
        password: password,
        recoveryCode: recoveryCode,
        recoveryCodeHint: hint,
        secretQuestion: question,
        secretAnswer: answer,
      );

  group('Compte utilisateur', () {
    test('aucun compte puis création', () async {
      expect(await users.hasUser(), isFalse);
      expect(await users.getUser(), isNull);

      final user = await users.register(registration());
      expect(user.id, isNotNull);
      expect(await users.hasUser(), isTrue);
    });

    test('l\'email est normalisé (minuscules + espaces)', () async {
      final user = await users.register(registration(email: '  Boutique@Example.TN '));
      expect(user.email, 'boutique@example.tn');
    });

    test('un second compte est refusé', () async {
      await users.register(registration());
      await expectLater(
        users.register(registration(email: 'autre@example.tn')),
        throwsA(
          isA<AppFailure>().having(
            (e) => e.code,
            'code',
            FailureCode.duplicateEmail,
          ),
        ),
      );
    });

    test('mot de passe trop court refusé', () async {
      await expectLater(
        users.register(registration(password: '123')),
        throwsA(
          isA<AppFailure>().having(
            (e) => e.code,
            'code',
            FailureCode.weakPassword,
          ),
        ),
      );
    });

    test('dispositif de récupération incomplet refusé', () async {
      await expectLater(
        users.register(registration(recoveryCode: '   ')),
        throwsA(
          isA<AppFailure>().having(
            (e) => e.code,
            'code',
            FailureCode.validation,
          ),
        ),
      );
    });

    test('watchUser émet le compte créé', () async {
      expect(await users.watchUser().first, isNull);

      await users.register(registration());

      final emitted = await users.watchUser().firstWhere((u) => u != null);
      expect(emitted?.email, 'boutique@example.tn');
    });
  });

  group('Authentification', () {
    test('mot de passe correct accepté + dernière connexion mise à jour', () async {
      await users.register(registration());

      final before = (await users.getUser())!.lastLoginAt;
      expect(before, isNull);

      final user = await users.authenticate(
        email: 'boutique@example.tn',
        password: 'pass123',
      );
      expect(user.lastLoginAt, isNotNull);
    });

    test('email insensible à la casse', () async {
      await users.register(registration());
      final user = await users.authenticate(
        email: 'BOUTIQUE@example.tn',
        password: 'pass123',
      );
      expect(user.email, 'boutique@example.tn');
    });

    test('mot de passe incorrect refusé', () async {
      await users.register(registration());
      await expectLater(
        users.authenticate(email: 'boutique@example.tn', password: 'mauvais'),
        throwsA(
          isA<AppFailure>().having(
            (e) => e.code,
            'code',
            FailureCode.invalidCredentials,
          ),
        ),
      );
    });

    test('email inconnu refusé', () async {
      await users.register(registration());
      await expectLater(
        users.authenticate(email: 'inconnu@example.tn', password: 'pass123'),
        throwsA(
          isA<AppFailure>().having(
            (e) => e.code,
            'code',
            FailureCode.invalidCredentials,
          ),
        ),
      );
    });
  });

  group('Récupération hors-ligne', () {
    test('code de récupération tolérant à la saisie', () async {
      await users.register(registration());

      expect(
        await users.verifyRecoveryCode(
          email: 'boutique@example.tn',
          recoveryCode: 'ABCD-EFGH-JKLM-NPQR',
        ),
        isTrue,
      );
      expect(
        await users.verifyRecoveryCode(
          email: 'boutique@example.tn',
          recoveryCode: 'abcd efgh jklm npqr',
        ),
        isTrue,
      );
      expect(
        await users.verifyRecoveryCode(
          email: 'boutique@example.tn',
          recoveryCode: 'ABCD-EFGH-JKLM-XXXX',
        ),
        isFalse,
      );
    });

    test('réponse secrète insensible à la casse et aux espaces', () async {
      await users.register(registration());

      expect(
        await users.verifySecretAnswer(
          email: 'boutique@example.tn',
          answer: 'TUNIS',
        ),
        isTrue,
      );
      expect(
        await users.verifySecretAnswer(
          email: 'boutique@example.tn',
          answer: '  tunis ',
        ),
        isTrue,
      );
      expect(
        await users.verifySecretAnswer(
          email: 'boutique@example.tn',
          answer: 'Sfax',
        ),
        isFalse,
      );
    });

    test('réinitialisation du mot de passe', () async {
      await users.register(registration());

      await users.resetPassword(
        email: 'boutique@example.tn',
        newPassword: 'nouveau123',
      );

      // L'ancien mot de passe ne fonctionne plus.
      await expectLater(
        users.authenticate(email: 'boutique@example.tn', password: 'pass123'),
        throwsA(isA<AppFailure>()),
      );
      // Le nouveau fonctionne.
      final user = await users.authenticate(
        email: 'boutique@example.tn',
        password: 'nouveau123',
      );
      expect(user.email, 'boutique@example.tn');
    });

    test('nouveau mot de passe trop court refusé', () async {
      await users.register(registration());
      await expectLater(
        users.resetPassword(email: 'boutique@example.tn', newPassword: '12'),
        throwsA(
          isA<AppFailure>().having(
            (e) => e.code,
            'code',
            FailureCode.weakPassword,
          ),
        ),
      );
    });
  });

  group('Blocage de la question secrète', () {
    Future<bool> wrongAnswer() => users.verifySecretAnswer(
          email: 'boutique@example.tn',
          answer: 'fausse réponse',
        );

    test('cinq échecs déclenchent le blocage temporaire', () async {
      await users.register(registration());

      for (int i = 0; i < 4; i++) {
        expect(await wrongAnswer(), isFalse);
      }
      final status = await users.recoveryStatus();
      expect(status.remainingAttempts, 1);
      expect(status.isLockedAt(DateTime.now()), isFalse);

      // Le 5e échec épuise la série : blocage immédiat.
      await expectLater(
        wrongAnswer(),
        throwsA(
          isA<AppFailure>().having(
            (e) => e.code,
            'code',
            FailureCode.recoveryLocked,
          ),
        ),
      );

      final locked = await users.recoveryStatus();
      expect(locked.remainingAttempts, 0);
      expect(locked.lockLevel, 1);
      expect(locked.isLockedAt(DateTime.now()), isTrue);
      expect(locked.remainingLockAt(DateTime.now()).inMinutes, greaterThan(0));

      // Tant que le blocage court, toute vérification est refusée.
      await expectLater(wrongAnswer(), throwsA(isA<AppFailure>()));
    });

    test('une bonne réponse remet le compteur d\'échecs à zéro', () async {
      await users.register(registration());

      expect(await wrongAnswer(), isFalse);
      expect(await wrongAnswer(), isFalse);
      expect((await users.recoveryStatus()).remainingAttempts, 3);

      expect(
        await users.verifySecretAnswer(
          email: 'boutique@example.tn',
          answer: 'Tunis',
        ),
        isTrue,
      );

      final status = await users.recoveryStatus();
      expect(status.remainingAttempts, RecoveryLockStatus.maxAttempts);
      expect(status.lockLevel, 0);
      expect(status.isLockedAt(DateTime.now()), isFalse);
    });

    test('la régénération du code de récupération lève le blocage', () async {
      await users.register(registration());

      for (int i = 0; i < 4; i++) {
        await wrongAnswer();
      }
      await expectLater(wrongAnswer(), throwsA(isA<AppFailure>()));

      final newCode = await users.regenerateRecoveryCode(password: 'pass123');
      expect(newCode, isNotEmpty);

      final status = await users.recoveryStatus();
      expect(status.remainingAttempts, RecoveryLockStatus.maxAttempts);
      expect(status.lockLevel, 0);
      expect(status.isLockedAt(DateTime.now()), isFalse);
    });

    test('la réinitialisation du mot de passe lève aussi le blocage', () async {
      await users.register(registration());

      for (int i = 0; i < 4; i++) {
        await wrongAnswer();
      }
      await expectLater(wrongAnswer(), throwsA(isA<AppFailure>()));

      await users.resetPassword(
        email: 'boutique@example.tn',
        newPassword: 'nouveau123',
      );

      final status = await users.recoveryStatus();
      expect(status.remainingAttempts, RecoveryLockStatus.maxAttempts);
      expect(status.isLockedAt(DateTime.now()), isFalse);
    });

    test('la durée de blocage double à chaque série', () {
      expect(
        RecoveryLockStatus.durationForLevel(0),
        const Duration(minutes: 15),
      );
      expect(
        RecoveryLockStatus.durationForLevel(1),
        const Duration(minutes: 30),
      );
      expect(
        RecoveryLockStatus.durationForLevel(2),
        const Duration(minutes: 60),
      );
    });
  });

  group('Régénération du code de récupération', () {
    test('mot de passe incorrect refusé', () async {
      await users.register(registration());
      await expectLater(
        users.regenerateRecoveryCode(password: 'mauvais'),
        throwsA(
          isA<AppFailure>().having(
            (e) => e.code,
            'code',
            FailureCode.invalidCredentials,
          ),
        ),
      );
    });

    test('le nouveau code remplace l\'ancien', () async {
      await users.register(registration());

      final newCode = await users.regenerateRecoveryCode(password: 'pass123');

      expect(
        await users.verifyRecoveryCode(
          email: 'boutique@example.tn',
          recoveryCode: newCode,
        ),
        isTrue,
      );
      expect(
        await users.verifyRecoveryCode(
          email: 'boutique@example.tn',
          recoveryCode: 'ABCD-EFGH-JKLM-NPQR',
        ),
        isFalse,
      );
    });
  });

  group('Biométrie', () {
    test('activation puis désactivation persistées', () async {
      await users.register(registration());
      expect((await users.getUser())!.biometricEnabled, isFalse);

      await users.setBiometricEnabled(true);
      expect((await users.getUser())!.biometricEnabled, isTrue);

      await users.setBiometricEnabled(false);
      expect((await users.getUser())!.biometricEnabled, isFalse);
    });

    test('refus si aucun compte', () async {
      await expectLater(
        users.setBiometricEnabled(true),
        throwsA(
          isA<AppFailure>().having(
            (e) => e.code,
            'code',
            FailureCode.notFound,
          ),
        ),
      );
    });
  });
}
