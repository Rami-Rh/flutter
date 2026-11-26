import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_stock/domain/entities/report.dart';

void main() {
  group('ReportPeriod.day', () {
    test('couvre la journée entière (borne de fin exclue)', () {
      final ReportPeriod period = ReportPeriod.day(DateTime(2026, 11, 26, 14, 35));

      expect(period.kind, ReportPeriodKind.day);
      expect(period.start, DateTime(2026, 11, 26));
      expect(period.end, DateTime(2026, 11, 27));
      expect(period.dayCount, 1);
      expect(period.days, <DateTime>[DateTime(2026, 11, 26)]);
      expect(period.contains(DateTime(2026, 11, 26, 23, 59)), isTrue);
      expect(period.contains(DateTime(2026, 11, 27)), isFalse);
    });
  });

  group('ReportPeriod.week', () {
    test('du lundi au lundi suivant (semaine ISO)', () {
      // 26/11/2026 est un jeudi.
      final ReportPeriod period = ReportPeriod.week(DateTime(2026, 11, 26));

      expect(period.kind, ReportPeriodKind.week);
      expect(period.start, DateTime(2026, 11, 23)); // lundi
      expect(period.end, DateTime(2026, 11, 30));
      expect(period.dayCount, 7);
      expect(period.days.first, DateTime(2026, 11, 23));
      expect(period.days.last, DateTime(2026, 11, 29));
    });

    test('un lundi reste le début de sa semaine', () {
      final ReportPeriod period = ReportPeriod.week(DateTime(2026, 11, 23, 9));

      expect(period.start, DateTime(2026, 11, 23));
      expect(period.end, DateTime(2026, 11, 30));
    });
  });

  group('ReportPeriod.month', () {
    test('couvre le mois civil', () {
      final ReportPeriod period = ReportPeriod.month(DateTime(2026, 2, 10));

      expect(period.start, DateTime(2026, 2));
      expect(period.end, DateTime(2026, 3));
      expect(period.dayCount, 28);
    });
  });

  group('ReportPeriod.custom', () {
    test('intervalle explicite', () {
      final ReportPeriod period =
          ReportPeriod.custom(DateTime(2026, 1, 5), DateTime(2026, 1, 8));

      expect(period.kind, ReportPeriodKind.custom);
      expect(period.dayCount, 3);
      expect(period.days.last, DateTime(2026, 1, 7));
    });

    test('bornes invalides refusées', () {
      expect(
        () => ReportPeriod.custom(DateTime(2026, 1, 5), DateTime(2026, 1, 5)),
        throwsArgumentError,
      );
    });
  });

  test('égalité sur (nature, bornes) sans égard à l\'heure', () {
    expect(
      ReportPeriod.day(DateTime(2026, 11, 26, 1)),
      ReportPeriod.day(DateTime(2026, 11, 26, 22)),
    );
  });
}
