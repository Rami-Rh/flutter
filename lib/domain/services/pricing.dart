import 'package:meta/meta.dart';

import '../../core/money/money.dart';
import '../enums/enums.dart';
import '../units/units.dart';

/// Contexte de tarification d'un produit (prix exprimés **par unité de base**).
@immutable
class PricingContext {
  const PricingContext({
    required this.retailPrice,
    required this.wholesalePrice,
    required this.purchasePrice,
    required this.packaging,
  });

  /// Prix de vente au détail (par pièce / par kilo).
  final Money retailPrice;

  /// Prix de vente en gros (par pièce / par kilo).
  final Money wholesalePrice;

  /// Prix d'achat unitaire (par pièce / par kilo).
  final Money purchasePrice;

  final PackagingConfig packaging;

  /// Prix de vente applicable selon le mode de vente choisi.
  Money priceFor(SaleMode mode) => switch (mode) {
        SaleMode.retail => retailPrice,
        SaleMode.wholesale => wholesalePrice,
      };

  /// Prix d'un conditionnement (ex. prix du carton de 12 pièces).
  Money pricePerPackaging(SaleMode mode, PackagingUnit unit) =>
      UnitConverter.pricePerPackaging(priceFor(mode), unit, packaging);
}

/// Calculs de marge et de taux.
abstract final class MarginCalculator {
  /// Marge unitaire = prix de vente − prix d'achat.
  static Money unitMargin({
    required Money salePrice,
    required Money purchasePrice,
  }) =>
      salePrice - purchasePrice;

  /// Taux de **marge** (marge / prix d'achat). `null` si l'achat est nul.
  ///
  /// Exemple : achat 1,000 D, vente 1,400 D → 0,4 (40 %).
  static num? marginRate({
    required Money salePrice,
    required Money purchasePrice,
  }) {
    if (purchasePrice.isZero) return null;
    return (salePrice - purchasePrice).millimes / purchasePrice.millimes;
  }

  /// Taux de **marque** (marge / prix de vente). `null` si la vente est nulle.
  static num? markupRate({
    required Money salePrice,
    required Money purchasePrice,
  }) {
    if (salePrice.isZero) return null;
    return (salePrice - purchasePrice).millimes / salePrice.millimes;
  }
}
