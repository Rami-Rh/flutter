import '../../core/money/money.dart';
import '../../core/quantity/quantity.dart';
import '../entities/report.dart';
import '../entities/sale.dart';

/// Agrège des ventes et leurs lignes en [ReportData] (rapports, tableau de
/// bord).
///
/// Fonction **pure** : aucun accès base ni horloge, donc directement testable.
/// [items] doit contenir les lignes des ventes **encaissées** (non annulées)
/// de la période ; les ventes annulées présentes dans [sales] sont ignorées des
/// agrégats mais restent comptées dans `summary.cancelledCount`.
ReportData buildReport({
  required ReportPeriod period,
  required List<Sale> sales,
  required List<SaleItem> items,
  int topProductLimit = 10,
}) {
  final List<Sale> active =
      sales.where((Sale sale) => !sale.isCancelled).toList(growable: false);

  final SalesSummary summary = SalesSummary(
    saleCount: active.length,
    cancelledCount: sales.length - active.length,
    totalSales: Money.sum(active.map((Sale sale) => sale.total)),
    totalDiscount: Money.sum(active.map((Sale sale) => sale.discount)),
    totalCost: Money.sum(active.map((Sale sale) => sale.totalCost)),
    totalProfit: Money.sum(active.map((Sale sale) => sale.profit)),
    quantitySold: Qty.fromMilliUnits(
      items.fold(
        0,
        (int sum, SaleItem item) => sum + item.quantityBase.milliUnits,
      ),
    ),
  );

  return ReportData(
    period: period,
    summary: summary,
    topProducts: _rankProducts(items, topProductLimit),
    daily: _dailyBreakdown(period, active),
    sales: active,
  );
}

/// Classe les produits par chiffre d'affaires décroissant (au plus [limit]).
List<ProductSales> _rankProducts(List<SaleItem> items, int limit) {
  final Map<int, _ProductTotal> totals = <int, _ProductTotal>{};
  for (final SaleItem item in items) {
    totals
        .putIfAbsent(
          item.productId,
          () => _ProductTotal(item.productId, item.productName),
        )
        .add(item);
  }
  final List<ProductSales> ranked = totals.values
      .map((_ProductTotal total) => total.toProductSales())
      .toList()
    ..sort(
      (ProductSales a, ProductSales b) => b.revenue.compareTo(a.revenue),
    );
  return limit >= ranked.length
      ? List<ProductSales>.unmodifiable(ranked)
      : List<ProductSales>.unmodifiable(ranked.take(limit));
}

/// Un point par jour de la période (jours sans vente inclus).
List<DailySales> _dailyBreakdown(ReportPeriod period, List<Sale> active) {
  final Map<DateTime, _DailyTotal> totals = <DateTime, _DailyTotal>{};
  for (final Sale sale in active) {
    final DateTime day =
        DateTime(sale.date.year, sale.date.month, sale.date.day);
    totals.putIfAbsent(day, _DailyTotal.new).add(sale);
  }
  return <DailySales>[
    for (final DateTime day in period.days)
      (totals[day] ?? _DailyTotal()).toDailySales(day),
  ];
}

/// Cumul des ventes d'un produit.
class _ProductTotal {
  _ProductTotal(this.productId, this.name);

  final int productId;
  String? name;
  int milliUnits = 0;
  int revenue = 0;
  int profit = 0;

  void add(SaleItem item) {
    name ??= item.productName;
    milliUnits += item.quantityBase.milliUnits;
    revenue += item.lineTotal.millimes;
    profit += item.lineProfit.millimes;
  }

  ProductSales toProductSales() => ProductSales(
        productId: productId,
        name: name,
        quantity: Qty.fromMilliUnits(milliUnits),
        revenue: Money.fromMillimes(revenue),
        profit: Money.fromMillimes(profit),
      );
}

/// Cumul des ventes d'une journée.
class _DailyTotal {
  int saleCount = 0;
  int revenue = 0;
  int profit = 0;

  void add(Sale sale) {
    saleCount++;
    revenue += sale.total.millimes;
    profit += sale.profit.millimes;
  }

  DailySales toDailySales(DateTime day) => DailySales(
        date: day,
        saleCount: saleCount,
        revenue: Money.fromMillimes(revenue),
        profit: Money.fromMillimes(profit),
      );
}
