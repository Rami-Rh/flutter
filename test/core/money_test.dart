import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_stock/core/money/money.dart';
import 'package:gestion_stock/core/quantity/quantity.dart';

void main() {
  group('Money — précision exacte en millimes', () {
    test('construction depuis un décimal', () {
      expect(Money.fromDecimal(1.4), const Money.fromMillimes(1400));
      expect(const Money.fromMillimes(3450).toDecimal(), 3.45);
      expect(Money.zero, const Money.fromMillimes(0));
    });

    test('aucune perte de précision flottante (0,1 + 0,2 = 0,3)', () {
      final result = Money.fromDecimal(0.1) + Money.fromDecimal(0.2);
      expect(result, Money.fromDecimal(0.3));
      expect(result.millimes, 300);
    });

    test('addition, soustraction et négation', () {
      final a = Money.fromDecimal(10.0);
      final b = Money.fromDecimal(2.5);
      expect(a + b, Money.fromDecimal(12.5));
      expect(a - b, Money.fromDecimal(7.5));
      expect(-b, Money.fromMillimes(-2500));
    });

    test('multiplication par une quantité entière', () {
      final unitPrice = Money.fromDecimal(2.5);
      expect(unitPrice * 4, Money.fromDecimal(10.0));
    });

    test('multiplication par une quantité décimale (2,5 kg × 3,000 D)', () {
      final pricePerKg = Money.fromDecimal(3.0);
      final qty = Qty.kilograms(2.5);
      expect(pricePerKg.timesQuantity(qty), Money.fromDecimal(7.5));
    });

    test('arrondi au millime le plus proche', () {
      // 0,333 D × 3 kg = 0,999 D
      final pricePerKg = Money.fromDecimal(0.333);
      expect(pricePerKg.timesQuantity(Qty.kilograms(3)), Money.fromDecimal(0.999));
      // 1 millime × 1 carton de 12 = 12 millimes
      expect(
        const Money.fromMillimes(1).timesQuantity(Qty.pieces(12)),
        const Money.fromMillimes(12),
      );
    });

    test('pourcentage (remise / TVA)', () {
      expect(Money.fromDecimal(100).percentage(0.19), Money.fromDecimal(19));
      expect(Money.fromDecimal(100).percentage(-0.1), Money.fromDecimal(-10));
    });

    test('somme d\'une collection', () {
      final total = Money.sum(<Money>[
        Money.fromDecimal(1.5),
        Money.fromDecimal(2.25),
        Money.fromDecimal(0.25),
      ]);
      expect(total, Money.fromDecimal(4.0));
      expect(Money.sum(const <Money>[]), Money.zero);
    });

    test('comparaisons', () {
      final small = Money.fromDecimal(1.0);
      final big = Money.fromDecimal(2.0);
      expect(small < big, isTrue);
      expect(big > small, isTrue);
      expect(small <= small, isTrue);
      expect(big >= small, isTrue);
      expect(Money.min(small, big), small);
      expect(Money.max(small, big), big);
    });

    test('valeur absolue et signes', () {
      expect(const Money.fromMillimes(-500).abs, const Money.fromMillimes(500));
      expect(const Money.fromMillimes(-1).isNegative, isTrue);
      expect(Money.zero.isZero, isTrue);
      expect(const Money.fromMillimes(1).isPositive, isTrue);
    });
  });
}
