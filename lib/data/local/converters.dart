import 'package:drift/drift.dart';

import '../../core/money/money.dart';
import '../../core/quantity/quantity.dart';

/// Convertit un entier (millimes) en [Money] et inversement.
///
/// Toutes les colonnes monétaires sont stockées en **entiers** : aucune
/// valeur flottante ne circule dans la base (précision financière exacte).
class MoneyConverter extends TypeConverter<Money, int> {
  const MoneyConverter();

  @override
  Money fromSql(int fromDb) => Money.fromMillimes(fromDb);

  @override
  int toSql(Money value) => value.millimes;
}

/// Convertit un entier (milli-unités) en [Qty] et inversement.
///
/// Exemple : 2,5 kg est stocké `2500`.
class QtyConverter extends TypeConverter<Qty, int> {
  const QtyConverter();

  @override
  Qty fromSql(int fromDb) => Qty.fromMilliUnits(fromDb);

  @override
  int toSql(Qty value) => value.milliUnits;
}
