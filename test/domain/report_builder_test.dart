import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_stock/core/money/money.dart';
import 'package:gestion_stock/core/quantity/quantity.dart';
import 'package:gestion_stock/domain/entities/report.dart';
import 'package:gestion_stock/domain/entities/sale.dart';
import 'package:gestion_stock/domain/enums/enums.dart';
import 'package:gestion_stock/domain/services/report_builder.dart';

void main() {
  final ReportPeriod day = ReportPeriod.day(DateTime(2026, 11, 26));

  Sale sale({
    required int id,
    required Money total,
    required Money cost,
    required Money profit,
    bool cancelled = false,
    DateTime? date,
  }) =>
      Sale(
        id: id,
        date: date ?? DateTime(2026, 11, 26, 10),
        mode: SaleMode.retail,
        subtotal: total,
        total: total,
        totalCost: cost,
        profit: profit,
        isCancelled: cancelled,
      );

  SaleItem item({
    required int productId,
    String? name,
    required Qty qty,
    required Money lineTotal,
    required Money lineProfit,
  }) =>
      SaleItem(
        productId: productId,
        packagingUnit: PackagingUnit.base,
        quantityBase: qty,
        quantityInPackaging: qty,
        unitPrice: Money.zero,
        unitCost: Money.zero,
        lineTotal: lineTotal,
        lineProfit: lineProfit,
        productName: name,
      );

  test('agrège les ventes encaissées et ignore les annulées', () {
    final ReportData data = buildReport(
      period: day,
      sales: <Sale>[
        sale(
          id: 1,
          total: Money.fromDecimal(10),
          cost: Money.fromDecimal(6),
          profit: Money.fromDecimal(4),
        ),
        sale(
          id: 2,
          total: Money.fromDecimal(50),
          cost: Money.fromDecimal(30),
          profit: Money.fromDecimal(20),
          cancelled: true,
        ),
      ],
      items: <SaleItem>[
        item(
          productId: 1,
          name: 'Riz',
          qty: Qty.pieces(2),
          lineTotal: Money.fromDecimal(10),
          lineProfit: Money.fromDecimal(4),
        ),
      ],
    );

    expect(data.summary.saleCount, 1);
    expect(data.summary.cancelledCount, 1);
    expect(data.summary.totalSales, Money.fromDecimal(10));
    expect(data.summary.totalProfit, Money.fromDecimal(4));
    expect(data.summary.quantitySold, Qty.pieces(2));
    expect(data.sales, hasLength(1));
    expect(data.sales.single.id, 1);
  });

  test('classe les produits par chiffre d\'affaires décroissant', () {
    final ReportData data = buildReport(
      period: day,
      sales: const <Sale>[],
      items: <SaleItem>[
        item(
          productId: 1,
          name: 'A',
          qty: Qty.pieces(1),
          lineTotal: Money.fromDecimal(5),
          lineProfit: Money.fromDecimal(1),
        ),
        item(
          productId: 2,
          name: 'B',
          qty: Qty.pieces(1),
          lineTotal: Money.fromDecimal(20),
          lineProfit: Money.fromDecimal(8),
        ),
        item(
          productId: 1,
          name: 'A',
          qty: Qty.pieces(2),
          lineTotal: Money.fromDecimal(10),
          lineProfit: Money.fromDecimal(2),
        ),
      ],
    );

    expect(data.topProducts, hasLength(2));
    expect(data.topProducts.first.productId, 2);
    expect(data.topProducts.first.revenue, Money.fromDecimal(20));
    expect(data.topProducts.last.productId, 1);
    expect(data.topProducts.last.quantity, Qty.pieces(3));
    expect(data.topProducts.last.revenue, Money.fromDecimal(15));
  });

  test('ventilation journalière : un point par jour, zéro si aucune vente', () {
    final ReportPeriod week = ReportPeriod.week(DateTime(2026, 11, 26));
    final ReportData data = buildReport(
      period: week,
      sales: <Sale>[
        sale(
          id: 1,
          date: DateTime(2026, 11, 24, 9),
          total: Money.fromDecimal(10),
          cost: Money.fromDecimal(6),
          profit: Money.fromDecimal(4),
        ),
        sale(
          id: 2,
          date: DateTime(2026, 11, 26, 9),
          total: Money.fromDecimal(5),
          cost: Money.fromDecimal(3),
          profit: Money.fromDecimal(2),
        ),
      ],
      items: const <SaleItem>[],
    );

    expect(data.daily, hasLength(7));
    final DailySales tuesday = data.daily
        .firstWhere((DailySales d) => d.date == DateTime(2026, 11, 24));
    expect(tuesday.saleCount, 1);
    expect(tuesday.revenue, Money.fromDecimal(10));

    final DailySales monday = data.daily
        .firstWhere((DailySales d) => d.date == DateTime(2026, 11, 23));
    expect(monday.saleCount, 0);
    expect(monday.revenue, Money.zero);
  });

  test('limite le nombre de produits classés', () {
    final ReportData data = buildReport(
      period: day,
      sales: const <Sale>[],
      items: <SaleItem>[
        for (int i = 1; i <= 5; i++)
          item(
            productId: i,
            name: 'P$i',
            qty: Qty.pieces(1),
            lineTotal: Money.fromMillimes(i * 1000),
            lineProfit: Money.zero,
          ),
      ],
      topProductLimit: 3,
    );

    expect(data.topProducts, hasLength(3));
  });

  test('période sans vente : rapport vide', () {
    final ReportData data = buildReport(
      period: day,
      sales: const <Sale>[],
      items: const <SaleItem>[],
    );

    expect(data.isEmpty, isTrue);
    expect(data.summary.totalSales, Money.zero);
    expect(data.topProducts, isEmpty);
  });
}
