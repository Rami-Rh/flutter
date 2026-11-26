import 'package:meta/meta.dart';

/// Quantité de stock à **précision exacte** (milli-unités entières).
///
/// La quantité est exprimée dans l'**unité de base** du produit
/// (pièce ou gramme/kilogramme) ; les conversions carton/sac sont gérées par
/// `UnitConverter` (voir `lib/domain/units/units.dart`).
///
/// Aucune quantité n'utilise de `double` en interne : `2,5 kg` devient
/// `2500` milli-unités, ce qui garantit une arithmétique exacte et
/// un journal de stock (ledger) immuable et vérifiable.
@immutable
class Qty implements Comparable<Qty> {
  /// Nombre de milli-unités par unité de base.
  static const int scale = 1000;

  /// Nombre de milli-unités (1 unité = 1000 milli-unités).
  final int milliUnits;

  const Qty.fromMilliUnits(this.milliUnits);

  factory Qty.fromUnits(num units) =>
      Qty.fromMilliUnits((units * scale).round());

  /// Quantité en pièces entières.
  factory Qty.pieces(int count) => Qty.fromMilliUnits(count * scale);

  /// Quantité en kilogrammes (accepte les décimales, ex. 0,5 kg).
  factory Qty.kilograms(num kg) => Qty.fromUnits(kg);

  static const Qty zero = Qty.fromMilliUnits(0);

  Qty operator +(Qty other) => Qty.fromMilliUnits(milliUnits + other.milliUnits);
  Qty operator -(Qty other) => Qty.fromMilliUnits(milliUnits - other.milliUnits);
  Qty operator -() => Qty.fromMilliUnits(-milliUnits);
  Qty operator *(int factor) => Qty.fromMilliUnits(milliUnits * factor);

  bool get isZero => milliUnits == 0;
  bool get isNegative => milliUnits < 0;
  bool get isPositive => milliUnits > 0;

  num toDecimal() => milliUnits / scale;

  /// Renvoie le nombre de pièces entières, ou `null` si la quantité
  /// n'est pas un multiple de 1000 (ex. 0,5 kg).
  int? asWholeUnits() => milliUnits % scale == 0 ? milliUnits ~/ scale : null;

  @override
  int compareTo(Qty other) => milliUnits.compareTo(other.milliUnits);

  bool operator <(Qty other) => milliUnits < other.milliUnits;
  bool operator <=(Qty other) => milliUnits <= other.milliUnits;
  bool operator >(Qty other) => milliUnits > other.milliUnits;
  bool operator >=(Qty other) => milliUnits >= other.milliUnits;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Qty && other.milliUnits == milliUnits);

  @override
  int get hashCode => milliUnits.hashCode;

  @override
  String toString() => 'Qty($milliUnits milliUnits)';
}
