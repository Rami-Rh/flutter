import '../entities/catalog.dart';

/// Contrat d'accès aux fournisseurs.
abstract interface class SupplierRepository {
  /// Tous les fournisseurs, triés par société puis contact.
  Stream<List<Supplier>> watchAll();

  /// Liste filtrée par recherche (contact, société, téléphone).
  Future<List<Supplier>> getAll({String? query});

  Future<Supplier?> getById(int id);

  /// Crée un fournisseur et renvoie son identifiant.
  Future<int> create(Supplier supplier);

  Future<void> update(Supplier supplier);

  /// Supprime le fournisseur ; les produits rattachés sont détachés
  /// (`supplier_id` passe à `NULL`).
  Future<void> delete(int id);

  /// Nombre de produits fournis par ce fournisseur.
  Future<int> countProducts(int supplierId);
}
