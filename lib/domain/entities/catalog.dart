import 'package:meta/meta.dart';

import '../../core/money/money.dart';
import '../../core/quantity/quantity.dart';
import '../enums/enums.dart';
import '../services/pricing.dart';
import '../services/stock_calculator.dart';
import '../units/units.dart';
import 'cart_line.dart';

/// Catégorie de produits.
@immutable
class Category {
  const Category({
    this.id,
    required this.name,
    this.colorHex,
    this.createdAt,
    this.updatedAt,
  });

  /// `null` tant que la catégorie n'a pas été enregistrée en base.
  final int? id;
  final String name;

  /// Couleur d'accent (hex `#RRGGBB`).
  final String? colorHex;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  Category copyWith({int? id, String? name, String? colorHex}) => Category(
        id: id ?? this.id,
        name: name ?? this.name,
        colorHex: colorHex ?? this.colorHex,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Category && other.id == id && other.name == name);

  @override
  int get hashCode => Object.hash(id, name);
}

/// Fournisseur.
@immutable
class Supplier {
  const Supplier({
    this.id,
    required this.name,
    this.companyName,
    this.phone,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  final int? id;

  /// Nom de la personne de contact.
  final String name;

  /// Raison sociale (ex. « Lilas »).
  final String? companyName;

  final String? phone;
  final String? notes;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Nom à afficher : la société si renseignée, sinon le contact.
  String get displayName =>
      (companyName == null || companyName!.trim().isEmpty) ? name : companyName!;

  Supplier copyWith({
    int? id,
    String? name,
    String? companyName,
    String? phone,
    String? notes,
  }) =>
      Supplier(
        id: id ?? this.id,
        name: name ?? this.name,
        companyName: companyName ?? this.companyName,
        phone: phone ?? this.phone,
        notes: notes ?? this.notes,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Supplier && other.id == id);

  @override
  int get hashCode => id.hashCode;
}

/// Produit.
///
/// Toutes les quantités sont en **unité de base** (pièce ou kilo) et tous les
/// prix sont **par unité de base** ; les conversions carton/sac sont déduites
/// automatiquement par [PackagingConfig].
@immutable
class Product {
  const Product({
    this.id,
    required this.name,
    required this.barcode,
    this.categoryId,
    this.supplierId,
    required this.packaging,
    this.quantityOnHand = Qty.zero,
    required this.purchasePrice,
    required this.retailPrice,
    required this.wholesalePrice,
    this.lowStockThreshold = Qty.zero,
    this.imagePath,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  /// `null` tant que le produit n'a pas été enregistré en base.
  final int? id;

  final String name;

  /// Chaîne vide = code-barres à générer automatiquement à l'enregistrement.
  final String barcode;

  final int? categoryId;
  final int? supplierId;

  final PackagingConfig packaging;

  /// Stock disponible en unité de base (cache du journal des mouvements).
  final Qty quantityOnHand;

  final Money purchasePrice;
  final Money retailPrice;
  final Money wholesalePrice;

  final Qty lowStockThreshold;

  final String? imagePath;
  final bool isActive;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Contexte de tarification (prix selon le mode de vente).
  PricingContext get pricing => PricingContext(
        retailPrice: retailPrice,
        wholesalePrice: wholesalePrice,
        purchasePrice: purchasePrice,
        packaging: packaging,
      );

  StockStatus get stockStatus => StockCalculator.statusOf(
        onHand: quantityOnHand,
        threshold: lowStockThreshold,
      );

  /// Vrai si le produit doit déclencher une alerte (faible ou rupture).
  bool get needsRestock => stockStatus != StockStatus.inStock;

  /// Marge unitaire au détail.
  Money get retailUnitMargin => MarginCalculator.unitMargin(
        salePrice: retailPrice,
        purchasePrice: purchasePrice,
      );

  Product copyWith({
    int? id,
    String? name,
    String? barcode,
    int? categoryId,
    int? supplierId,
    PackagingConfig? packaging,
    Qty? quantityOnHand,
    Money? purchasePrice,
    Money? retailPrice,
    Money? wholesalePrice,
    Qty? lowStockThreshold,
    String? imagePath,
    bool? isActive,
  }) =>
      Product(
        id: id ?? this.id,
        name: name ?? this.name,
        barcode: barcode ?? this.barcode,
        categoryId: categoryId ?? this.categoryId,
        supplierId: supplierId ?? this.supplierId,
        packaging: packaging ?? this.packaging,
        quantityOnHand: quantityOnHand ?? this.quantityOnHand,
        purchasePrice: purchasePrice ?? this.purchasePrice,
        retailPrice: retailPrice ?? this.retailPrice,
        wholesalePrice: wholesalePrice ?? this.wholesalePrice,
        lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
        imagePath: imagePath ?? this.imagePath,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  /// Construit une ligne de panier pour ce produit.
  ///
  /// Nécessite que le produit soit déjà enregistré (donc doté d'un [id]).
  CartLine toCartLine({
    required SaleMode mode,
    required PackagingUnit packagingUnit,
    required Qty quantity,
  }) =>
      CartLine(
        productId: id!,
        productName: name,
        barcode: barcode,
        packaging: packaging,
        packagingUnit: packagingUnit,
        quantity: quantity,
        unitPrice: pricing.priceFor(mode),
        unitCost: purchasePrice,
      );
}
