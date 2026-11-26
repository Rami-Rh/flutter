import 'package:flutter/material.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_stock/core/money/money.dart';
import 'package:gestion_stock/core/quantity/quantity.dart';
import 'package:gestion_stock/domain/entities/app_settings.dart';
import 'package:gestion_stock/domain/enums/enums.dart';
import 'package:gestion_stock/features/catalog/presentation/catalog_helpers.dart';

void main() {
  group('parseMilli', () {
    test('accepte les entiers et les décimales exactes', () {
      expect(parseMilli('1234'), 1234000);
      expect(parseMilli('12,5'), 12500);
      expect(parseMilli('12.5'), 12500);
      expect(parseMilli('0,125'), 125);
    });

    test('rejette les saisies invalides ou trop précises', () {
      expect(parseMilli(''), isNull);
      expect(parseMilli('   '), isNull);
      expect(parseMilli('12.3456'), isNull);
      expect(parseMilli('.5'), isNull);
      expect(parseMilli('abc'), isNull);
      expect(parseMilli('-3'), isNull);
    });
  });

  test('parseMoney conserve la précision au millime', () {
    expect(parseMoney('3,450'), Money.fromMillimes(3450));
    expect(parseMoney('0'), Money.zero);
    expect(parseMoney(''), isNull);
  });

  test('parseDecimal renvoie une valeur numérique exacte', () {
    expect(parseDecimal('2,5'), 2.5);
    expect(parseDecimal('bof'), isNull);
  });

  test('parseIntValue refuse les décimales', () {
    expect(parseIntValue('12'), 12);
    expect(parseIntValue('12,5'), isNull);
    expect(parseIntValue(''), isNull);
  });

  group('parseQuantity', () {
    test('en pièces, seules les quantités entières sont acceptées', () {
      expect(parseQuantity('5', StockBaseUnit.piece), Qty.pieces(5));
      expect(parseQuantity('2,5', StockBaseUnit.piece), isNull);
    });

    test('en kilogrammes, les décimales sont acceptées', () {
      expect(parseQuantity('2,5', StockBaseUnit.kilogram), Qty.kilograms(2.5));
      expect(
        parseQuantity('0,125', StockBaseUnit.kilogram),
        Qty.fromMilliUnits(125),
      );
    });
  });

  group('colorFromHex', () {
    const Color fallback = Color(0xFF123456);

    test('convertit une couleur valide', () {
      expect(colorFromHex('#E53935', fallback), const Color(0xFFE53935));
    });

    test('replie sur la couleur par défaut si le code est invalide', () {
      expect(colorFromHex(null, fallback), fallback);
      expect(colorFromHex('', fallback), fallback);
      expect(colorFromHex('#12345', fallback), fallback);
      expect(colorFromHex('#ZZZZZZ', fallback), fallback);
    });
  });

  test('la palette de catégories ne contient que des codes #RRGGBB valides', () {
    for (final String hex in categoryPalette) {
      expect(
        RegExp(r'^#[0-9A-F]{6}$').hasMatch(hex),
        isTrue,
        reason: '$hex doit respecter le format #RRGGBB',
      );
    }
  });

  test('le formatage localisé respecte la devise et les décimales', () {
    const AppSettings settings = AppSettings();
    expect(
      formatMoney(settings, Money.fromMillimes(3450)),
      contains('3,450'),
    );
    expect(
      formatQuantity(settings, Qty.pieces(3), StockBaseUnit.piece),
      '3',
    );
    expect(
      formatQuantity(settings, Qty.kilograms(2.5), StockBaseUnit.kilogram),
      contains('2,5'),
    );
  });
}
