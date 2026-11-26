import '../../core/money/money.dart';
import '../entities/catalog.dart';

/// Contrat d'accès au catalogue produits.
abstract interface class ProductRepository {
  /// Flux des produits, filtrable (recherche, catégorie, fournisseur).
  Stream<List<Product>> watchAll({
    String? query,
    int? categoryId,
    int? supplierId,
    bool onlyActive = true,
  });

  /// Liste ponctuelle des produits avec les mêmes filtres.
  Future<List<Product>> getAll({
    String? query,
    int? categoryId,
    int? supplierId,
    bool onlyActive = true,
  });

  Future<Product?> getById(int id);

  /// Recherche par code-barres (scan douchette / caméra).
  Future<Product?> getByBarcode(String barcode);

  /// Vrai si un **autre** produit utilise déjà ce code-barres.
  Future<bool> isBarcodeTaken(String barcode, {int? exceptId});

  /// Crée un produit et renvoie son identifiant.
  ///
  /// Si `product.barcode` est vide, un code EAN-13 unique est **généré
  /// automatiquement** ; sinon l'unicité est vérifiée.
  Future<int> create(Product product);

  /// Met à jour un produit existant (code-barres si modifié).
  Future<void> update(Product product);

  /// Active / désactive un produit (désactivation logique, sans suppression).
  Future<void> setActive(int id, bool isActive);

  /// Supprime définitivement le produit (refusé s'il est référencé par une
  /// vente ou un achat).
  Future<void> delete(int id);

  /// Produits en alerte : stock faible et, si [includeOutOfStock], ruptures.
  Future<List<Product>> lowStock({bool includeOutOfStock = true});

  /// Valeur du stock au prix d'achat (par défaut) ou de détail.
  Future<Money> stockValue({bool atPurchasePrice = true});

  /// Nombre total de produits actifs.
  Future<int> count({bool onlyActive = true});
}
