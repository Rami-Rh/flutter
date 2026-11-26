import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gestion_stock/app/providers/repository_providers.dart';
import 'package:gestion_stock/core/money/money.dart';
import 'package:gestion_stock/core/quantity/quantity.dart';
import 'package:gestion_stock/domain/entities/app_settings.dart';
import 'package:gestion_stock/domain/entities/catalog.dart';
import 'package:gestion_stock/domain/entities/sale.dart';
import 'package:gestion_stock/domain/enums/enums.dart';
import 'package:gestion_stock/domain/repositories/sale_repository.dart';
import 'package:gestion_stock/domain/repositories/settings_repository.dart';
import 'package:gestion_stock/domain/units/units.dart';
import 'package:mocktail/mocktail.dart';

import '../catalog/catalog_test_support.dart';

/// Dépôt de ventes espionné (aucun accès base dans les tests).
class MockSaleRepository extends Mock implements SaleRepository {}

/// Dépôt de paramètres espionné (`settingsProvider` s'y abonne).
class MockSettingsRepository extends Mock implements SettingsRepository {}

/// Valeur de repli des matchers `any()` sur [SaleDraft].
class FakeSaleDraft extends Fake implements SaleDraft {}

/// Produit vendu à la pièce (carton optionnel).
Product pieceProduct({
  int id = 1,
  String name = 'Eau minérale',
  String barcode = '2000000000001',
  int? piecesPerCarton,
  Money retailPrice = const Money.fromMillimes(500),
  Money wholesalePrice = const Money.fromMillimes(400),
  Money purchasePrice = const Money.fromMillimes(300),
  Qty quantityOnHand = const Qty.fromMilliUnits(100000),
}) =>
    Product(
      id: id,
      name: name,
      barcode: barcode,
      packaging: PackagingConfig.pieces(piecesPerCarton: piecesPerCarton),
      quantityOnHand: quantityOnHand,
      purchasePrice: purchasePrice,
      retailPrice: retailPrice,
      wholesalePrice: wholesalePrice,
    );

/// Produit vendu au kilo (sac optionnel).
Product kgProduct({
  int id = 2,
  String name = 'Pommes de terre',
  String barcode = '2000000000002',
  num? kgPerSack,
  Money retailPrice = const Money.fromMillimes(1200),
  Money wholesalePrice = const Money.fromMillimes(1000),
  Money purchasePrice = const Money.fromMillimes(800),
  Qty quantityOnHand = const Qty.fromMilliUnits(50000),
}) =>
    Product(
      id: id,
      name: name,
      barcode: barcode,
      packaging: PackagingConfig.kilograms(kgPerSack: kgPerSack),
      quantityOnHand: quantityOnHand,
      purchasePrice: purchasePrice,
      retailPrice: retailPrice,
      wholesalePrice: wholesalePrice,
    );

/// Ligne d'une vente enregistrée (3 pièces à 0,500 D par défaut).
SaleItem sampleSaleItem({
  int productId = 1,
  String? productName = 'Eau minérale',
  PackagingUnit packagingUnit = PackagingUnit.base,
  Qty quantityBase = const Qty.fromMilliUnits(3000),
  Qty quantityInPackaging = const Qty.fromMilliUnits(3000),
  Money unitPrice = const Money.fromMillimes(500),
  Money unitCost = const Money.fromMillimes(300),
  Money lineTotal = const Money.fromMillimes(1500),
  Money lineProfit = const Money.fromMillimes(600),
}) =>
    SaleItem(
      productId: productId,
      packagingUnit: packagingUnit,
      quantityBase: quantityBase,
      quantityInPackaging: quantityInPackaging,
      unitPrice: unitPrice,
      unitCost: unitCost,
      lineTotal: lineTotal,
      lineProfit: lineProfit,
      productName: productName,
    );

/// Vente neutre pour les listes et l'écran de détail.
Sale sampleSale({
  int id = 1,
  DateTime? date,
  SaleMode mode = SaleMode.retail,
  Money subtotal = const Money.fromMillimes(1500),
  Money discount = Money.zero,
  Money total = const Money.fromMillimes(1500),
  Money totalCost = const Money.fromMillimes(900),
  Money profit = const Money.fromMillimes(600),
  bool isCancelled = false,
  List<SaleItem> items = const <SaleItem>[],
}) =>
    Sale(
      id: id,
      date: date ?? DateTime(2026, 11, 26, 14, 35),
      mode: mode,
      subtotal: subtotal,
      discount: discount,
      total: total,
      totalCost: totalCost,
      profit: profit,
      isCancelled: isCancelled,
      items: items,
    );

/// Surcharges communes aux écrans de ventes : dépôt de ventes et paramètres.
List<Override> salesOverrides({
  required MockSaleRepository sales,
  required MockSettingsRepository settings,
  MockProductRepository? products,
}) =>
    <Override>[
      saleRepositoryProvider.overrideWithValue(sales),
      settingsRepositoryProvider.overrideWithValue(settings),
      if (products != null)
        productRepositoryProvider.overrideWithValue(products),
    ];

/// Prépare [repository] pour émettre [value] (paramètres par défaut sinon).
void stubSettingsWatch(MockSettingsRepository repository, [AppSettings? value]) {
  when(() => repository.watch()).thenAnswer(
    (_) => Stream<AppSettings>.value(value ?? AppSettings.defaults),
  );
}
