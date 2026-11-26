import 'package:intl/intl.dart';

import '../../../domain/entities/app_settings.dart';
import '../../../domain/entities/cart_line.dart';
import '../../../domain/entities/catalog.dart';
import '../../../domain/entities/sale.dart';
import '../../../domain/enums/enums.dart';
import '../../../domain/units/units.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../catalog/presentation/catalog_helpers.dart';

/// Libellés et formatages propres au module **Ventes**.
///
/// Les fonctions d'analyse et de mise en forme génériques (montants,
/// quantités, unités) sont mutualisées dans `catalog_helpers`, déjà testé.

/// Libellé localisé du mode de vente (détail / gros).
String saleModeLabel(AppLocalizations l10n, SaleMode mode) => switch (mode) {
      SaleMode.retail => l10n.saleModeRetail,
      SaleMode.wholesale => l10n.saleModeWholesale,
    };

/// Libellé localisé d'un conditionnement (pièce/kg, carton ou sac).
String packagingUnitLabel(
  AppLocalizations l10n,
  PackagingUnit unit,
  StockBaseUnit baseUnit,
) =>
    switch (unit) {
      PackagingUnit.base => baseUnitLabel(l10n, baseUnit),
      PackagingUnit.carton => l10n.unitCarton,
      PackagingUnit.sack => l10n.unitSack,
    };

/// Formate la quantité d'une ligne **dans son conditionnement** :
/// entiers pour pièce, carton et sac ; décimales pour les kilos au poids.
String formatPackagingQuantity(AppSettings settings, CartLine line) {
  final bool withDecimals = line.packagingUnit == PackagingUnit.base &&
      line.packaging.baseUnit == StockBaseUnit.kilogram;
  return NumberFormat.decimalPatternDigits(
    locale: settings.language.code,
    decimalDigits: withDecimals ? 3 : 0,
  ).format(line.quantity.toDecimal());
}

/// Analyse une saisie de quantité pour un conditionnement donné.
///
/// En unité de base, les kilos acceptent les décimales ; les cartons et les
/// sacs sont comptés en unités entières.
Qty? parsePackagingQuantity(
  String raw,
  PackagingUnit unit,
  StockBaseUnit baseUnit,
) {
  if (unit == PackagingUnit.base) return parseQuantity(raw, baseUnit);
  final int? count = parseIntValue(raw);
  return count == null ? null : Qty.pieces(count);
}

/// Heure locale courte d'une vente (ex. `14:35`).
String formatSaleTime(String locale, DateTime date) =>
    DateFormat.Hm(locale).format(date);

/// Date locale courte d'une vente (ex. `26/11/2026`).
String formatSaleDate(String locale, DateTime date) =>
    DateFormat.yMd(locale).format(date);

/// Unité de base d'une ligne de vente, déduite du produit — ou du
/// conditionnement vendu lorsque le produit n'est plus disponible.
StockBaseUnit saleItemBaseUnit(SaleItem item, Product? product) {
  final StockBaseUnit? fromProduct = product?.packaging.baseUnit;
  if (fromProduct != null) return fromProduct;
  return item.packagingUnit == PackagingUnit.sack
      ? StockBaseUnit.kilogram
      : StockBaseUnit.piece;
}

/// Formate la quantité d'une ligne de vente dans son conditionnement vendu :
/// entiers pour pièce, carton et sac ; décimales pour les kilos au poids.
String formatSaleItemQuantity(
  AppSettings settings,
  SaleItem item,
  StockBaseUnit baseUnit,
) {
  final bool withDecimals = item.packagingUnit == PackagingUnit.base &&
      baseUnit == StockBaseUnit.kilogram;
  return NumberFormat.decimalPatternDigits(
    locale: settings.language.code,
    decimalDigits: withDecimals ? 3 : 0,
  ).format(item.quantityInPackaging.toDecimal());
}
