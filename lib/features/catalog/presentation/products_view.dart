import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/l10n/failure_messages.dart';
import '../../../app/providers/catalog_providers.dart';
import '../../../app/router/app_router.dart';
import '../../../domain/entities/catalog.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'widgets/catalog_states.dart';
import 'widgets/confirm_dialog.dart';
import 'widgets/product_tile.dart';

/// Valeur sentinelle des menus de filtre signifiant « tout ».
const int _allFilter = -1;

/// Onglet « Produits » : recherche, filtres, liste et CRUD.
class ProductsView extends ConsumerStatefulWidget {
  const ProductsView({super.key});

  @override
  ConsumerState<ProductsView> createState() => _ProductsViewState();
}

class _ProductsViewState extends ConsumerState<ProductsView> {
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ProductFilters filters = ref.watch(productFiltersProvider);
    final AsyncValue<List<Product>> products = ref.watch(productsProvider);

    final List<Category> categories =
        ref.watch(categoriesProvider).valueOrNull ?? const <Category>[];
    final List<Supplier> suppliers =
        ref.watch(suppliersProvider).valueOrNull ?? const <Supplier>[];

    final Map<int, String> categoryNames = <int, String>{
      for (final Category category in categories)
        if (category.id != null) category.id!: category.name,
    };
    final Map<int, String> supplierNames = <int, String>{
      for (final Supplier supplier in suppliers)
        if (supplier.id != null) supplier.id!: supplier.displayName,
    };

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.productNew),
        icon: const Icon(Icons.add),
        label: Text(l10n.actionAdd),
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              controller: _search,
              onChanged: (String value) =>
                  ref.read(productFiltersProvider.notifier).setQuery(value),
              decoration: InputDecoration(
                hintText: l10n.productSearchHint,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: (filters.query == null || filters.query!.isEmpty)
                    ? null
                    : IconButton(
                        tooltip: l10n.actionClose,
                        onPressed: () {
                          _search.clear();
                          ref
                              .read(productFiltersProvider.notifier)
                              .setQuery(null);
                        },
                        icon: const Icon(Icons.clear),
                      ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: categoryNames.containsKey(filters.categoryId)
                        ? filters.categoryId
                        : _allFilter,
                    isExpanded: true,
                    decoration: const InputDecoration(isDense: true),
                    items: <DropdownMenuItem<int>>[
                      DropdownMenuItem<int>(
                        value: _allFilter,
                        child: Text(l10n.productFilterCategory),
                      ),
                      for (final Category category in categories)
                        DropdownMenuItem<int>(
                          value: category.id,
                          child: Text(category.name),
                        ),
                    ],
                    onChanged: (int? value) => ref
                        .read(productFiltersProvider.notifier)
                        .setCategory(value == null || value == _allFilter
                            ? null
                            : value),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: supplierNames.containsKey(filters.supplierId)
                        ? filters.supplierId
                        : _allFilter,
                    isExpanded: true,
                    decoration: const InputDecoration(isDense: true),
                    items: <DropdownMenuItem<int>>[
                      DropdownMenuItem<int>(
                        value: _allFilter,
                        child: Text(l10n.productFilterSupplier),
                      ),
                      for (final Supplier supplier in suppliers)
                        DropdownMenuItem<int>(
                          value: supplier.id,
                          child: Text(supplier.displayName),
                        ),
                    ],
                    onChanged: (int? value) => ref
                        .read(productFiltersProvider.notifier)
                        .setSupplier(value == null || value == _allFilter
                            ? null
                            : value),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: products.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (Object error, StackTrace stackTrace) =>
                  CatalogErrorView(message: failureMessage(l10n, error)),
              data: (List<Product> items) {
                if (items.isEmpty) {
                  return CatalogEmptyView(
                    message: filters.isEmpty
                        ? l10n.catalogEmptyProducts
                        : l10n.catalogNoResults,
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 96),
                  itemCount: items.length,
                  itemBuilder: (BuildContext context, int index) {
                    final Product product = items[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ProductTile(
                        product: product,
                        categoryName: categoryNames[product.categoryId],
                        supplierName: supplierNames[product.supplierId],
                        onTap: () => context.push(
                          AppRoutes.productEditPath(product.id!),
                          extra: product,
                        ),
                        onDelete: () => _delete(context, ref, product),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Product product,
  ) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool confirmed = await confirmAction(
      context,
      title: l10n.deleteConfirmTitle,
      message: l10n.productDeleteConfirm,
      confirmLabel: l10n.actionDelete,
      cancelLabel: l10n.actionCancel,
    );
    if (!confirmed) return;

    try {
      await ref.read(catalogControllerProvider).deleteProduct(product.id!);
    } on Object catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failureMessage(l10n, error))),
      );
    }
  }
}
