import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_stock/core/money/money.dart';
import 'package:gestion_stock/domain/entities/sale.dart';
import 'package:gestion_stock/features/sales/presentation/sales_screen.dart';
import 'package:gestion_stock/features/sales/presentation/widgets/sale_tile.dart';
import 'package:mocktail/mocktail.dart';

import '../catalog/catalog_test_support.dart';
import 'sales_test_support.dart';

void main() {
  late MockSaleRepository sales;
  late MockSettingsRepository settings;

  setUp(() {
    sales = MockSaleRepository();
    settings = MockSettingsRepository();
    stubSettingsWatch(settings);
  });

  List<Override> overrides() => salesOverrides(sales: sales, settings: settings);

  testWidgets('les ventes du jour sont listées avec leur mode et total',
      (WidgetTester tester) async {
    when(() => sales.watchToday()).thenAnswer(
      (_) => Stream<List<Sale>>.value(<Sale>[
        sampleSale(id: 1, total: const Money.fromMillimes(1500)),
        sampleSale(
          id: 2,
          total: const Money.fromMillimes(2000),
          isCancelled: true,
        ),
      ]),
    );

    await pumpCatalogScreen(
      tester,
      const SalesScreen(),
      overrides: overrides(),
    );

    expect(find.byType(SaleTile), findsNWidgets(2));
    expect(find.text('Vente au détail'), findsNWidgets(2));
    expect(find.text('Annulée'), findsOneWidget);
    expect(find.text('Nouvelle vente'), findsOneWidget);
  });

  testWidgets('aucune vente : message affiché', (WidgetTester tester) async {
    when(() => sales.watchToday())
        .thenAnswer((_) => Stream<List<Sale>>.value(const <Sale>[]));

    await pumpCatalogScreen(
      tester,
      const SalesScreen(),
      overrides: overrides(),
    );

    expect(find.text('Aucune vente enregistrée aujourd\'hui.'), findsOneWidget);
  });
}
