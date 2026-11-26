import '../../core/money/money.dart';
import '../../core/quantity/quantity.dart';
import '../entities/catalog.dart';
import '../entities/stock_movement.dart';

/// Contrat d'accès au **journal de stock** (immuable).
///
/// Le journal est la source de vérité ; le solde d'un produit en est la somme
/// signée. Les écritures passent par les repositories de ventes / achats, sauf
/// l'ajustement manuel d'inventaire exposé ici.
abstract interface class StockRepository {
  /// Flux des mouvements d'un produit, du plus récent au plus ancien.
  Stream<List<StockMovement>> watchMovementsOf(int productId);

  /// Historique des mouvements d'un produit (optionnellement limité).
  Future<List<StockMovement>> movementsOf(int productId, {int? limit});

  /// Solde courant recalculé depuis le journal.
  Future<Qty> balanceOf(int productId);

  /// Ajuste manuellement le stock à [newBalance] et journalise l'écart.
  ///
  /// Renvoie le mouvement créé (`adjustment`), dont la quantité est signée.
  Future<StockMovement> adjustTo({
    required int productId,
    required Qty newBalance,
    String? note,
  });

  /// Produits en stock faible ou en rupture (tous confondus).
  Future<List<Product>> lowStockProducts();

  /// Valeur totale du stock (au prix d'achat ou de détail).
  Future<Money> totalStockValue({bool atPurchasePrice = true});
}
