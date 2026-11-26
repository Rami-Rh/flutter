import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_stock/core/quantity/quantity.dart';

void main() {
  group('Qty — quantités exactes en milli-unités', () {
    test('construction (pièces, kilos, unités)', () {
      expect(Qty.pieces(12).milliUnits, 12000);
      expect(Qty.kilograms(2.5).milliUnits, 2500);
      expect(Qty.fromUnits(0.5).milliUnits, 500);
      expect(Qty.zero.milliUnits, 0);
    });

    test('conversion vers décimal', () {
      expect(Qty.kilograms(2.5).toDecimal(), 2.5);
      expect(Qty.pieces(3).toDecimal(), 3);
    });

    test('arithmétique', () {
      expect(Qty.pieces(2) + Qty.pieces(3), Qty.pieces(5));
      expect(Qty.pieces(5) - Qty.pieces(2), Qty.pieces(3));
      expect(Qty.kilograms(1.5) + Qty.kilograms(1.5), Qty.kilograms(3));
      expect(-Qty.pieces(2), Qty.pieces(-2));
      expect(Qty.pieces(2) * 3, Qty.pieces(6));
    });

    test('asWholeUnits distingue les quantités fractionnaires', () {
      expect(Qty.pieces(12).asWholeUnits(), 12);
      expect(Qty.kilograms(2.5).asWholeUnits(), isNull);
    });

    test('comparaisons et signes', () {
      expect(Qty.pieces(1) < Qty.pieces(2), isTrue);
      expect(Qty.kilograms(0.5) > Qty.zero, isTrue);
      expect(Qty.zero.isZero, isTrue);
      expect(Qty.pieces(-1).isNegative, isTrue);
    });
  });
}
