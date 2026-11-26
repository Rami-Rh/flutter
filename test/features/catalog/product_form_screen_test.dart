import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_stock/app/providers/repository_providers.dart';
import 'package:gestion_stock/app/providers/settings_providers.dart';
import 'package:gestion_stock/core/barcode/barcode_generator.dart';
import 'package:gestion_stock/core/money/money.dart';
import 'package:gestion_stock/domain/entities/app_settings.dart';
import 'package:gestion_stock/domain/entities/catalog.dart';
import 'package:gestion_stock/domain/enums/enums.dart';
import 'package:gestion_stock/features/catalog/presentation/product_form_screen.dart';
import 'package:mocktail/mocktail.dart';

import 'catalog_test_support.dart';

void main() {
  late MockCategoryRepository categories;
  late MockSupplierRepository suppliers;
  late MockProductRepository products;

  setUpAll(() => registerFallbackValue(sampleProduct));

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
        settingsProvider.overrideWith(
          (Ref ref) => Stream<AppSettings>.value(AppSettings.defaults),
        ),
      ];

  /// Agrandit la surface de test pour que tout le formulaire soit construit
  /// (la liste est paresseuse et ne bâtit pas les widgets hors écran).
  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Finder fieldWithLabel(String label) =>
      find.widgetWithText(TextFormField, label);

  testWidgets('création : le produit est enregistré avec les saisies exactes',
      (WidgetTester tester) async {
    when(() => products.create(any())).thenAnswer((_) async => 7);

    useTallSurface(tester);
    await pumpPushedScreen(
      tester,
      const ProductFormScreen.create(),
      overrides: overrides(),
    );

    await tester.enterText(fieldWithLabel('Nom'), 'Huile 1L');
    await tester.enterText(fieldWithLabel('Prix d\'achat'), '3,5');
    await tester.enterText(fieldWithLabel('Prix de détail'), '4,2');

    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    final Product created =
        verify(() => products.create(captureAny())).captured.single as Product;
    expect(created.name, 'Huile 1L');
    expect(created.purchasePrice, Money.fromMillimes(3500));
    expect(created.retailPrice, Money.fromMillimes(4200));
    expect(created.wholesalePrice, Money.fromMillimes(4200));
    expect(created.packaging.baseUnit, StockBaseUnit.piece);
    // Le formulaire est refermé après enregistrement.
    expect(find.text('Enregistrer'), findsNothing);
  });

  testWidgets('création : les champs obligatoires sont vérifiés',
      (WidgetTester tester) async {
    useTallSurface(tester);
    await pumpPushedScreen(
      tester,
      const ProductFormScreen.create(),
      overrides: overrides(),
    );

    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(find.text('Ce champ est obligatoire.'), findsNWidgets(3));
    verifyNever(() => products.create(any()));
  });

  testWidgets('le code-barres peut être généré automatiquement',
      (WidgetTester tester) async {
    when(() => products.getAll(onlyActive: false))
        .thenAnswer((_) async => const <Product>[]);

    useTallSurface(tester);
    await pumpPushedScreen(
      tester,
      const ProductFormScreen.create(),
      overrides: overrides(),
    );

    await tester.tap(find.byIcon(Icons.auto_fix_high));
    await tester.pumpAndSettle();

    final EditableText barcodeField = tester.widget<EditableText>(
      find.descendant(
        of: fieldWithLabel('Code-barres'),
        matching: find.byType(EditableText),
      ),
    );
    expect(
      BarcodeValidator.isValidEan13(barcodeField.controller.text),
      isTrue,
    );
  });
}
