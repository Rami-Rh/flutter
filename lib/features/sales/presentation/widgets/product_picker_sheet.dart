import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/l10n/failure_messages.dart';
import '../../../../app/providers/sale_providers.dart';
import '../../../../app/providers/settings_providers.dart';
import '../../../../domain/entities/app_settings.dart';
import '../../../../domain/entities/catalog.dart';
import '../../../../domain/enums/enums.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../catalog/presentation/catalog_helpers.dart';
import '../../../catalog/presentation/widgets/catalog_states.dart';

/// Ouvre le sélecteur de produits : recherche puis ajout au panier.
Future<void> showProductPickerSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (BuildContext context) => const _ProductPickerSheet(),
  );
}

class _ProductPickerSheet extends ConsumerStatefulWidget {
  const _ProductPickerSheet();

  @override
  ConsumerState<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends ConsumerState<_ProductPickerSheet> {
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _add(Product product) {
    ref.read(cartProvider.notifier).addProduct(product);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppSettings settings =
        ref.watch(settingsProvider).valueOrNull ?? AppSettings.defaults;
    final AsyncValue<List<Product>> products =
        ref.watch(saleProductsProvider(_search.text));

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _search,
                autofocus: true,
                onChanged: (String value) => setState(() {}),
                decoration: InputDecoration(
                  hintText: l10n.saleSearchHint,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: l10n.actionClose,
                          onPressed: () {
                            _search.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.clear),
                        ),
                ),
              ),
            ),
            Expanded(
              child: products.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (Object error, StackTrace stackTrace) =>
                    CatalogErrorView(message: failureMessage(l10n, error)),
                data: (List<Product> items) {
                  if (items.isEmpty) {
                    return CatalogEmptyView(message: l10n.saleNoProductFound);
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    itemCount: items.length,
                    itemBuilder: (BuildContext context, int index) {
                      final Product product = items[index];
                      return ListTile(
                        title: Text(product.name),
                        subtitle: Text(
                          '${formatMoney(settings, product.retailPrice)} • '
                          '${product.barcode} • '
                          '${formatQuantity(settings, product.quantityOnHand, product.packaging.baseUnit)}'
                          ' ${baseUnitLabel(l10n, product.packaging.baseUnit)}',
                        ),
                        trailing: const Icon(Icons.add_circle_outline),
                        onTap: () => _add(product),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
