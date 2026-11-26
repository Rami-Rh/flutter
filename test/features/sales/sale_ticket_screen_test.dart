import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_stock/core/printing/ticket_printer.dart';
import 'package:gestion_stock/domain/entities/app_settings.dart';
import 'package:gestion_stock/domain/entities/sale.dart';
import 'package:gestion_stock/features/sales/presentation/sale_ticket_screen.dart';
import 'package:mocktail/mocktail.dart';

import '../catalog/catalog_test_support.dart';
import 'sales_test_support.dart';
import 'ticket_test_support.dart';

void main() {
  late MockSaleRepository sales;
  late MockSettingsRepository settings;
  late MockProductRepository products;
  late FakeTicketPrinter printer;

  const AppSettings configured = AppSettings(
    storeName: 'Épicerie du coin',
    printerAddress: '00:11:22:33:44:55',
    printerName: 'TPS-300',
  );

  setUp(() {
    sales = MockSaleRepository();
    settings = MockSettingsRepository();
    products = MockProductRepository();
    printer = FakeTicketPrinter();
    stubSettingsWatch(settings, configured);
  });

  List<Override> overrides() => <Override>[
        ...salesOverrides(sales: sales, settings: settings, products: products),
        ticketPrinterProvider.overrideWithValue(printer),
      ];

  void stubDetail() {
    when(() => sales.getById(7)).thenAnswer(
      (_) async => sampleSale(
        id: 7,
        items: <SaleItem>[sampleSaleItem(productId: 1)],
      ),
    );
    when(() => products.getById(1))
        .thenAnswer((_) async => pieceProduct(id: 1));
  }

  testWidgets('affiche le magasin, la ligne, le total et les actions',
      (WidgetTester tester) async {
    stubDetail();

    await pumpPushedScreen(
      tester,
      const SaleTicketScreen(saleId: 7),
      overrides: overrides(),
    );

    expect(find.text('Ticket de vente'), findsOneWidget);
    expect(find.text('Épicerie du coin'), findsOneWidget);
    expect(find.text('Eau minérale'), findsOneWidget);
    expect(find.text('Sous-total'), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);
    expect(find.text('Imprimer'), findsOneWidget);
    expect(find.text('Partager le PDF'), findsOneWidget);
  });

  testWidgets('imprimer envoie le ticket à l\'imprimante mémorisée',
      (WidgetTester tester) async {
    stubDetail();

    await pumpPushedScreen(
      tester,
      const SaleTicketScreen(saleId: 7),
      overrides: overrides(),
    );
    await tester.tap(find.text('Imprimer'));
    await tester.pumpAndSettle();

    expect(printer.printCount, 1);
    expect(printer.lastAddress, '00:11:22:33:44:55');
    expect(printer.lastPaperWidthMm, 58);
    expect(find.text('Ticket envoyé à l\'imprimante.'), findsOneWidget);
  });

  testWidgets('partager le PDF produit un fichier nommé d\'après la vente',
      (WidgetTester tester) async {
    stubDetail();

    await pumpPushedScreen(
      tester,
      const SaleTicketScreen(saleId: 7),
      overrides: overrides(),
    );
    await tester.tap(find.text('Partager le PDF'));
    await tester.pumpAndSettle();

    expect(printer.shareCount, 1);
    expect(printer.lastFileName, 'ticket-7.pdf');
  });

  testWidgets('vente introuvable : message affiché', (WidgetTester tester) async {
    when(() => sales.getById(7)).thenAnswer((_) async => null);

    await pumpPushedScreen(
      tester,
      const SaleTicketScreen(saleId: 7),
      overrides: overrides(),
    );

    expect(find.text('Élément introuvable.'), findsOneWidget);
  });
}
