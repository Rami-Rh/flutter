import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_stock/core/money/money.dart';
import 'package:gestion_stock/core/quantity/quantity.dart';
import 'package:gestion_stock/domain/enums/enums.dart';
import 'package:gestion_stock/domain/services/stock_calculator.dart';

void main() {
  group('StockCalculator — journal immuable', () {
    test('entrée (réapprovisionnement) augmente le stock', () {
      final result = StockCalculator.apply(
        Qty.pieces(10),
        StockMovementType.purchaseIn,
        Qty.pieces(5),
      );
      expect(result, Qty.pieces(15));
    });

    test('sortie (vente) diminue le stock', () {
      final result = StockCalculator.apply(
        Qty.pieces(10),
        StockMovementType.saleOut,
        Qty.pieces(3),
      );
      expect(result, Qty.pieces(7));
    });

    test('annulation de vente remet en stock', () {
      final afterSale = StockCalculator.apply(
        Qty.pieces(10),
        StockMovementType.saleOut,
        Qty.pieces(4),
      );
      final afterCancel = StockCalculator.apply(
        afterSale,
        StockMovementType.saleCancellation,
        Qty.pieces(4),
      );
      expect(afterCancel, Qty.pieces(10));
    });

    test('solde recalculé depuis l\'historique complet', () {
      final balance = StockCalculator.balance(<({StockMovementType type, Qty quantity})>[
        (type: StockMovementType.initial, quantity: Qty.pieces(100)),
        (type: StockMovementType.purchaseIn, quantity: Qty.pieces(50)),
        (type: StockMovementType.saleOut, quantity: Qty.pieces(30)),
        (type: StockMovementType.loss, quantity: Qty.pieces(2)),
        (type: StockMovementType.saleOut, quantity: Qty.pieces(8)),
      ]);
      expect(balance, Qty.pieces(110));
    });

    test('le solde peut devenir négatif (vente sans stock) et être détecté', () {
      final balance = StockCalculator.apply(
        Qty.pieces(1),
        StockMovementType.saleOut,
        Qty.pieces(3),
      );
      expect(balance, Qty.pieces(-2));
      expect(balance.isNegative, isTrue);
    });

    test('kg : journal exact avec décimales', () {
      final balance = StockCalculator.balance(<({StockMovementType type, Qty quantity})>[
        (type: StockMovementType.initial, quantity: Qty.kilograms(50)),
        (type: StockMovementType.saleOut, quantity: Qty.kilograms(2.5)),
        (type: StockMovementType.saleOut, quantity: Qty.kilograms(0.75)),
      ]);
      expect(balance, Qty.kilograms(46.75));
    });
  });

  group('StockCalculator — statut et valeur', () {
    test('statuts selon le seuil', () {
      expect(
        StockCalculator.statusOf(
          onHand: Qty.pieces(0),
          threshold: Qty.pieces(5),
        ),
        StockStatus.outOfStock,
      );
      expect(
        StockCalculator.statusOf(
          onHand: Qty.pieces(3),
          threshold: Qty.pieces(5),
        ),
        StockStatus.low,
      );
      expect(
        StockCalculator.statusOf(
          onHand: Qty.pieces(5),
          threshold: Qty.pieces(5),
        ),
        StockStatus.low,
      );
      expect(
        StockCalculator.statusOf(
          onHand: Qty.pieces(20),
          threshold: Qty.pieces(5),
        ),
        StockStatus.inStock,
      );
    });

    test('stock négatif considéré comme en rupture', () {
      expect(
        StockCalculator.statusOf(
          onHand: Qty.pieces(-1),
          threshold: Qty.pieces(5),
        ),
        StockStatus.outOfStock,
      );
    });

    test('valeur totale du stock (achat et vente)', () {
      final atPurchase = StockCalculator.totalValue(<({Qty quantity, Money pricePerBaseUnit})>[
        (quantity: Qty.pieces(10), pricePerBaseUnit: Money.fromDecimal(2.0)),
        (quantity: Qty.kilograms(2.5), pricePerBaseUnit: Money.fromDecimal(3.0)),
      ]);
      expect(atPurchase, Money.fromDecimal(27.5)); // 20 + 7.5
    });

    test('valeur nulle pour un stock vide', () {
      expect(
        StockCalculator.totalValue(const <({Qty quantity, Money pricePerBaseUnit})>[]),
        Money.zero,
      );
    });
  });
}
