import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_stock/app/providers/repository_providers.dart';
import 'package:gestion_stock/domain/entities/catalog.dart';
import 'package:gestion_stock/features/catalog/presentation/catalog_screen.dart';
import 'package:gestion_stock/features/catalog/presentation/categories_view.dart';
import 'package:gestion_stock/features/catalog/presentation/category_form_sheet.dart';
import 'package:gestion_stock/features/catalog/presentation/suppliers_view.dart';
import 'package:gestion_stock/features/catalog/presentation/widgets/confirm_dialog.dart';
import 'package:mocktail/mocktail.dart';

import 'catalog_test_support.dart';

void main() {
  late MockCategoryRepository categories;
  late MockSupplierRepository suppliers;
  late MockProductRepository products;

  setUp(() {
    categories = MockCategoryRepository();
    suppliers = MockSupplierRepository();
    products = MockProductRepository();
    when(() => categories.watchAll())
        .thenAnswer((_) => Stream<List<Category>>.value(const <Category>[]));
    when(() => suppliers.watchAll())
        .thenAnswer((_) => Stream<List<Supplier>>.value(const <Supplier>[]));
  });

  List<Override> overrides() => <Override>[
        categoryRepositoryProvider.overrideWithValue(categories),
        supplierRepositoryProvider.overrideWithValue(suppliers),
        productRepositoryProvider.overrideWithValue(products),
      ];

  testWidgets('catégories : la liste reçue est affichée',
      (WidgetTester tester) async {
    when(() => categories.watchAll()).thenAnswer(
      (_) => Stream<List<Category>>.value(
        const <Category>[Category(id: 1, name: 'Boissons')],
      ),
    );

    await pumpCatalogScreen(
      tester,
      const CategoriesView(),
      overrides: overrides(),
    );

    expect(find.text('Boissons'), findsOneWidget);
  });

  testWidgets('catégories : message affiché quand la liste est vide',
      (WidgetTester tester) async {
    await pumpCatalogScreen(
      tester,
      const CategoriesView(),
      overrides: overrides(),
    );

    expect(find.text('Aucune catégorie pour l\'instant.'), findsOneWidget);
  });

  testWidgets('catégories : le bouton d\'ajout ouvre le formulaire',
      (WidgetTester tester) async {
    await pumpCatalogScreen(
      tester,
      const CategoriesView(),
      overrides: overrides(),
    );

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.byType(CategoryFormSheet), findsOneWidget);
    expect(find.text('Nouvelle catégorie'), findsOneWidget);
  });

  testWidgets('fournisseurs : nom d\'affichage et appel direct',
      (WidgetTester tester) async {
    when(() => suppliers.watchAll()).thenAnswer(
      (_) => Stream<List<Supplier>>.value(
        const <Supplier>[
          Supplier(
            id: 1,
            name: 'Karim',
            companyName: 'Laitier',
            phone: '71234567',
          ),
        ],
      ),
    );

    await pumpCatalogScreen(
      tester,
      const SuppliersView(),
      overrides: overrides(),
    );

    expect(find.text('Laitier'), findsOneWidget);
    expect(find.byIcon(Icons.phone_outlined), findsOneWidget);
  });

  testWidgets('catalogue : les trois onglets sont disponibles',
      (WidgetTester tester) async {
    when(
      () => products.watchAll(
        query: null,
        categoryId: null,
        supplierId: null,
        onlyActive: true,
      ),
    ).thenAnswer((_) => Stream<List<Product>>.value(const <Product>[]));

    await pumpCatalogScreen(
      tester,
      const CatalogScreen(),
      overrides: overrides(),
    );

    expect(find.text('Produits'), findsOneWidget);
    expect(find.text('Catégories'), findsOneWidget);
    expect(find.text('Fournisseurs'), findsOneWidget);
    expect(find.text('Aucun produit pour l\'instant.'), findsOneWidget);

    await tester.tap(find.text('Catégories'));
    await tester.pumpAndSettle();

    expect(find.text('Aucune catégorie pour l\'instant.'), findsOneWidget);
  });

  testWidgets('confirmAction ne renvoie vrai qu\'après confirmation',
      (WidgetTester tester) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) => TextButton(
              onPressed: () async {
                result = await confirmAction(
                  context,
                  title: 'Confirmation',
                  message: 'Supprimer ?',
                  confirmLabel: 'Supprimer',
                  cancelLabel: 'Annuler',
                );
              },
              child: const Text('ouvrir'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(result, isFalse);

    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });
}
