import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_stock/domain/entities/catalog.dart';
import 'package:gestion_stock/features/sales/presentation/sale_cart_screen.dart';
import 'package:gestion_stock/features/sales/presentation/widgets/cart_line_tile.dart';
import 'package:mocktail/mocktail.dart';

import '../catalog/catalog_test_support.dart';
import 'sales_test_support.dart';

void main() {
  late MockSaleRepository sales;
  late MockSettingsRepository settings;
  late MockProductRepository products;

  setUpAll(() {
    registerFallbackValue(FakeSaleDraft());
  });

  setUp(() {
    sales = MockSaleRepository();
    settings = MockSettingsRepository();
    products = MockProductRepository();
    stubSettingsWatch(settings);
  });

  List<Override> overrides() => salesOverrides(
        sales: sales,
        settings: settings,
        products: products,
      );

  void stubCatalog() {
    when(
      () => products.watchAll(
        query: null,
        categoryId: null,
        supplierId: null,
        onlyActive: true,
      ),
    ).thenAnswer(
      (_) => Stream<List<Product>>.value(<Product>[pieceProduct(id: 1)]),
    );
  }

  Future<void> addFirstProduct(WidgetTester tester) async {
    await tester.tap(find.text('Ajouter un produit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eau minérale'));
    await tester.pumpAndSettle();
  }

  testWidgets('panier vide : message affiché, ni ligne ni encaissement',
      (WidgetTester tester) async {
    await pumpPushedScreen(
      tester,
      const SaleCartScreen(),
      overrides: overrides(),
    );

    expect(find.text('Le panier est vide.'), findsOneWidget);
    expect(find.text('Ajouter un produit'), findsOneWidget);
    expect(find.byType(CartLineTile), findsNothing);
    expect(find.text('Encaisser'), findsNothing);
  });

  testWidgets('ajout via le sélecteur puis encaissement',
      (WidgetTester tester) async {
    stubCatalog();
    when(() => sales.checkout(any())).thenAnswer((_) async => sampleSale());

    await pumpPushedScreen(
      tester,
      const SaleCartScreen(),
      overrides: overrides(),
    );

    await addFirstProduct(tester);

    expect(find.byType(CartLineTile), findsOneWidget);
    expect(find.text('Eau minérale'), findsOneWidget);
    expect(find.text('Encaisser'), findsOneWidget);

    await tester.tap(find.text('Encaisser'));
    await tester.pumpAndSettle();

    verify(() => sales.checkout(any())).called(1);
    expect(find.byType(SaleCartScreen), findsNothing);
  });

  testWidgets('vider le panier demande confirmation puis le vide',
      (WidgetTester tester) async {
    stubCatalog();

    await pumpPushedScreen(
      tester,
      const SaleCartScreen(),
      overrides: overrides(),
    );

    await addFirstProduct(tester);
    expect(find.byType(CartLineTile), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_sweep_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Cette action est irréversible.'), findsOneWidget);

    await tester.tap(find.text('Vider le panier'));
    await tester.pumpAndSettle();

    expect(find.byType(CartLineTile), findsNothing);
    expect(find.text('Le panier est vide.'), findsOneWidget);
  });
}
