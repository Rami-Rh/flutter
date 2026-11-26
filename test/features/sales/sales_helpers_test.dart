import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_stock/core/money/money.dart';
import 'package:gestion_stock/core/quantity/quantity.dart';
import 'package:gestion_stock/domain/entities/app_settings.dart';
import 'package:gestion_stock/domain/entities/cart_line.dart';
import 'package:gestion_stock/domain/entities/catalog.dart';
import 'package:gestion_stock/domain/entities/sale.dart';
import 'package:gestion_stock/domain/enums/enums.dart';
import 'package:gestion_stock/domain/units/units.dart';
import 'package:gestion_stock/features/sales/presentation/sales_helpers.dart';
import 'package:gestion_stock/l10n/generated/app_localizations.dart';

void main() {
  late AppLocalizations fr;

  setUpAll(() async {
    fr = await AppLocalizations.delegate.load(const Locale('fr'));
  });

  const AppSettings settings = AppSettings();

  CartLine line({
    required PackagingConfig packaging,
    required PackagingUnit unit,
    required Qty quantity,
  }) =>
      CartLine(
        productId: 1,
        productName: 'Produit',
        barcode: '',
        packaging: packaging,
        packagingUnit: unit,
        quantity: quantity,
        unitPrice: Money.zero,
        unitCost: Money.zero,
      );

  SaleItem item({
    PackagingUnit unit = PackagingUnit.base,
    Qty quantity = const Qty.fromMilliUnits(3000),
  }) =>
      SaleItem(
        productId: 1,
        packagingUnit: unit,
        quantityBase: quantity,
        quantityInPackaging: quantity,
        unitPrice: Money.zero,
        unitCost: Money.zero,
        lineTotal: Money.zero,
        lineProfit: Money.zero,
      );

  test('saleModeLabel traduit le mode de vente', () {
    expect(saleModeLabel(fr, SaleMode.retail), 'Vente au détail');
    expect(saleModeLabel(fr, SaleMode.wholesale), 'Vente en gros');
  });

  test('packagingUnitLabel traduit le conditionnement', () {
    expect(
      packagingUnitLabel(fr, PackagingUnit.base, StockBaseUnit.piece),
      'Pièce',
    );
    expect(
      packagingUnitLabel(fr, PackagingUnit.base, StockBaseUnit.kilogram),
      'Kilogramme',
    );
    expect(
      packagingUnitLabel(fr, PackagingUnit.carton, StockBaseUnit.piece),
      'Carton',
    );
    expect(
      packagingUnitLabel(fr, PackagingUnit.sack, StockBaseUnit.kilogram),
      'Sac',
    );
  });

  test('formatPackagingQuantity : entiers en pièces, décimales au poids', () {
    expect(
      formatPackagingQuantity(
        settings,
        line(
          packaging: PackagingConfig.pieces(),
          unit: PackagingUnit.base,
          quantity: Qty.pieces(3),
        ),
      ),
      '3',
    );
    expect(
      formatPackagingQuantity(
        settings,
        line(
          packaging: PackagingConfig.kilograms(),
          unit: PackagingUnit.base,
          quantity: Qty.kilograms(2.5),
        ),
      ),
      '2,500',
    );
    expect(
      formatPackagingQuantity(
        settings,
        line(
          packaging: PackagingConfig.pieces(piecesPerCarton: 12),
          unit: PackagingUnit.carton,
          quantity: Qty.pieces(2),
        ),
      ),
      '2',
    );
  });

  test('parsePackagingQuantity : entiers sauf le poids à l\'unité de base', () {
    expect(
      parsePackagingQuantity('5', PackagingUnit.base, StockBaseUnit.piece),
      Qty.pieces(5),
    );
    expect(
      parsePackagingQuantity('2,5', PackagingUnit.base, StockBaseUnit.kilogram),
      Qty.kilograms(2.5),
    );
    expect(
      parsePackagingQuantity('2,5', PackagingUnit.base, StockBaseUnit.piece),
      isNull,
    );
    expect(
      parsePackagingQuantity('3', PackagingUnit.carton, StockBaseUnit.piece),
      Qty.pieces(3),
    );
    expect(
      parsePackagingQuantity('2,5', PackagingUnit.carton, StockBaseUnit.piece),
      isNull,
    );
    expect(
      parsePackagingQuantity('', PackagingUnit.sack, StockBaseUnit.kilogram),
      isNull,
    );
  });

  group('saleItemBaseUnit', () {
    final Product kg = Product(
      id: 1,
      name: 'Riz',
      barcode: '2000000000002',
      packaging: PackagingConfig.kilograms(kgPerSack: 25),
      purchasePrice: Money.zero,
      retailPrice: Money.zero,
      wholesalePrice: Money.zero,
    );

    test('le produit prime sur le conditionnement vendu', () {
      expect(saleItemBaseUnit(item(), kg), StockBaseUnit.kilogram);
    });

    test('repli sur le conditionnement quand le produit est absent', () {
      expect(
        saleItemBaseUnit(item(unit: PackagingUnit.sack), null),
        StockBaseUnit.kilogram,
      );
      expect(
        saleItemBaseUnit(item(unit: PackagingUnit.carton), null),
        StockBaseUnit.piece,
      );
    });
  });

  test('formatSaleItemQuantity : décimales seulement au poids de base', () {
    expect(
      formatSaleItemQuantity(
        settings,
        item(quantity: Qty.kilograms(1.25)),
        StockBaseUnit.kilogram,
      ),
      '1,250',
    );
    expect(
      formatSaleItemQuantity(
        settings,
        item(unit: PackagingUnit.carton),
        StockBaseUnit.piece,
      ),
      '3',
    );
  });
}
