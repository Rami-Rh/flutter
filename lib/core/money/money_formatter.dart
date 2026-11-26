import 'package:intl/intl.dart';

import 'money.dart';

/// Formatage localisé des montants (aucune logique métier ici).
///
/// La précision interne reste entière ([Money.millimes]) ; le nombre de
/// décimales affiché est fourni par les paramètres de l'application.
abstract final class MoneyFormatter {
  /// Formate un montant selon la locale (ex. `fr` / `ar`).
  static String format(
    Money money, {
    required String locale,
    required String currencySymbol,
    int decimalDigits = 3,
  }) {
    final formatter = NumberFormat.currency(
      locale: locale,
      symbol: currencySymbol,
      decimalDigits: decimalDigits,
    );
    return formatter.format(money.toDecimal());
  }

  /// Formate sans symbole (ex. pour colonnes de tableau).
  static String formatPlain(
    Money money, {
    required String locale,
    int decimalDigits = 3,
  }) {
    final formatter = NumberFormat.decimalPatternDigits(
      locale: locale,
      decimalDigits: decimalDigits,
    );
    return formatter.format(money.toDecimal());
  }
}
