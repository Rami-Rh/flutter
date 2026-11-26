import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_stock/core/security/password_hasher.dart';

void main() {
  // Peu d'itérations pour garder les tests rapides (l'algorithme est identique).
  const hasher = PasswordHasher(iterations: 1000);

  group('PasswordHasher — hachage', () {
    test('le sel décodé fait la longueur attendue', () {
      final salt = PasswordHasher.generateSalt(random: Random(1));
      expect(base64Decode(salt).length, PasswordHasher.saltLengthBytes);
    });

    test('deux sels successifs sont différents', () {
      final a = PasswordHasher.generateSalt();
      final b = PasswordHasher.generateSalt();
      expect(a, isNot(equals(b)));
    });

    test('même secret + même sel ⇒ même empreinte', () async {
      final salt = PasswordHasher.generateSalt(random: Random(2));
      final first = await hasher.hash('secret', saltBase64: salt);
      final second = await hasher.hash('secret', saltBase64: salt);
      expect(first, second);
    });

    test('sels différents ⇒ empreintes différentes', () async {
      final first = await hasher.hash(
        'secret',
        saltBase64: PasswordHasher.generateSalt(random: Random(3)),
      );
      final second = await hasher.hash(
        'secret',
        saltBase64: PasswordHasher.generateSalt(random: Random(4)),
      );
      expect(first, isNot(equals(second)));
    });

    test('l\'empreinte ne contient jamais le secret en clair', () async {
      const secret = 'MonMotDePasse123';
      final hash = await hasher.hash(
        secret,
        saltBase64: PasswordHasher.generateSalt(random: Random(5)),
      );
      expect(base64Decode(hash), isNot(equals(utf8.encode(secret))));
      expect(hash, isNot(contains(secret)));
    });
  });

  group('PasswordHasher — vérification', () {
    test('accepte le bon secret et rejette les autres', () async {
      final salt = PasswordHasher.generateSalt(random: Random(6));
      final hash = await hasher.hash('correct', saltBase64: salt);

      expect(
        await hasher.verify('correct', hashBase64: hash, saltBase64: salt),
        isTrue,
      );
      expect(
        await hasher.verify('incorrect', hashBase64: hash, saltBase64: salt),
        isFalse,
      );
      expect(
        await hasher.verify('Correct', hashBase64: hash, saltBase64: salt),
        isFalse,
      );
    });

    test('rejette si le sel ne correspond pas', () async {
      final hash = await hasher.hash(
        'correct',
        saltBase64: PasswordHasher.generateSalt(random: Random(7)),
      );
      final otherSalt = PasswordHasher.generateSalt(random: Random(8));
      expect(
        await hasher.verify('correct', hashBase64: hash, saltBase64: otherSalt),
        isFalse,
      );
    });

    test('constantTimeEquals compare correctement', () {
      expect(constantTimeEquals(<int>[1, 2, 3], <int>[1, 2, 3]), isTrue);
      expect(constantTimeEquals(<int>[1, 2, 3], <int>[1, 2, 4]), isFalse);
      expect(constantTimeEquals(<int>[1, 2], <int>[1, 2, 3]), isFalse);
      expect(constantTimeEquals(<int>[], <int>[]), isTrue);
    });
  });

  group('RecoveryCode', () {
    test('génère un code groupé par 4, sans caractère ambigu', () {
      final code = RecoveryCode.generate(random: Random(9));
      // 16 caractères + 3 tirets.
      expect(code.length, 16 + 3);
      expect(RegExp(r'^[A-Z0-9]{4}(-[A-Z0-9]{4}){3}$').hasMatch(code), isTrue);
      expect(code.contains(RegExp('[IO01]')), isFalse);
    });

    test('normalise la saisie (casse + séparateurs)', () {
      expect(RecoveryCode.normalize('abcd-efgh'), 'ABCDEFGH');
      expect(RecoveryCode.normalize('a1b2 c3d4'), 'A1B2C3D4');
      expect(RecoveryCode.normalize('AB CD'), 'ABCD');
    });

    test('la forme générée se normalise en texte brut', () {
      final code = RecoveryCode.generate(random: Random(10));
      expect(RecoveryCode.normalize(code), isNot(contains('-')));
      expect(RecoveryCode.normalize(code).length, 16);
    });
  });

  group('PasswordPolicy', () {
    test('exige la longueur minimale', () {
      expect(PasswordPolicy.isAcceptable('a' * PasswordPolicy.minLength), isTrue);
      expect(
        PasswordPolicy.isAcceptable('a' * (PasswordPolicy.minLength - 1)),
        isFalse,
      );
    });
  });
}
