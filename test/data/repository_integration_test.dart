import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_stock/core/errors/failures.dart';
import 'package:gestion_stock/core/money/money.dart';
import 'package:gestion_stock/core/quantity/quantity.dart';
import 'package:gestion_stock/data/local/database.dart';
import 'package:gestion_stock/data/repositories/drift_category_repository.dart';
import 'package:gestion_stock/data/repositories/drift_product_repository.dart';
import 'package:gestion_stock/data/repositories/drift_purchase_repository.dart';
import 'package:gestion_stock/data/repositories/drift_sale_repository.dart';
import 'package:gestion_stock/data/repositories/drift_settings_repository.dart';
import 'package:gestion_stock/data/repositories/drift_stock_repository.dart';
import 'package:gestion_stock/domain/entities/app_settings.dart';
import 'package:gestion_stock/domain/entities/catalog.dart';
import 'package:gestion_stock/domain/entities/purchase.dart';
import 'package:gestion_stock/domain/entities/sale.dart';
import 'package:gestion_stock/domain/enums/enums.dart';
import 'package:gestion_stock/domain/units/units.dart';

void main() {
  late AppDatabase db;
  late DriftCategoryRepository categories;
  late DriftProductRepository products;
  late DriftStockRepository stock;
  late DriftSaleRepository sales;
  late DriftPurchaseRepository purchases;
  late DriftSettingsRepository settings;

  setUp(() {
    db = AppDatabase.memory();
    categories = DriftCategoryRepository(db);
    products = DriftProductRepository(db);
    stock = DriftStockRepository(db);
    sales = DriftSaleRepository(db);
    purchases = DriftPurchaseRepository(db);
    settings = DriftSettingsRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  /// Produit de test : 10 pièces en stock, achat 1,000 D, détail 2,000 D.
  Future<Product> seedProduct({
    String name = 'Riz',
    String barcode = '',
    Qty onHand = const Qty.fromMilliUnits(10000),
    PackagingConfig packaging = const PackagingConfig(baseUnit: StockBaseUnit.piece),
    int? categoryId,
  }) async {
    final id = await products.create(
      Product(
        name: name,
        barcode: barcode,
        packaging: packaging,
        quantityOnHand: onHand,
        purchasePrice: Money.fromDecimal(1),
        retailPrice: Money.fromDecimal(2),
        wholesalePrice: Money.fromDecimal(1.5),
        lowStockThreshold: Qty.pieces(3),
        categoryId: categoryId,
      ),
    );
    return (await products.getById(id))!;
  }

  group('Catégories', () {
    test('création, lecture et unicité du nom', () async {
      final id = await categories.create(const Category(name: 'Épicerie'));
      final loaded = await categories.getById(id);
      expect(loaded?.name, 'Épicerie');

      await expectLater(
        categories.create(const Category(name: 'Épicerie')),
        throwsA(
          isA<AppFailure>().having(
            (e) => e.code,
            'code',
            FailureCode.duplicateCategoryName,
          ),
        ),
      );
    });

    test('suppression refusée si la catégorie contient des produits', () async {
      final categoryId = await categories.create(const Category(name: 'Boissons'));
      await seedProduct(categoryId: categoryId);

      await expectLater(
        categories.delete(categoryId),
        throwsA(
          isA<AppFailure>().having(
            (e) => e.code,
            'code',
            FailureCode.categoryInUse,
          ),
        ),
      );

      expect(await categories.countProducts(categoryId), 1);
    });
  });

  group('Produits', () {
    test('code-barres généré automatiquement (EAN-13 unique)', () async {
      final product = await seedProduct();
      expect(product.barcode, isNotEmpty);
      expect(product.barcode.length, 13);
      expect(product.barcode.startsWith('200'), isTrue);
    });

    test('refus d\'un code-barres déjà utilisé', () async {
      await seedProduct(name: 'A', barcode: '4006381333931');
      await expectLater(
        seedProduct(name: 'B', barcode: '4006381333931'),
        throwsA(
          isA<AppFailure>().having(
            (e) => e.code,
            'code',
            FailureCode.duplicateBarcode,
          ),
        ),
      );
    });

    test('recherche par code-barres', () async {
      final product = await seedProduct(barcode: '4006381333931');
      final found = await products.getByBarcode('4006381333931');
      expect(found?.id, product.id);
    });

    test('le stock initial est journalisé comme premier mouvement', () async {
      final product = await seedProduct();
      final movements = await stock.movementsOf(product.id!);
      expect(movements, hasLength(1));
      expect(movements.single.type, StockMovementType.initial);
      expect(movements.single.quantity, Qty.pieces(10));
    });

    test('alerte de stock faible', () async {
      await seedProduct(name: 'Faible', onHand: Qty.pieces(2));
      await seedProduct(name: 'Correct', onHand: Qty.pieces(50));
      final low = await products.lowStock();
      expect(low.map((p) => p.name), contains('Faible'));
      expect(low.map((p) => p.name), isNot(contains('Correct')));
    });

    test('valeur du stock au prix d\'achat', () async {
      await seedProduct(onHand: Qty.pieces(10)); // 10 × 1,000 D
      expect(await products.stockValue(), Money.fromDecimal(10));
    });
  });

  group('Ventes', () {
    test('encaissement : ventes, lignes, déduction du stock et bénéfice',
        () async {
      final product = await seedProduct(); // stock 10, achat 1, détail 2
      final draft = SaleDraft(
        mode: SaleMode.retail,
        lines: [
          product.toCartLine(
            mode: SaleMode.retail,
            packagingUnit: PackagingUnit.base,
            quantity: Qty.pieces(3),
          ),
        ],
      );

      final sale = await sales.checkout(draft);

      expect(sale.id, isNotNull);
      expect(sale.total, Money.fromDecimal(6)); // 3 × 2,000
      expect(sale.totalCost, Money.fromDecimal(3)); // 3 × 1,000
      expect(sale.profit, Money.fromDecimal(3));
      expect(sale.items, hasLength(1));

      final reloaded = await products.getById(product.id!);
      expect(reloaded?.quantityOnHand, Qty.pieces(7));

      final movements = await stock.movementsOf(product.id!);
      expect(movements.first.type, StockMovementType.saleOut);
      expect(movements.first.referenceType, MovementReferenceType.sale);
      expect(movements.first.referenceId, sale.id);
    });

    test('annulation : remise en stock et marquage', () async {
      final product = await seedProduct();
      final sale = await sales.checkout(
        SaleDraft(
          mode: SaleMode.retail,
          lines: [
            product.toCartLine(
              mode: SaleMode.retail,
              packagingUnit: PackagingUnit.base,
              quantity: Qty.pieces(4),
            ),
          ],
        ),
      );

      final cancelled = await sales.cancel(sale.id!);
      expect(cancelled.isCancelled, isTrue);

      final reloaded = await products.getById(product.id!);
      expect(reloaded?.quantityOnHand, Qty.pieces(10));

      // Annulation deux fois : refusée.
      await expectLater(sales.cancel(sale.id!), throwsA(isA<AppFailure>()));
    });

    test('résumé des ventes sur une période', () async {
      final product = await seedProduct(); // détail 2,000 D
      final now = DateTime.now();
      await sales.checkout(
        SaleDraft(
          mode: SaleMode.retail,
          lines: [
            product.toCartLine(
              mode: SaleMode.retail,
              packagingUnit: PackagingUnit.base,
              quantity: Qty.pieces(2),
            ),
          ],
        ),
      );

      final summary = await sales.summaryBetween(
        now.subtract(const Duration(days: 1)),
        now.add(const Duration(days: 1)),
      );
      expect(summary.saleCount, 1);
      expect(summary.totalSales, Money.fromDecimal(4));
      expect(summary.totalProfit, Money.fromDecimal(2));
      expect(summary.quantitySold, Qty.pieces(2));
    });

    test('lignes encaissées d\'une période (hors ventes annulées)', () async {
      final product = await seedProduct(); // nom « Riz », détail 2,000 D
      final now = DateTime.now();

      await sales.checkout(
        SaleDraft(
          mode: SaleMode.retail,
          lines: [
            product.toCartLine(
              mode: SaleMode.retail,
              packagingUnit: PackagingUnit.base,
              quantity: Qty.pieces(2),
            ),
          ],
        ),
      );
      final Sale cancelled = await sales.checkout(
        SaleDraft(
          mode: SaleMode.retail,
          lines: [
            product.toCartLine(
              mode: SaleMode.retail,
              packagingUnit: PackagingUnit.base,
              quantity: Qty.pieces(1),
            ),
          ],
        ),
      );
      await sales.cancel(cancelled.id!);

      final List<SaleItem> items = await sales.itemsBetween(
        now.subtract(const Duration(days: 1)),
        now.add(const Duration(days: 1)),
      );

      expect(items, hasLength(1));
      expect(items.single.productName, 'Riz');
      expect(items.single.quantityBase, Qty.pieces(2));
      expect(items.single.lineTotal, Money.fromDecimal(4));
    });

    test('panier vide refusé', () async {
      await expectLater(
        sales.checkout(
          const SaleDraft(mode: SaleMode.retail, lines: []),
        ),
        throwsA(isA<AppFailure>()),
      );
    });
  });

  group('Réapprovisionnement', () {
    test('augmente le stock et met à jour le prix d\'achat', () async {
      final product = await seedProduct(onHand: Qty.pieces(5));

      final purchase = await purchases.register(
        PurchaseDraft(
          supplierId: null,
          lines: [
            PurchaseLineDraft(
              productId: product.id!,
              quantity: Qty.pieces(20),
              unitPurchasePrice: Money.fromDecimal(1.2),
            ),
          ],
        ),
      );

      expect(purchase.totalAmount, Money.fromDecimal(24)); // 20 × 1,200

      final reloaded = await products.getById(product.id!);
      expect(reloaded?.quantityOnHand, Qty.pieces(25));
      expect(reloaded?.purchasePrice, Money.fromDecimal(1.2));

      final movements = await stock.movementsOf(product.id!);
      expect(movements.first.type, StockMovementType.purchaseIn);
    });
  });

  group('Stock — ajustement manuel', () {
    test('recale le stock et journalise l\'écart', () async {
      final product = await seedProduct(onHand: Qty.pieces(10));

      final movement = await stock.adjustTo(
        productId: product.id!,
        newBalance: Qty.pieces(7),
        note: 'Inventaire',
      );

      expect(movement.type, StockMovementType.adjustment);
      expect(movement.quantity, Qty.pieces(-3)); // signé
      expect(movement.balanceAfter, Qty.pieces(7));

      final reloaded = await products.getById(product.id!);
      expect(reloaded?.quantityOnHand, Qty.pieces(7));
      expect(await stock.balanceOf(product.id!), Qty.pieces(7));
    });
  });

  group('Paramètres', () {
    test('les valeurs par défaut sont renvoyées avant tout enregistrement',
        () async {
      final current = await settings.get();
      expect(current.language, AppLanguage.fr);
      expect(current.currencyCode, 'TND');
    });

    test('enregistrement puis lecture (langue arabe)', () async {
      await settings.save(
        (await settings.get()).copyWith(
          language: AppLanguage.ar,
          storeName: 'Épicerie du coin',
          currencySymbol: 'د.ت',
        ),
      );
      final saved = await settings.get();
      expect(saved.language, AppLanguage.ar);
      expect(saved.storeName, 'Épicerie du coin');
      expect(saved.currencySymbol, 'د.ت');
    });
  });
}
