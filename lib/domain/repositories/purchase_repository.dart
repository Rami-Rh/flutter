import '../entities/purchase.dart';

/// Contrat d'accès aux achats / réapprovisionnements.
///
/// L'enregistrement est **atomique** : achat, lignes, journal de stock et
/// cache de stock sont écrits dans une seule transaction.
abstract interface class PurchaseRepository {
  /// Enregistre un réapprovisionnement : crée l'achat, alimente le stock de
  /// chaque produit et renvoie l'achat persisté (avec ses lignes).
  ///
  /// Si [PurchaseDraft.updateProductCost] est vrai, le prix d'achat de
  /// référence du produit est mis à jour avec le prix saisi.
  Future<Purchase> register(PurchaseDraft draft);

  /// Achat complet (avec ses lignes), ou `null` si introuvable.
  Future<Purchase?> getById(int purchaseId);

  /// Historique des achats d'un fournisseur (du plus récent au plus ancien).
  Future<List<Purchase>> getBySupplier(int supplierId);

  /// Achats d'un intervalle [from] (inclus) → [to] (exclu).
  Future<List<Purchase>> getBetween(DateTime from, DateTime to);

  /// Flux des achats d'un intervalle.
  Stream<List<Purchase>> watchBetween(DateTime from, DateTime to);
}
