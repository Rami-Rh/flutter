import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_stock/core/money/money.dart';
import 'package:gestion_stock/domain/enums/enums.dart';
import 'package:gestion_stock/domain/services/pricing.dart';
import 'package:gestion_stock/domain/units/units.dart';

void main() {
  group('MarginCalculator — marge et taux', () {
    test('marge unitaire = vente - achat', () {
      expect(
        MarginCalculator.unitMargin(
          salePrice: Money.fromDecimal(1.4),
          purchasePrice: Money.fromDecimal(1.0),
        ),
        Money.fromDecimal(0.4),
      );
    });

    test('taux de marge sur le prix d\'achat', () {
      final rate = MarginCalculator.marginRate(
        salePrice: Money.fromDecimal(1.4),
        purchasePrice: Money.fromDecimal(1.0),
      );
      expect(rate, isNotNull);
      expect(rate!, closeTo(0.4, 1e-9));
    });

    test('taux de marque sur le prix de vente', () {
      final rate = MarginCalculator.markupRate(
        salePrice: Money.fromDecimal(1.4),
        purchasePrice: Money.fromDecimal(1.0),
      );
      expect(rate, isNotNull);
      expect(rate!, closeTo(0.2857142857, 1e-9));
    });

    test('taux indéfini quand le diviseur est nul', () {
      expect(
        MarginCalculator.marginRate(
          salePrice: Money.fromDecimal(1.0),
          purchasePrice: Money.zero,
        ),
        isNull,
      );
      expect(
        MarginCalculator.markupRate(
          salePrice: Money.zero,
          purchasePrice: Money.fromDecimal(1.0),
        ),
        isNull,
      );
    });
  });

  group('PricingContext — prix selon le mode de vente', () {
    const context = PricingContext(
      retailPrice: Money.fromMillimes(250),
      wholesalePrice: Money.fromMillimes(200),
      purchasePrice: Money.fromMillimes(150),
      packaging: PackagingConfig(
        baseUnit: StockBaseUnit.piece,
        piecesPerCarton: 12,
      ),
    );

    test('prix détail vs gros', () {
      expect(context.priceFor(SaleMode.retail), const Money.fromMillimes(250));
      expect(context.priceFor(SaleMode.wholesale), const Money.fromMillimes(200));
    });

    test('prix du carton selon le mode', () {
      expect(
        context.pricePerPackaging(SaleMode.retail, PackagingUnit.carton),
        const Money.fromMillimes(3000),
      );
      expect(
        context.pricePerPackaging(SaleMode.wholesale, PackagingUnit.carton),
        const Money.fromMillimes(2400),
      );
    });

    test('prix du conditionnement de base = prix unitaire', () {
      expect(
        context.pricePerPackaging(SaleMode.retail, PackagingUnit.base),
        const Money.fromMillimes(250),
      );
    });
  });
}
