import '../../core/money/money.dart';
import '../../core/quantity/quantity.dart';
import '../enums/enums.dart';

/// Calculs de stock basés sur le **journal immuable des mouvements**.
///
/// Le journal (`stock_movements`) est la source de vérité : chaque ligne est
/// ajoutée seule (jamais modifiée) et le solde est la somme signée des
/// mouvements. Le champ `quantityOnHand` de la table `products` n'est qu'un
/// **cache** de ce solde, recalculable à tout moment pour audit.
abstract final class StockCalculator {
  /// Solde après application d'un mouvement.
  static Qty apply(Qty balance, StockMovementType type, Qty magnitude) {
    final signed = type.isInbound ? magnitude : -magnitude;
    return balance + signed;
  }

  /// Solde recalculé à partir de l'historique des mouvements.
  static Qty balance(
    Iterable<({StockMovementType type, Qty quantity})> movements,
  ) {
    return movements.fold(
      Qty.zero,
      (running, m) => apply(running, m.type, m.quantity),
    );
  }

  /// Statut d'alerte dérivé du seuil paramétré sur le produit.
  static StockStatus statusOf({required Qty onHand, required Qty threshold}) {
    if (onHand <= Qty.zero) return StockStatus.outOfStock;
    if (onHand <= threshold) return StockStatus.low;
    return StockStatus.inStock;
  }

  /// Valeur d'un ensemble de stocks à un prix donné (par unité de base).
  static Money totalValue(
    Iterable<({Qty quantity, Money pricePerBaseUnit})> entries,
  ) {
    return Money.sum(
      entries.map((e) => e.pricePerBaseUnit.timesQuantity(e.quantity)),
    );
  }
}
