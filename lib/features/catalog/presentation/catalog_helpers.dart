import 'dart:ui' show Color;

import 'package:intl/intl.dart';

import '../../../core/money/money.dart';
import '../../../core/money/money_formatter.dart';
import '../../../core/quantity/quantity.dart';
import '../../../domain/entities/app_settings.dart';
import '../../../domain/enums/enums.dart';
import '../../../l10n/generated/app_localizations.dart';

// --- Analyse des saisies (sans `double`) ------------------------------------

/// Analyse une saisie décimale exacte et renvoie les milli-unités.
///
/// Accepte `1234`, `12,5`, `12.5`, `0,125` (au plus 3 décimales).
/// Renvoie `null` si la saisie est vide ou invalide.
int? parseMilli(String raw) {
  final String text = raw.trim().replaceAll(',', '.');
  if (text.isEmpty) return null;
  final RegExpMatch? match =
      RegExp(r'^(\d+)(?:\.(\d{1,3}))?$').firstMatch(text);
  if (match == null) return null;
  final String fraction = (match.group(2) ?? '').padRight(3, '0');
  return int.parse(match.group(1)!) * Money.scale + int.parse(fraction);
}

/// Saisie → [Money] (`null` si vide ou invalide).
Money? parseMoney(String raw) {
  final int? millimes = parseMilli(raw);
  return millimes == null ? null : Money.fromMillimes(millimes);
}

/// Saisie → `num` décimal (`null` si vide ou invalide).
num? parseDecimal(String raw) {
  final int? millimes = parseMilli(raw);
  return millimes == null ? null : millimes / Qty.scale;
}

/// Saisie → `int` (`null` si vide ou invalide).
int? parseIntValue(String raw) {
  final String text = raw.trim();
  if (text.isEmpty) return null;
  return int.tryParse(text);
}

/// Saisie → [Qty] dans l'unité de base.
///
/// En pièces, seules les valeurs entières sont acceptées ; en kilogrammes,
/// les décimales le sont aussi.
Qty? parseQuantity(String raw, StockBaseUnit unit) {
  final int? millimes = parseMilli(raw);
  if (millimes == null) return null;
  if (unit == StockBaseUnit.piece && millimes % Qty.scale != 0) return null;
  return Qty.fromMilliUnits(millimes);
}

// --- Formatage --------------------------------------------------------------

/// Formate un montant selon la devise et la langue des paramètres.
String formatMoney(AppSettings settings, Money money) => MoneyFormatter.format(
      money,
      locale: settings.language.code,
      currencySymbol: settings.currencySymbol,
      decimalDigits: settings.currencyDecimalDigits,
    );

/// Palette de couleurs proposées pour les catégories (hex `#RRGGBB`).
const List<String> categoryPalette = <String>[
  '#E53935',
  '#FB8C00',
  '#FDD835',
  '#43A047',
  '#00ACC1',
  '#1E88E5',
  '#5E35B1',
  '#8E24AA',
  '#6D4C41',
  '#546E7A',
];

/// Convertit un code couleur `#RRGGBB` en [Color] ; [fallback] si invalide.
Color colorFromHex(String? hex, Color fallback) {
  if (hex == null) return fallback;
  final String value = hex.replaceFirst('#', '').trim();
  if (value.length != 6) return fallback;
  final int? rgb = int.tryParse(value, radix: 16);
  return rgb == null ? fallback : Color(0xFF000000 | rgb);
}

/// Formate une quantité dans l'unité de base (0 décimale en pièces).
String formatQuantity(AppSettings settings, Qty quantity, StockBaseUnit unit) {
  final int digits = unit == StockBaseUnit.piece ? 0 : 3;
  return NumberFormat.decimalPatternDigits(
    locale: settings.language.code,
    decimalDigits: digits,
  ).format(quantity.toDecimal());
}

/// Libellé localisé de l'unité de base.
String baseUnitLabel(AppLocalizations l10n, StockBaseUnit unit) =>
    switch (unit) {
      StockBaseUnit.piece => l10n.unitPiece,
      StockBaseUnit.kilogram => l10n.unitKilogram,
    };

/// Libellé localisé du statut de stock.
String stockStatusLabel(AppLocalizations l10n, StockStatus status) =>
    switch (status) {
      StockStatus.inStock => l10n.stockStatusInStock,
      StockStatus.low => l10n.stockStatusLow,
      StockStatus.outOfStock => l10n.stockStatusOutOfStock,
    };
