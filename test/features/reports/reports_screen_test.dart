import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_stock/core/money/money.dart';
import 'package:gestion_stock/core/pdf/report_exporter.dart';
import 'package:gestion_stock/domain/entities/sale.dart';
import 'package:gestion_stock/features/reports/presentation/reports_screen.dart';
import 'package:mocktail/mocktail.dart';

import '../catalog/catalog_test_support.dart';
import '../sales/sales_test_support.dart';

/// Exportateur espionné : aucun rendu PDF réel pendant les tests d'interface.
class RecordingReportExporter implements ReportExporter {
  int calls = 0;
  String? lastName;

  @override
  Future<void> shareReport(
    GlobalKey boundaryKey, {
    required String fileName,
    double pixelRatio = 3,
  }) async {
    calls++;
    lastName = fileName;
  }
}

void main() {
  late MockSaleRepository sales;
  late MockSettingsRepository settings;

  setUpAll(() => registerFallbackValue(DateTime(2026, 1, 1)));

  setUp(() {
    sales = MockSaleRepository();
    settings = MockSettingsRepository();
    stubSettingsWatch(settings);
  });

  List<Override> overrides(RecordingReportExporter exporter) => <Override>[
        ...salesOverrides(sales: sales, settings: settings),
        reportExporterProvider.overrideWithValue(exporter),
      ];

  void stubData({required List<Sale> rows, required List<SaleItem> items}) {
    when(() => sales.getBetween(any(), any())).thenAnswer((_) async => rows);
    when(() => sales.itemsBetween(any(), any())).thenAnswer((_) async => items);
  }

  testWidgets('affiche les agrégats et le classement de la période',
      (WidgetTester tester) async {
    stubData(
      rows: <Sale>[
        sampleSale(
          id: 1,
          total: const Money.fromMillimes(1500),
          totalCost: const Money.fromMillimes(900),
          profit: const Money.fromMillimes(600),
        ),
      ],
      items: <SaleItem>[sampleSaleItem()],
    );

    await pumpCatalogScreen(
      tester,
      const ReportsScreen(),
      overrides: overrides(RecordingReportExporter()),
    );

    expect(find.text('Chiffre d\'affaires'), findsOneWidget);
    expect(find.text('Meilleures ventes'), findsOneWidget);
    expect(find.text('Eau minérale'), findsOneWidget);
    expect(find.byType(BarChart), findsOneWidget);
  });

  testWidgets('période sans vente : message vide', (WidgetTester tester) async {
    stubData(rows: const <Sale>[], items: const <SaleItem>[]);

    await pumpCatalogScreen(
      tester,
      const ReportsScreen(),
      overrides: overrides(RecordingReportExporter()),
    );

    expect(find.text('Aucune vente sur cette période.'), findsOneWidget);
  });

  testWidgets('l\'action partage produit un PDF nommé',
      (WidgetTester tester) async {
    stubData(
      rows: <Sale>[sampleSale(id: 1)],
      items: <SaleItem>[sampleSaleItem()],
    );
    final RecordingReportExporter exporter = RecordingReportExporter();

    await pumpCatalogScreen(
      tester,
      const ReportsScreen(),
      overrides: overrides(exporter),
    );

    await tester.tap(find.byIcon(Icons.ios_share));
    await tester.pumpAndSettle();

    expect(exporter.calls, 1);
    expect(exporter.lastName, startsWith('rapport-'));
    expect(exporter.lastName, endsWith('.pdf'));
  });
}
