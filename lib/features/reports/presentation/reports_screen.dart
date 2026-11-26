import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/l10n/failure_messages.dart';
import '../../../app/providers/report_providers.dart';
import '../../../app/providers/settings_providers.dart';
import '../../../core/pdf/report_exporter.dart';
import '../../../core/quantity/quantity.dart';
import '../../../domain/entities/app_settings.dart';
import '../../../domain/entities/report.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../catalog/presentation/catalog_helpers.dart';
import '../../catalog/presentation/widgets/catalog_states.dart';

/// Rapports de ventes (jour / semaine / mois / période) et tableau de bord.
///
/// Le rapport est rendu à l'écran dans un `RepaintBoundary` : la même image sert
/// au PDF A4 multi-pages partagé (l'arabe reste mis en forme par Flutter).
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  final GlobalKey _boundaryKey = GlobalKey();
  bool _busy = false;

  /// Ouvre le sélecteur de dates puis applique la période choisie.
  Future<void> _pickCustomRange(ReportPeriod current) async {
    final DateTime lastDay = _lastDayOf(current);
    final DateTime now = DateTime.now();
    final DateTimeRange? range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: DateTimeRange(start: current.start, end: lastDay),
      helpText: AppLocalizations.of(context).reportPeriodPickRange,
    );
    if (range == null || !mounted) return;
    // Bornes inclusives dans le sélecteur → borne de fin exclue pour la période.
    final DateTime start =
        DateTime(range.start.year, range.start.month, range.start.day);
    final DateTime end =
        DateTime(range.end.year, range.end.month, range.end.day + 1);
    ref.read(reportPeriodProvider.notifier).selectCustom(start, end);
  }

  /// Rasterise le rapport et ouvre le partage de son PDF.
  Future<void> _share(ReportPeriod period) async {
    if (_busy) return;
    final AppLocalizations l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(reportExporterProvider).shareReport(
            _boundaryKey,
            fileName: reportFileName(period),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.reportShareDone)),
      );
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failureMessage(l10n, error))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _onKindChanged(ReportPeriod period, ReportPeriodKind kind) {
    if (kind == ReportPeriodKind.custom) {
      unawaited(_pickCustomRange(period));
      return;
    }
    ref.read(reportPeriodProvider.notifier).selectKind(kind);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppSettings settings =
        ref.watch(settingsProvider).valueOrNull ?? AppSettings.defaults;
    final ReportPeriod period = ref.watch(reportPeriodProvider);
    final AsyncValue<ReportData> report = ref.watch(reportDataProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.reportsTitle),
        actions: <Widget>[
          IconButton(
            tooltip: l10n.reportShareAction,
            onPressed: _busy || report.valueOrNull == null
                ? null
                : () => unawaited(_share(period)),
            icon: const Icon(Icons.ios_share),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          _PeriodSelector(
            selected: period.kind,
            onChanged: (ReportPeriodKind kind) => _onKindChanged(period, kind),
          ),
          Expanded(
            child: report.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (Object error, StackTrace stackTrace) =>
                  CatalogErrorView(message: failureMessage(l10n, error)),
              data: (ReportData data) => SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: RepaintBoundary(
                      key: _boundaryKey,
                      child: ReportContentView(
                        data: data,
                        settings: settings,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sélecteur de période (jour / semaine / mois / intervalle libre).
class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.selected, required this.onChanged});

  final ReportPeriodKind selected;
  final ValueChanged<ReportPeriodKind> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        child: SegmentedButton<ReportPeriodKind>(
          showSelectedIcon: false,
          segments: <ButtonSegment<ReportPeriodKind>>[
            for (final ReportPeriodKind kind in ReportPeriodKind.values)
              ButtonSegment<ReportPeriodKind>(
                value: kind,
                label: Text(reportPeriodKindLabel(l10n, kind)),
              ),
          ],
          selected: <ReportPeriodKind>{selected},
          onSelectionChanged: (Set<ReportPeriodKind> selection) =>
              onChanged(selection.first),
        ),
      ),
    );
  }
}

/// Rendu **imprimable** du rapport : noir sur blanc, indépendant du thème.
///
/// Les couleurs sont figées pour garantir un PDF toujours lisible, en clair
/// comme en sombre ; la mise en page suit la direction du texte (RTL en arabe).
class ReportContentView extends StatelessWidget {
  const ReportContentView({
    required this.data,
    required this.settings,
    super.key,
  });

  final ReportData data;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String locale = settings.language.code;
    final String? storeName = settings.storeName?.trim();

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.black, fontSize: 13, height: 1.3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              storeName == null || storeName.isEmpty
                  ? l10n.reportsTitle
                  : storeName,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              l10n.reportsTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 2),
            Text(
              reportRangeLabel(l10n, locale, data.period),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 16),
            _KpiGrid(
              items: <_KpiItem>[
                _KpiItem(
                  label: l10n.reportRevenueLabel,
                  value: formatMoney(settings, data.summary.totalSales),
                ),
                _KpiItem(
                  label: l10n.reportProfit,
                  value: formatMoney(settings, data.summary.totalProfit),
                ),
                _KpiItem(
                  label: l10n.reportCost,
                  value: formatMoney(settings, data.summary.totalCost),
                ),
                _KpiItem(
                  label: l10n.reportDiscount,
                  value: formatMoney(settings, data.summary.totalDiscount),
                ),
                _KpiItem(
                  label: l10n.reportSalesCount,
                  value: '${data.summary.saleCount}',
                ),
                _KpiItem(
                  label: l10n.reportAverageBasketLabel,
                  value: formatMoney(settings, data.summary.averageBasket),
                ),
                _KpiItem(
                  label: l10n.reportQuantitySoldLabel,
                  value: formatQuantityValue(locale, data.summary.quantitySold),
                ),
                if (data.summary.cancelledCount > 0)
                  _KpiItem(
                    label: l10n.reportCancelledCount(
                      data.summary.cancelledCount,
                    ),
                    value: '${data.summary.cancelledCount}',
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              l10n.reportDailyChartTitle,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 200,
              child: _DailyBarChart(daily: data.daily, settings: settings),
            ),
            const SizedBox(height: 20),
            Text(
              l10n.reportTopProductsTitle,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (data.topProducts.isEmpty)
              Text(
                l10n.reportEmptyPeriod,
                style: const TextStyle(color: Colors.black54),
              ),
            for (int i = 0; i < data.topProducts.length; i++)
              _TopProductRow(
                rank: i + 1,
                product: data.topProducts[i],
                settings: settings,
              ),
          ],
        ),
      ),
    );
  }
}

/// Tableau des indicateurs (deux colonnes adaptatives).
class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.items});

  final List<_KpiItem> items;

  @override
  Widget build(BuildContext context) {
    const double spacing = 12;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double tileWidth = (constraints.maxWidth - spacing) / 2;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: <Widget>[
            for (final _KpiItem item in items)
              SizedBox(
                width: tileWidth < 0 ? double.infinity : tileWidth,
                child: _KpiTile(item: item),
              ),
          ],
        );
      },
    );
  }
}

/// Un indicateur : libellé discret au-dessus, valeur en évidence.
class _KpiItem {
  const _KpiItem({required this.label, required this.value});

  final String label;
  final String value;
}

/// Voir [_KpiItem].
class _KpiTile extends StatelessWidget {
  const _KpiTile({required this.item});

  final _KpiItem item;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE0E0E0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              item.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
            const SizedBox(height: 4),
            Text(
              item.value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
}

/// Graphique en barres du chiffre d'affaires quotidien (fl_chart).
class _DailyBarChart extends StatelessWidget {
  const _DailyBarChart({required this.daily, required this.settings});

  final List<DailySales> daily;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    if (daily.isEmpty) return const SizedBox.shrink();

    final String locale = settings.language.code;
    final double maxRevenue = daily
        .map((DailySales day) => day.revenue.toDecimal().toDouble())
        .fold(0.0, (double a, double b) => a > b ? a : b);
    final double maxY = maxRevenue <= 0 ? 1.0 : maxRevenue * 1.2;
    final double barWidth =
        daily.length > 20 ? 4.0 : (daily.length > 10 ? 6.0 : 10.0);
    final double interval =
        (daily.length / 6).ceil().clamp(1, daily.length).toDouble();

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (BarChartGroupData group) => Colors.black87,
            getTooltipItem: (
              BarChartGroupData group,
              int groupIndex,
              BarChartRodData rod,
              int rodIndex,
            ) {
              final DailySales day = daily[group.x];
              return BarTooltipItem(
                '${DateFormat.yMd(locale).format(day.date)}\n'
                '${formatMoney(settings, day.revenue)}',
                const TextStyle(color: Colors.white, fontSize: 11),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (double value, TitleMeta meta) => Text(
                NumberFormat.compact(locale: locale).format(value),
                style: const TextStyle(fontSize: 10, color: Colors.black54),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              interval: interval,
              getTitlesWidget: (double value, TitleMeta meta) {
                final int index = value.round();
                if (index < 0 || index >= daily.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    DateFormat.Md(locale).format(daily[index].date),
                    style: const TextStyle(fontSize: 9, color: Colors.black54),
                  ),
                );
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (double value) => const FlLine(
            color: Color(0xFFE0E0E0),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: <BarChartGroupData>[
          for (int i = 0; i < daily.length; i++)
            BarChartGroupData(
              x: i,
              barRods: <BarChartRodData>[
                BarChartRodData(
                  toY: daily[i].revenue.toDecimal().toDouble(),
                  color: const Color(0xFF1E88E5),
                  width: barWidth,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(2),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Ligne du classement des meilleures ventes.
class _TopProductRow extends StatelessWidget {
  const _TopProductRow({
    required this.rank,
    required this.product,
    required this.settings,
  });

  final int rank;
  final ProductSales product;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final String locale = settings.language.code;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 24,
            child: Text(
              '$rank.',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              product.name ?? '—',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formatQuantityValue(locale, product.quantity),
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(width: 12),
          Text(
            formatMoney(settings, product.revenue),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

/// Libellé localisé d'une nature de période (sélecteur).
String reportPeriodKindLabel(AppLocalizations l10n, ReportPeriodKind kind) =>
    switch (kind) {
      ReportPeriodKind.day => l10n.reportPeriodDay,
      ReportPeriodKind.week => l10n.reportPeriodWeek,
      ReportPeriodKind.month => l10n.reportPeriodMonth,
      ReportPeriodKind.custom => l10n.reportPeriodCustom,
    };

/// Libellé de l'intervalle d'un rapport, bornes **incluses** à l'affichage.
String reportRangeLabel(
  AppLocalizations l10n,
  String locale,
  ReportPeriod period,
) {
  final DateFormat format = DateFormat.yMd(locale);
  return l10n.reportRangeSummary(
    format.format(period.start),
    format.format(_lastDayOf(period)),
  );
}

/// Nom de fichier du PDF d'un rapport (`rapport-2026-11-01-2026-11-30.pdf`).
String reportFileName(ReportPeriod period) {
  final DateTime last = _lastDayOf(period);
  String stamp(DateTime value) =>
      '${value.year}-${_two(value.month)}-${_two(value.day)}';
  return 'rapport-${stamp(period.start)}-${stamp(last)}.pdf';
}

/// Formate une quantité sans unité implicite : entiers si possible, sinon 3
/// décimales (les rapports agrègent pièces et kilos confondus).
String formatQuantityValue(String locale, Qty quantity) {
  final int digits = quantity.milliUnits % Qty.scale == 0 ? 0 : 3;
  return NumberFormat.decimalPatternDigits(
    locale: locale,
    decimalDigits: digits,
  ).format(quantity.toDecimal());
}

/// Dernier jour **couvert** par [period] (bornes incluses pour l'affichage).
DateTime _lastDayOf(ReportPeriod period) =>
    DateTime(period.end.year, period.end.month, period.end.day - 1);

String _two(int value) => value.toString().padLeft(2, '0');
