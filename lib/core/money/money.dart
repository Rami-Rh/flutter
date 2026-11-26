import 'package:meta/meta.dart';

import '../quantity/quantity.dart';

/// Montant monétaire à **précision exacte**, stocké en sous-unités entières.
///
/// Contrainte métier : aucun calcul financier n'utilise de `double`.
/// Tous les montants sont des entiers en « millimes »
/// (1 unité monétaire = 1000 millimes), ce qui élimine toute erreur
/// d'arrondi flottant sur les prix, marges et totaux.
@immutable
class Money implements Comparable<Money> {
  /// Facteur d'échelle interne : nombre de sous-unités par unité.
  static const int scale = 1000;

  /// Montant exprimé en millimes (entier, peut être négatif).
  final int millimes;

  const Money.fromMillimes(this.millimes);

  /// Construit un montant depuis une valeur décimale (arrondi au millime).
  factory Money.fromDecimal(num amount) =>
      Money.fromMillimes((amount * scale).round());

  static const Money zero = Money.fromMillimes(0);

  /// Somme d'une collection de montants (utile pour les totaux de panier).
  static Money sum(Iterable<Money> amounts) =>
      amounts.fold(Money.zero, (a, b) => a + b);

  static Money min(Money a, Money b) => a <= b ? a : b;
  static Money max(Money a, Money b) => a >= b ? a : b;

  Money operator +(Money other) => Money.fromMillimes(millimes + other.millimes);

  Money operator -(Money other) => Money.fromMillimes(millimes - other.millimes);

  Money operator -() => Money.fromMillimes(-millimes);

  /// Multiplication par un **entier** (nombre de pièces/unités).
  Money operator *(int factor) => Money.fromMillimes(millimes * factor);

  /// Multiplication par une quantité de stock, arrondie au millime.
  ///
  /// Exemple : 2,5 kg × 3,450 D le kg.
  Money timesQuantity(Qty quantity) =>
      Money.fromMillimes((millimes * quantity.milliUnits) ~/ Qty.scale);

  /// Applique un taux (ex. `0.19` pour 19 %). Arrondi « au plus proche ».
  Money percentage(num rate) => Money.fromMillimes((millimes * rate).round());

  Money get abs => Money.fromMillimes(millimes.abs());

  bool get isZero => millimes == 0;
  bool get isNegative => millimes < 0;
  bool get isPositive => millimes > 0;

  /// Valeur décimale (affichage/graphiques uniquement, jamais pour calculer).
  num toDecimal() => millimes / scale;

  @override
  int compareTo(Money other) => millimes.compareTo(other.millimes);

  bool operator <(Money other) => millimes < other.millimes;
  bool operator <=(Money other) => millimes <= other.millimes;
  bool operator >(Money other) => millimes > other.millimes;
  bool operator >=(Money other) => millimes >= other.millimes;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Money && other.millimes == millimes);

  @override
  int get hashCode => millimes.hashCode;

  @override
  String toString() => 'Money($millimes millimes)';
}
