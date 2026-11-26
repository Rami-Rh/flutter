import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_stock/app/providers/sale_providers.dart';
import 'package:gestion_stock/core/money/money.dart';
import 'package:gestion_stock/core/quantity/quantity.dart';
import 'package:gestion_stock/domain/entities/catalog.dart';
import 'package:gestion_stock/domain/enums/enums.dart';

import 'sales_test_support.dart';

void main() {
  late ProviderContainer container;
  late CartNotifier cart;

  CartState cartState() => container.read(cartProvider);

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
    cart = container.read(cartProvider.notifier);
  });

  test('le panier démarre vide, en mode détail', () {
    expect(cartState().isEmpty, isTrue);
    expect(cartState().mode, SaleMode.retail);
    expect(cartState().totals.total, Money.zero);
  });

  test('ajouter un produit crée une ligne au prix de détail', () {
    cart.addProduct(pieceProduct(id: 1));

    expect(cartState().lines, hasLength(1));
    expect(cartState().lines.single.unitPrice, const Money.fromMillimes(500));
    expect(cartState().lines.single.quantity, Qty.pieces(1));
  });

  test('ajouter deux fois le même produit fusionne la quantité', () {
    final Product product = pieceProduct(id: 1);
    cart.addProduct(product);
    cart.addProduct(product);

    expect(cartState().lines, hasLength(1));
    expect(cartState().lines.single.quantity, Qty.pieces(2));
  });

  test('changer de mode réévalue le prix unitaire des lignes', () {
    cart.addProduct(pieceProduct(id: 1));

    cart.setMode(SaleMode.wholesale);

    expect(cartState().mode, SaleMode.wholesale);
    expect(cartState().lines.single.unitPrice, const Money.fromMillimes(400));
  });

  test('stepQuantity incrémente puis retire la ligne à zéro', () {
    cart.addProduct(pieceProduct(id: 1));

    cart.stepQuantity(0, 1);
    expect(cartState().lines.single.quantity, Qty.pieces(2));

    cart.stepQuantity(0, -1);
    expect(cartState().lines.single.quantity, Qty.pieces(1));

    cart.stepQuantity(0, -1);
    expect(cartState().lines, isEmpty);
  });

  test('updateLine avec une quantité nulle retire la ligne', () {
    cart.addProduct(pieceProduct(id: 1));

    cart.updateLine(0, quantity: Qty.zero);

    expect(cartState().lines, isEmpty);
  });

  test('setDiscount ignore une remise négative', () {
    cart.setDiscount(const Money.fromMillimes(-100));

    expect(cartState().discount, Money.zero);
  });

  test('les totaux appliquent la remise au sous-total', () {
    cart.addProduct(pieceProduct(id: 1));
    cart.setDiscount(const Money.fromMillimes(100));

    expect(cartState().totals.subtotal, const Money.fromMillimes(500));
    expect(cartState().totals.total, const Money.fromMillimes(400));
  });

  test('le brouillon reprend mode, lignes et remise', () {
    cart.addProduct(pieceProduct(id: 1));
    cart.setMode(SaleMode.wholesale);
    cart.setDiscount(const Money.fromMillimes(50));

    final draft = cartState().toDraft();

    expect(draft.mode, SaleMode.wholesale);
    expect(draft.lines, hasLength(1));
    expect(draft.discount, const Money.fromMillimes(50));
  });

  test('clear vide le panier et oublie les produits mémorisés', () {
    cart.addProduct(pieceProduct(id: 1));

    cart.clear();

    expect(cartState().isEmpty, isTrue);
    expect(cartState().discount, Money.zero);
    expect(cart.productOf(1), isNull);
  });

  test('productOf retrouve le produit mémorisé pour le contrôle de stock', () {
    cart.addProduct(pieceProduct(id: 1, quantityOnHand: Qty.pieces(7)));

    expect(cart.productOf(1)?.quantityOnHand, Qty.pieces(7));
  });
}
