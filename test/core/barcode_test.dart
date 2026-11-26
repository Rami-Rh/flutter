import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_stock/core/barcode/barcode_generator.dart';

void main() {
  group('BarcodeValidator — EAN-13', () {
    test('clé de contrôle connue (400638133393 -> 1)', () {
      expect(BarcodeValidator.ean13CheckDigit('400638133393'), '1');
    });

    test('validation d\'un code réel', () {
      expect(BarcodeValidator.isValidEan13('4006381333931'), isTrue);
      expect(BarcodeValidator.isValidEan13('4006381333932'), isFalse);
    });

    test('rejette les longueurs et caractères invalides', () {
      expect(BarcodeValidator.isValidEan13('123'), isFalse);
      expect(BarcodeValidator.isValidEan13('400638133393A'), isFalse);
    });

    test('clé de contrôle : entrée invalide', () {
      expect(
        () => BarcodeValidator.ean13CheckDigit('123'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('détection du format', () {
      expect(BarcodeValidator.detectFormat('4006381333931'), BarcodeFormat.ean13);
      expect(BarcodeValidator.detectFormat('ABC-123'), BarcodeFormat.code128);
      expect(BarcodeValidator.detectFormat(''), isNull);
    });
  });

  group('BarcodeGenerator', () {
    test('génère des EAN-13 valides et uniques', () {
      final generator = BarcodeGenerator(random: Random(42));
      final taken = <String>{};

      for (var i = 0; i < 200; i++) {
        final code = generator.generateEan13(isTaken: taken.contains);
        expect(BarcodeValidator.isValidEan13(code), isTrue);
        expect(code.startsWith('200'), isTrue);
        expect(taken.add(code), isTrue, reason: 'doublon généré : $code');
      }
    });

    test('réessaie quand le code est déjà pris', () {
      final generator = BarcodeGenerator(random: Random(7));
      var calls = 0;
      // Les 3 premières tentatives sont « déjà prises ».
      final code = generator.generateEan13(
        isTaken: (_) => calls++ < 3,
      );
      expect(calls, greaterThan(3));
      expect(BarcodeValidator.isValidEan13(code), isTrue);
    });

    test('échoue explicitement si aucun code n\'est disponible', () {
      final generator = BarcodeGenerator(random: Random(1));
      expect(
        () => generator.generateEan13(isTaken: (_) => true),
        throwsA(isA<StateError>()),
      );
    });

    test('préfixe personnalisé respecté', () {
      final generator = BarcodeGenerator(random: Random(3));
      final code = generator.generateEan13(
        isTaken: (_) => false,
        prefix: '299',
      );
      expect(code.startsWith('299'), isTrue);
      expect(BarcodeValidator.isValidEan13(code), isTrue);
    });

    test('génère des Code128 alphanumériques uniques', () {
      final generator = BarcodeGenerator(random: Random(11));
      final taken = <String>{};
      for (var i = 0; i < 100; i++) {
        final code = generator.generateCode128(isTaken: taken.contains);
        expect(BarcodeValidator.isValidCode128(code), isTrue);
        expect(taken.add(code), isTrue);
      }
    });

    test('generate() route vers le bon format', () {
      final generator = BarcodeGenerator(random: Random(5));
      final ean = generator.generate(
        format: BarcodeFormat.ean13,
        isTaken: (_) => false,
      );
      expect(BarcodeValidator.isValidEan13(ean), isTrue);
    });
  });
}
