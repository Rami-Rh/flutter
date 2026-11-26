import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_stock/core/errors/failures.dart';
import 'package:gestion_stock/core/money/money.dart';
import 'package:gestion_stock/core/quantity/quantity.dart';
import 'package:gestion_stock/domain/enums/enums.dart';
import 'package:gestion_stock/domain/units/units.dart';

void main() {
  group('UnitConverter — conversions carton / pièce', () {
    const config = PackagingConfig(
      baseUnit: StockBaseUnit.piece,
      piecesPerCarton: 12,
    );

    test('quantité contenue dans un conditionnement', () {
      expect(config.quantityPerPackaging(PackagingUnit.base), Qty.pieces(1));
      expect(config.quantityPerPackaging(PackagingUnit.carton), Qty.pieces(12));
    });

    test('conversion carton -> unité de base', () {
      expect(
        UnitConverter.toBaseUnit(Qty.pieces(2), PackagingUnit.carton, config),
        Qty.pieces(24),
      );
    });

    test('conversion unité de base -> carton', () {
      expect(
        UnitConverter.fromBaseUnit(Qty.pieces(24), PackagingUnit.carton, config),
        Qty.pieces(2),
      );
    });

    test('prix d\'un carton déduit du prix à la pièce', () {
      final pricePerPiece = Money.fromDecimal(0.25);
      expect(
        UnitConverter.pricePerPackaging(
          pricePerPiece,
          PackagingUnit.carton,
          config,
        ),
        Money.fromDecimal(3.0),
      );
    });

    test('décomposition 26 pièces = 2 cartons + 2 pièces', () {
      final breakdown = UnitConverter.breakdown(
        Qty.pieces(26),
        PackagingUnit.carton,
        config,
      );
      expect(breakdown.packagings, 2);
      expect(breakdown.remainder, Qty.pieces(2));
    });

    test('carton interdit sur un produit vendu au kilo', () {
      const kgConfig = PackagingConfig(baseUnit: StockBaseUnit.kilogram);
      expect(
        () => UnitConverter.toBaseUnit(
          Qty.pieces(1),
          PackagingUnit.carton,
          kgConfig,
        ),
        throwsA(isA<AppFailure>()),
      );
    });
  });

  group('UnitConverter — conversions sac / kilo', () {
    const config = PackagingConfig(
      baseUnit: StockBaseUnit.kilogram,
      kgPerSack: 50,
    );

    test('sac de 50 kg', () {
      expect(config.quantityPerPackaging(PackagingUnit.sack), Qty.kilograms(50));
    });

    test('2 sacs = 100 kg', () {
      expect(
        UnitConverter.toBaseUnit(Qty.fromUnits(2), PackagingUnit.sack, config),
        Qty.kilograms(100),
      );
    });

    test('vente au kilo fractionnaire', () {
      expect(
        UnitConverter.toBaseUnit(Qty.kilograms(1.5), PackagingUnit.base, config),
        Qty.kilograms(1.5),
      );
    });

    test('prix d\'un sac de 50 kg à 2,400 D/kg', () {
      expect(
        UnitConverter.pricePerPackaging(
          Money.fromDecimal(2.4),
          PackagingUnit.sack,
          config,
        ),
        Money.fromDecimal(120.0),
      );
    });

    test('disponibilité des conditionnements', () {
      expect(
        config.availableUnits,
        <PackagingUnit>[PackagingUnit.base, PackagingUnit.sack],
      );
    });
  });
}
