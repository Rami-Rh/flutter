import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/report.dart';
import '../../domain/entities/sale.dart';
import '../../domain/repositories/sale_repository.dart';
import '../../domain/services/report_builder.dart';
import 'repository_providers.dart';

/// Période sélectionnée dans l'écran Rapports (jour par défaut).
class ReportPeriodNotifier extends Notifier<ReportPeriod> {
  @override
  ReportPeriod build() => ReportPeriod.day(DateTime.now());

  /// Sélectionne le jour, la semaine ou le mois courant.
  ///
  /// [ReportPeriodKind.custom] exige un intervalle : passer par [selectCustom].
  void selectKind(ReportPeriodKind kind) {
    final DateTime now = DateTime.now();
    state = switch (kind) {
      ReportPeriodKind.day => ReportPeriod.day(now),
      ReportPeriodKind.week => ReportPeriod.week(now),
      ReportPeriodKind.month => ReportPeriod.month(now),
      ReportPeriodKind.custom => state,
    };
  }

  /// Sélectionne un intervalle libre [start] → [end] (bornes de type date).
  void selectCustom(DateTime start, DateTime end) {
    state = ReportPeriod.custom(start, end);
  }
}

/// Période courante du rapport.
final NotifierProvider<ReportPeriodNotifier, ReportPeriod>
    reportPeriodProvider =
    NotifierProvider<ReportPeriodNotifier, ReportPeriod>(
  ReportPeriodNotifier.new,
  name: 'reportPeriodProvider',
);

/// Données agrégées de la période sélectionnée (agrégats, classement, jours).
final FutureProvider<ReportData> reportDataProvider =
    FutureProvider<ReportData>(
  (Ref ref) async {
    final ReportPeriod period = ref.watch(reportPeriodProvider);
    final SaleRepository sales = ref.watch(saleRepositoryProvider);
    final List<Sale> rows = await sales.getBetween(period.start, period.end);
    final List<SaleItem> items =
        await sales.itemsBetween(period.start, period.end);
    return buildReport(period: period, sales: rows, items: items);
  },
  name: 'reportDataProvider',
);
