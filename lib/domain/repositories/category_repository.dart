import '../entities/catalog.dart';

/// Contrat d'accès aux catégories.
///
/// La suppression est refusée si la catégorie contient encore des produits
/// (voir [countProducts]) : l'appelant propose alors de déplacer les produits.
abstract interface class CategoryRepository {
  /// Toutes les catégories, triées par nom.
  Stream<List<Category>> watchAll();

  /// Liste filtrée par recherche (nom, insensible à la casse).
  Future<List<Category>> getAll({String? query});

  Future<Category?> getById(int id);

  /// Crée une catégorie et renvoie son identifiant.
  Future<int> create(Category category);

  Future<void> update(Category category);

  /// Supprime la catégorie ; échoue si elle contient des produits.
  Future<void> delete(int id);

  /// Nombre de produits rattachés à la catégorie.
  Future<int> countProducts(int categoryId);
}
