import 'package:meta/meta.dart';

import '../../core/money/money.dart';
import '../../core/quantity/quantity.dart';
import 'sale.dart';

/// Nature de la période couverte par un rapport.
enum ReportPeriodKind {
  /// Une journée (minuit → minuit suivant).
  day,

  /// Une semaine ISO (lundi → lundi suivant).
  week,

  /// Un mois civil.
  month,

  /// Un intervalle libre choisi par l'utilisateur.
  custom,
}

/// Intervalle temporel d'un rapport : [start] **inclus**, [end] **exclu**.
///
/// Calculé en dates **calendaires** (jamais par ajout de `Duration`) afin de
/// rester exact quel que soit le changement d'heure.
@immutable
class ReportPeriod {
  const ReportPeriod._({
    required this.kind,
    required this.start,
    required this.end,
  });

  final ReportPeriodKind kind;

  /// Borne inférieure (incluse).
  final DateTime start;

  /// Borne supérieure (exclue).
  final DateTime end;

  /// Journée contenant [date].
  factory ReportPeriod.day(DateTime date) {
    final DateTime start = _dateOnly(date);
    return ReportPeriod._(
      kind: ReportPeriodKind.day,
      start: start,
      end: _addDays(start, 1),
    );
  }

  /// Semaine ISO (du lundi au dimanche) contenant [date].
  factory ReportPeriod.week(DateTime date) {
    final DateTime day = _dateOnly(date);
    final DateTime start = _addDays(day, -(day.weekday - DateTime.monday));
    return ReportPeriod._(
      kind: ReportPeriodKind.week,
      start: start,
      end: _addDays(start, 7),
    );
  }

  /// Mois civil contenant [date].
  factory ReportPeriod.month(DateTime date) {
    final DateTime start = DateTime(date.year, date.month);
    return ReportPeriod._(
      kind: ReportPeriodKind.month,
      start: start,
      end: DateTime(date.year, date.month + 1),
    );
  }

  /// Intervalle explicite [start] (inclus) → [end] (exclu).
  factory ReportPeriod.custom(DateTime start, DateTime end) {
    if (!end.isAfter(start)) {
      throw ArgumentError('La fin de la période doit suivre son début.');
    }
    return ReportPeriod._(
      kind: ReportPeriodKind.custom,
      start: start,
      end: end,
    );
  }

  /// Jours couverts, dans l'ordre chronologique (axe d'un graphique).
  List<DateTime> get days {
    final List<DateTime> result = <DateTime>[];
    final DateTime stop = _dateOnly(end);
    DateTime cursor = _dateOnly(start);
    while (cursor.isBefore(stop)) {
      result.add(cursor);
      cursor = _addDays(cursor, 1);
    }
    return result;
  }

  /// Nombre de jours couverts.
  int get dayCount => days.length;

  /// Vrai si la période contient [date].
  bool contains(DateTime date) =>
      !date.isBefore(start) && date.isBefore(end);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReportPeriod &&
          other.kind == kind &&
          other.start == start &&
          other.end == end);

  @override
  int get hashCode => Object.hash(kind, start, end);
}

/// Ventes d'un produit agrégées sur une période (classement des meilleures
/// ventes).
@immutable
class ProductSales {
  const ProductSales({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.revenue,
    required this.profit,
  });

  final int productId;

  /// Nom du produit au moment de la vente (`null` si le produit a été supprimé).
  final String? name;

  /// Quantité vendue, en unité de base.
  final Qty quantity;

  /// Chiffre d'affaires généré.
  final Money revenue;

  /// Bénéfice généré.
  final Money profit;
}

/// Ventes agrégées d'une journée (série du tableau de bord).
@immutable
class DailySales {
  const DailySales({
    required this.date,
    required this.saleCount,
    required this.revenue,
    required this.profit,
  });

  /// Jour concerné (minuit).
  final DateTime date;

  /// Nombre de ventes encaissées ce jour.
  final int saleCount;

  final Money revenue;
  final Money profit;
}

/// Ensemble des données d'un rapport : agrégats, classement et détail.
@immutable
class ReportData {
  const ReportData({
    required this.period,
    required this.summary,
    required this.topProducts,
    required this.daily,
    required this.sales,
  });

  final ReportPeriod period;

  /// Agrégat global de la période (ventes, remises, coût, bénéfice).
  final SalesSummary summary;

  /// Produits classés par chiffre d'affaires décroissant.
  final List<ProductSales> topProducts;

  /// Un point par jour de la période (jours sans vente inclus, à zéro).
  final List<DailySales> daily;

  /// Ventes encaissées de la période, de la plus récente à la plus ancienne.
  final List<Sale> sales;

  /// Vrai si aucune vente n'a été encaissée sur la période.
  bool get isEmpty => summary.saleCount == 0;
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

/// Ajoute des jours **calendaires** à une date.
DateTime _addDays(DateTime value, int days) =>
    DateTime(value.year, value.month, value.day + days);
