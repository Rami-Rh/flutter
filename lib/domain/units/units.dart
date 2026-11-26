import 'package:meta/meta.dart';

import '../../core/errors/failures.dart';
import '../../core/money/money.dart';
import '../../core/quantity/quantity.dart';
import '../enums/enums.dart';

/// Configuration des conditionnements d'un produit.
///
/// Le stock est toujours conservé dans l'[baseUnit] (pièce ou kilogramme).
/// Un produit vendu :
///  - à la pièce peut l'être aussi **au carton** ([piecesPerCarton] requis) ;
///  - au kilo peut l'être aussi **au sac** ([kgPerSack] requis).
@immutable
class PackagingConfig {
  const PackagingConfig({
    required this.baseUnit,
    this.piecesPerCarton,
    this.kgPerSack,
  });

  factory PackagingConfig.pieces({int? piecesPerCarton}) => PackagingConfig(
        baseUnit: StockBaseUnit.piece,
        piecesPerCarton: piecesPerCarton,
      );

  factory PackagingConfig.kilograms({num? kgPerSack}) => PackagingConfig(
        baseUnit: StockBaseUnit.kilogram,
        kgPerSack: kgPerSack,
      );

  /// Reconstruit la configuration depuis les colonnes stockées en base.
  factory PackagingConfig.fromColumns({
    required StockBaseUnit baseUnit,
    int? piecesPerCarton,
    int? kgPerSackMilli,
  }) =>
      PackagingConfig(
        baseUnit: baseUnit,
        piecesPerCarton: piecesPerCarton,
        kgPerSack:
            kgPerSackMilli == null ? null : kgPerSackMilli / Qty.scale,
      );

  final StockBaseUnit baseUnit;

  /// Nombre de pièces par carton (`null` si non vendu au carton).
  final int? piecesPerCarton;

  /// Nombre de kilos par sac (`null` si non vendu au sac).
  final num? kgPerSack;

  bool get hasCarton =>
      baseUnit == StockBaseUnit.piece && (piecesPerCarton ?? 0) > 0;

  bool get hasSack => baseUnit == StockBaseUnit.kilogram && (kgPerSack ?? 0) > 0;

  /// Taille du sac en milli-unités, pour le stockage en base.
  int? get kgPerSackMilli =>
      kgPerSack == null ? null : (kgPerSack! * Qty.scale).round();

  /// Conditionnements proposables à la vente.
  List<PackagingUnit> get availableUnits => <PackagingUnit>[
        PackagingUnit.base,
        if (hasCarton) PackagingUnit.carton,
        if (hasSack) PackagingUnit.sack,
      ];

  /// Quantité contenue dans **une** unité de conditionnement, en unité de base.
  Qty quantityPerPackaging(PackagingUnit unit) => switch (unit) {
        PackagingUnit.base => Qty.fromMilliUnits(Qty.scale),
        PackagingUnit.carton => _require(
            hasCarton,
            () => Qty.pieces(piecesPerCarton!),
            'Ce produit n\'est pas conditionné en carton.',
          ),
        PackagingUnit.sack => _require(
            hasSack,
            () => Qty.kilograms(kgPerSack!),
            'Ce produit n\'est pas conditionné en sac.',
          ),
      };

  T _require<T>(bool condition, T Function() value, String message) {
    if (!condition) {
      throw AppFailure(FailureCode.validation, debugMessage: message);
    }
    return value();
  }
}

/// Décomposition d'une quantité de base en cartons/sacs + reste.
@immutable
class PackagingBreakdown {
  const PackagingBreakdown({required this.packagings, required this.remainder});

  /// Nombre de cartons ou de sacs entiers.
  final int packagings;

  /// Reste en unité de base (pièces ou kg).
  final Qty remainder;

  @override
  String toString() => '$packagings + ${remainder.toDecimal()}';
}

/// Conversions automatiques entre unité de base et conditionnements.
///
/// Toutes les opérations restent en arithmétique **entière** (milli-unités),
/// donc exactes : indispensable pour un journal de stock fiable.
abstract final class UnitConverter {
  /// Convertit une quantité exprimée dans [from] vers l'unité de base.
  static Qty toBaseUnit(
    Qty amount,
    PackagingUnit from,
    PackagingConfig config,
  ) {
    if (from == PackagingUnit.base) return amount;
    final perPackaging = config.quantityPerPackaging(from);
    return Qty.fromMilliUnits(
      (amount.milliUnits * perPackaging.milliUnits) ~/ Qty.scale,
    );
  }

  /// Convertit une quantité en unité de base vers [to].
  static Qty fromBaseUnit(
    Qty baseAmount,
    PackagingUnit to,
    PackagingConfig config,
  ) {
    if (to == PackagingUnit.base) return baseAmount;
    final perPackaging = config.quantityPerPackaging(to);
    return Qty.fromMilliUnits(
      (baseAmount.milliUnits * Qty.scale) ~/ perPackaging.milliUnits,
    );
  }

  /// Prix d'un conditionnement déduit du prix en unité de base.
  ///
  /// Exemple : 0,250 D/piece × 12 pièces par carton = 3,000 D le carton.
  static Money pricePerPackaging(
    Money pricePerBaseUnit,
    PackagingUnit unit,
    PackagingConfig config,
  ) {
    return pricePerBaseUnit.timesQuantity(config.quantityPerPackaging(unit));
  }

  /// Décompose une quantité de base en conditionnements entiers + reste,
  /// pour l'affichage à l'écran (ex. « 2 cartons + 3 pce »).
  static PackagingBreakdown breakdown(
    Qty baseAmount,
    PackagingUnit packaging,
    PackagingConfig config,
  ) {
    if (packaging == PackagingUnit.base) {
      return PackagingBreakdown(packagings: 0, remainder: baseAmount);
    }
    final perPackaging = config.quantityPerPackaging(packaging);
    final count = baseAmount.milliUnits ~/ perPackaging.milliUnits;
    final remainder =
        Qty.fromMilliUnits(baseAmount.milliUnits % perPackaging.milliUnits);
    return PackagingBreakdown(packagings: count, remainder: remainder);
  }
}
