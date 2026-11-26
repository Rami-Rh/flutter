import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

import '../../core/barcode/barcode_generator.dart';
import '../../domain/entities/catalog.dart';
import '../../domain/repositories/category_repository.dart';
import '../../domain/repositories/product_repository.dart';
import '../../domain/repositories/supplier_repository.dart';
import 'repository_providers.dart';

/// État du catalogue exposé à l'interface : flux réactifs (listes) et
/// contrôleur d'écriture (création / modification / suppression).

// --- Catégories ------------------------------------------------------------

/// Toutes les catégories, mises à jour en temps réel.
final StreamProvider<List<Category>> categoriesProvider =
    StreamProvider<List<Category>>(
  (Ref ref) => ref.watch(categoryRepositoryProvider).watchAll(),
  name: 'categoriesProvider',
);

// --- Fournisseurs ----------------------------------------------------------

/// Tous les fournisseurs, mis à jour en temps réel.
final StreamProvider<List<Supplier>> suppliersProvider =
    StreamProvider<List<Supplier>>(
  (Ref ref) => ref.watch(supplierRepositoryProvider).watchAll(),
  name: 'suppliersProvider',
);

// --- Produits --------------------------------------------------------------

/// Filtres appliqués à la liste des produits (recherche, catégorie, fournisseur).
@immutable
class ProductFilters {
  const ProductFilters({this.query, this.categoryId, this.supplierId});

  final String? query;
  final int? categoryId;
  final int? supplierId;

  bool get isEmpty =>
      (query == null || query!.trim().isEmpty) &&
      categoryId == null &&
      supplierId == null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProductFilters &&
          other.query == query &&
          other.categoryId == categoryId &&
          other.supplierId == supplierId);

  @override
  int get hashCode => Object.hash(query, categoryId, supplierId);
}

/// Notifier des filtres produits, modifiable depuis la liste.
class ProductFiltersNotifier extends Notifier<ProductFilters> {
  @override
  ProductFilters build() => const ProductFilters();

  void setQuery(String? query) => state = ProductFilters(
        query: query,
        categoryId: state.categoryId,
        supplierId: state.supplierId,
      );

  void setCategory(int? categoryId) => state = ProductFilters(
        query: state.query,
        categoryId: categoryId,
        supplierId: state.supplierId,
      );

  void setSupplier(int? supplierId) => state = ProductFilters(
        query: state.query,
        categoryId: state.categoryId,
        supplierId: supplierId,
      );

  void clear() => state = const ProductFilters();
}

final NotifierProvider<ProductFiltersNotifier, ProductFilters>
    productFiltersProvider =
    NotifierProvider<ProductFiltersNotifier, ProductFilters>(
  ProductFiltersNotifier.new,
  name: 'productFiltersProvider',
);

/// Produits filtrés, mis à jour en temps réel.
final StreamProvider<List<Product>> productsProvider =
    StreamProvider<List<Product>>(
  (Ref ref) {
    final ProductFilters filters = ref.watch(productFiltersProvider);
    return ref.watch(productRepositoryProvider).watchAll(
          query: filters.query,
          categoryId: filters.categoryId,
          supplierId: filters.supplierId,
        );
  },
  name: 'productsProvider',
);

// --- Écritures -------------------------------------------------------------

/// Point d'entrée unique des écritures du catalogue.
final Provider<CatalogController> catalogControllerProvider =
    Provider<CatalogController>(
  CatalogController.new,
  name: 'catalogControllerProvider',
);

/// Regroupe les opérations d'écriture ; l'interface intercepte les erreurs
/// (`AppFailure`) et les traduit via `failureMessage`.
class CatalogController {
  CatalogController(this._ref);

  final Ref _ref;

  CategoryRepository get _categories => _ref.read(categoryRepositoryProvider);

  SupplierRepository get _suppliers => _ref.read(supplierRepositoryProvider);

  ProductRepository get _products => _ref.read(productRepositoryProvider);

  // Catégories
  Future<int> createCategory(Category category) =>
      _categories.create(category);

  Future<void> updateCategory(Category category) =>
      _categories.update(category);

  Future<void> deleteCategory(int id) => _categories.delete(id);

  // Fournisseurs
  Future<int> createSupplier(Supplier supplier) =>
      _suppliers.create(supplier);

  Future<void> updateSupplier(Supplier supplier) =>
      _suppliers.update(supplier);

  Future<void> deleteSupplier(int id) => _suppliers.delete(id);

  // Produits
  Future<int> createProduct(Product product) => _products.create(product);

  Future<void> updateProduct(Product product) => _products.update(product);

  Future<void> deleteProduct(int id) => _products.delete(id);

  Future<void> setProductActive(int id, {required bool isActive}) =>
      _products.setActive(id, isActive);

  /// Génère un EAN-13 libre de tout conflit avec les produits existants.
  ///
  /// [currentBarcode] (code du produit en cours d'édition) est exclu du test
  /// d'unicité, afin qu'une régénération reste possible.
  Future<String> generateBarcode({String? currentBarcode}) async {
    final List<Product> existing = await _products.getAll(onlyActive: false);
    final Set<String> taken =
        existing.map((Product product) => product.barcode).toSet();
    if (currentBarcode != null) {
      taken.remove(currentBarcode);
    }
    return BarcodeGenerator().generateEan13(isTaken: taken.contains);
  }
}
