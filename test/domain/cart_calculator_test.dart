import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_stock/core/money/money.dart';
import 'package:gestion_stock/core/quantity/quantity.dart';
import 'package:gestion_stock/domain/enums/enums.dart';
import 'package:gestion_stock/domain/entities/cart_line.dart';
import 'package:gestion_stock/domain/units/units.dart';

CartLine _pieceLine({
  required int id,
  required String name,
  required Qty quantity,
  required PackagingUnit packagingUnit,
  required Money unitPrice,
  required Money unitCost,
  int? piecesPerCarton,
}) {
  return CartLine(
    productId: id,
    productName: name,
    barcode: '20000000000$id',
    packaging: PackagingConfig(
      baseUnit: StockBaseUnit.piece,
      piecesPerCarton: piecesPerCarton,
    ),
    packagingUnit: packagingUnit,
    quantity: quantity,
    unitPrice: unitPrice,
    unitCost: unitCost,
  );
}

void main() {
  group('CartLine — vente à la pièce (détail)', () {
    late CartLine line;

    setUp(() {
      line = _pieceLine(
        id: 1,
        name: 'Jus 1L',
        quantity: Qty.pieces(3),
        packagingUnit: PackagingUnit.base,
        unitPrice: Money.fromDecimal(2.5),
        unitCost: Money.fromDecimal(2.0),
      );
    });

    test('totaux de la ligne', () {
      expect(line.baseQuantity, Qty.pieces(3));
      expect(line.lineTotal, Money.fromDecimal(7.5));
      expect(line.lineCost, Money.fromDecimal(6.0));
      expect(line.lineProfit, Money.fromDecimal(1.5));
    });
  });

  group('CartLine — vente au carton', () {
    test('2 cartons de 12 pièces à 0,250 D la pièce', () {
      final line = _pieceLine(
        id: 2,
        name: 'Savon',
        quantity: Qty.pieces(2),
        packagingUnit: PackagingUnit.carton,
        unitPrice: Money.fromDecimal(0.25),
        unitCost: Money.fromDecimal(0.20),
        piecesPerCarton: 12,
      );

      expect(line.baseQuantity, Qty.pieces(24));
      expect(line.lineTotal, Money.fromDecimal(6.0));
      expect(line.lineCost, Money.fromDecimal(4.8));
      expect(line.lineProfit, Money.fromDecimal(1.2));
    });
  });

  group('CartLine — vente au kilo', () {
    test('2,5 kg à 3,000 D/kg', () {
      final line = CartLine(
        productId: 3,
        productName: 'Riz',
        barcode: '2000000000030',
        packaging: const PackagingConfig(baseUnit: StockBaseUnit.kilogram),
        packagingUnit: PackagingUnit.base,
        quantity: Qty.kilograms(2.5),
        unitPrice: Money.fromDecimal(3.0),
        unitCost: Money.fromDecimal(2.2),
      );

      expect(line.lineTotal, Money.fromDecimal(7.5));
      expect(line.lineCost, Money.fromDecimal(5.5));
      expect(line.lineProfit, Money.fromDecimal(2.0));
    });
  });

  group('CartCalculator — totaux du panier', () {
    test('3 produits différents : somme automatique', () {
      final lines = <CartLine>[
        _pieceLine(
          id: 1,
          name: 'A',
          quantity: Qty.pieces(1),
          packagingUnit: PackagingUnit.base,
          unitPrice: Money.fromDecimal(2.0),
          unitCost: Money.fromDecimal(1.5),
        ),
        _pieceLine(
          id: 2,
          name: 'B',
          quantity: Qty.pieces(2),
          packagingUnit: PackagingUnit.base,
          unitPrice: Money.fromDecimal(3.0),
          unitCost: Money.fromDecimal(2.0),
        ),
        _pieceLine(
          id: 3,
          name: 'C',
          quantity: Qty.pieces(5),
          packagingUnit: PackagingUnit.base,
          unitPrice: Money.fromDecimal(1.0),
          unitCost: Money.fromDecimal(0.8),
        ),
      ];

      final totals = CartCalculator.compute(lines);

      expect(totals.subtotal, Money.fromDecimal(13.0)); // 2 + 6 + 5
      expect(totals.total, Money.fromDecimal(13.0));
      expect(totals.cost, Money.fromDecimal(9.5)); // 1.5 + 4 + 4
      expect(totals.profit, Money.fromDecimal(3.5));
      expect(totals.itemCount, 3);
    });

    test('remise appliquée sur le sous-total', () {
      final lines = <CartLine>[
        _pieceLine(
          id: 1,
          name: 'A',
          quantity: Qty.pieces(10),
          packagingUnit: PackagingUnit.base,
          unitPrice: Money.fromDecimal(1.0),
          unitCost: Money.fromDecimal(0.6),
        ),
      ];

      final totals = CartCalculator.compute(lines, discount: Money.fromDecimal(2.0));

      expect(totals.subtotal, Money.fromDecimal(10.0));
      expect(totals.discount, Money.fromDecimal(2.0));
      expect(totals.total, Money.fromDecimal(8.0));
      expect(totals.cost, Money.fromDecimal(6.0));
      expect(totals.profit, Money.fromDecimal(2.0));
    });

    test('panier vide', () {
      final totals = CartCalculator.compute(const <CartLine>[]);
      expect(totals.subtotal, Money.zero);
      expect(totals.total, Money.zero);
      expect(totals.profit, Money.zero);
      expect(totals.itemCount, 0);
    });

    test('addOrMerge fusionne le même produit scanné deux fois', () {
      final first = _pieceLine(
        id: 7,
        name: 'Lait',
        quantity: Qty.pieces(1),
        packagingUnit: PackagingUnit.base,
        unitPrice: Money.fromDecimal(1.2),
        unitCost: Money.fromDecimal(1.0),
      );
      final second = _pieceLine(
        id: 7,
        name: 'Lait',
        quantity: Qty.pieces(2),
        packagingUnit: PackagingUnit.base,
        unitPrice: Money.fromDecimal(1.2),
        unitCost: Money.fromDecimal(1.0),
      );

      final merged = CartCalculator.addOrMerge(<CartLine>[first], second);
      expect(merged, hasLength(1));
      expect(merged.first.quantity, Qty.pieces(3));
      expect(merged.first.lineTotal, Money.fromDecimal(3.6));
    });

    test('addOrMerge conserve un produit différent comme nouvelle ligne', () {
      final a = _pieceLine(
        id: 1,
        name: 'A',
        quantity: Qty.pieces(1),
        packagingUnit: PackagingUnit.base,
        unitPrice: Money.fromDecimal(1.0),
        unitCost: Money.fromDecimal(0.5),
      );
      final b = _pieceLine(
        id: 2,
        name: 'B',
        quantity: Qty.pieces(1),
        packagingUnit: PackagingUnit.base,
        unitPrice: Money.fromDecimal(1.0),
        unitCost: Money.fromDecimal(0.5),
      );

      expect(CartCalculator.addOrMerge(<CartLine>[a], b), hasLength(2));
    });

    test('le même produit en carton ET à la pièce reste sur deux lignes', () {
      final perPiece = _pieceLine(
        id: 5,
        name: 'Eau',
        quantity: Qty.pieces(3),
        packagingUnit: PackagingUnit.base,
        unitPrice: Money.fromDecimal(0.6),
        unitCost: Money.fromDecimal(0.4),
        piecesPerCarton: 6,
      );
      final perCarton = _pieceLine(
        id: 5,
        name: 'Eau',
        quantity: Qty.pieces(1),
        packagingUnit: PackagingUnit.carton,
        unitPrice: Money.fromDecimal(0.6),
        unitCost: Money.fromDecimal(0.4),
        piecesPerCarton: 6,
      );

      final lines = CartCalculator.addOrMerge(<CartLine>[perPiece], perCarton);
      expect(lines, hasLength(2));
      expect(CartCalculator.compute(lines).subtotal, Money.fromDecimal(5.4));
    });
  });
}
