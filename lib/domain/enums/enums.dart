/// Mode de vente choisi pour une transaction.
enum SaleMode {
  /// Vente au détail : utilisation du prix de détail unitaire.
  retail,

  /// Vente en gros : utilisation du prix de gros unitaire.
  wholesale,
}

/// Nature d'un mouvement de stock (journal immuable, en ajout seul).
enum StockMovementType {
  /// Stock initial saisi à la création du produit.
  initial,

  /// Entrée par réapprovisionnement / achat fournisseur.
  purchaseIn,

  /// Sortie automatique lors d'une vente validée.
  saleOut,

  /// Ré-entrée automatique lors de l'annulation d'une vente.
  saleCancellation,

  /// Ajustement manuel d'inventaire (correction).
  ///
  /// Seul type dont la quantité peut être **signée** : positive pour une
  /// augmentation, négative pour une diminution.
  adjustment,

  /// Retour client (ré-entrée).
  customerReturn,

  /// Retour au fournisseur (sortie).
  supplierReturn,

  /// Perte / casse / péremption (sortie).
  loss,
}

extension StockMovementTypeX on StockMovementType {
  /// `true` si le mouvement augmente le stock.
  bool get isInbound => switch (this) {
        StockMovementType.initial ||
        StockMovementType.purchaseIn ||
        StockMovementType.saleCancellation ||
        StockMovementType.customerReturn ||
        StockMovementType.adjustment =>
          true,
        _ => false,
      };

  /// Sens (+1 / -1) appliqué pour le calcul du solde.
  int get sign => isInbound ? 1 : -1;
}

/// Objet référencé par un mouvement de stock.
enum MovementReferenceType { none, sale, purchase, manual }

/// Statut de stock dérivé (jamais stocké : toujours recalculé).
enum StockStatus {
  inStock,
  low,
  outOfStock,
}

/// Langue de l'interface.
enum AppLanguage { ar, fr }

extension AppLanguageX on AppLanguage {
  /// Code ISO utilisé par `Locale` et les fichiers ARB.
  String get code => switch (this) {
        AppLanguage.ar => 'ar',
        AppLanguage.fr => 'fr',
      };

  bool get isRtl => this == AppLanguage.ar;

  static AppLanguage fromCode(String code) =>
      code == 'ar' ? AppLanguage.ar : AppLanguage.fr;
}

/// Mode clair / sombre / système.
enum AppThemeMode { system, light, dark }

/// Unités de base dans lesquelles le stock est **toujours** conservé.
///
/// Le stock est exprimé dans l'unité la plus petite (pièce ou kilogramme) ;
/// les cartons et sacs ne sont que des conditionnements de saisie/vente.
enum StockBaseUnit {
  piece,
  kilogram,
}

extension StockBaseUnitX on StockBaseUnit {
  bool get isPiece => this == StockBaseUnit.piece;

  /// Symbole court affiché dans l'interface (`pce`, `kg`).
  String get symbol => switch (this) {
        StockBaseUnit.piece => 'pce',
        StockBaseUnit.kilogram => 'kg',
      };
}

/// Conditionnement utilisé pour une opération (achat, vente, saisie).
enum PackagingUnit { base, carton, sack }
