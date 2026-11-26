import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_stock/domain/entities/sale.dart';
import 'package:gestion_stock/features/sales/presentation/sale_detail_screen.dart';
import 'package:mocktail/mocktail.dart';

import '../catalog/catalog_test_support.dart';
import 'sales_test_support.dart';

void main() {
  late MockSaleRepository sales;
  late MockSettingsRepository settings;
  late MockProductRepository products;

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

  Sale saleWithItem({bool isCancelled = false}) => sampleSale(
        id: 7,
        isCancelled: isCancelled,
        items: <SaleItem>[sampleSaleItem(productId: 1)],
      );

  void stubDetail(Sale sale) {
    when(() => sales.getById(7)).thenAnswer((_) async => sale);
    when(() => products.getById(1))
        .thenAnswer((_) async => pieceProduct(id: 1));
  }

  testWidgets('affiche les lignes, le total et le bouton d\'annulation',
      (WidgetTester tester) async {
    stubDetail(saleWithItem());

    await pumpPushedScreen(
      tester,
      const SaleDetailScreen(saleId: 7),
      overrides: overrides(),
    );

    expect(find.text('Détail de la vente'), findsOneWidget);
    expect(find.text('Eau minérale'), findsOneWidget);
    expect(find.text('Articles : 1'), findsOneWidget);
    expect(find.text('Annuler la vente'), findsOneWidget);
  });

  testWidgets('une vente annulée affiche la pastille et masque l\'annulation',
      (WidgetTester tester) async {
    stubDetail(saleWithItem(isCancelled: true));

    await pumpPushedScreen(
      tester,
      const SaleDetailScreen(saleId: 7),
      overrides: overrides(),
    );

    expect(find.text('Annulée'), findsOneWidget);
    expect(find.text('Annuler la vente'), findsNothing);
  });

  testWidgets('vente introuvable : message affiché', (WidgetTester tester) async {
    when(() => sales.getById(7)).thenAnswer((_) async => null);

    await pumpPushedScreen(
      tester,
      const SaleDetailScreen(saleId: 7),
      overrides: overrides(),
    );

    expect(find.text('Élément introuvable.'), findsOneWidget);
  });

  testWidgets('annuler la vente demande confirmation puis appelle le dépôt',
      (WidgetTester tester) async {
    final Sale sale = saleWithItem();
    stubDetail(sale);
    when(() => sales.cancel(7))
        .thenAnswer((_) async => sale.copyWith(isCancelled: true));

    await pumpPushedScreen(
      tester,
      const SaleDetailScreen(saleId: 7),
      overrides: overrides(),
    );

    await tester.tap(find.text('Annuler la vente'));
    await tester.pumpAndSettle();

    expect(
      find.text('Annuler cette vente et remettre les articles en stock ?'),
      findsOneWidget,
    );

    await tester.tap(find.text('Confirmer'));
    await tester.pumpAndSettle();

    verify(() => sales.cancel(7)).called(1);
    expect(find.byType(SaleDetailScreen), findsNothing);
  });
}
