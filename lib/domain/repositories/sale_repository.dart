import '../entities/sale.dart';

/// Contrat d'accès aux ventes.
///
/// Chaque écriture est **atomique** : l'enregistrement de la vente, de ses
/// lignes, le journal de stock et la mise à jour du cache de stock se font
/// dans une seule transaction.
abstract interface class SaleRepository {
  /// Encaisse un panier ([SaleDraft]) : enregistre la vente, déduit le stock
  /// de chaque produit et renvoie la vente persistée (avec ses lignes).
  Future<Sale> checkout(SaleDraft draft);

  /// Annule une vente : remet automatiquement les quantités en stock et
  /// renvoie la vente mise à jour. Échoue si la vente est déjà annulée.
  Future<Sale> cancel(int saleId);

  /// Vente complète (avec ses lignes), ou `null` si introuvable.
  Future<Sale?> getById(int saleId);

  /// Ventes d'un intervalle [from] (inclus) → [to] (exclu), du plus récent
  /// au plus ancien.
  Future<List<Sale>> getBetween(DateTime from, DateTime to);

  /// Flux des ventes d'un intervalle.
  Stream<List<Sale>> watchBetween(DateTime from, DateTime to);

  /// Ventes du jour courant (minuit → minuit).
  Stream<List<Sale>> watchToday();

  /// Agrégat (chiffre d'affaires, coût, bénéfice, quantités) sur un intervalle.
  Future<SalesSummary> summaryBetween(DateTime from, DateTime to);

  /// Lignes des ventes **encaissées** (non annulées) d'un intervalle
  /// [from] (inclus) → [to] (exclu), accompagnées du nom du produit.
  ///
  /// Sert aux rapports (classement des meilleures ventes).
  Future<List<SaleItem>> itemsBetween(DateTime from, DateTime to);
}
