import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import 'categories_view.dart';
import 'products_view.dart';
import 'suppliers_view.dart';

/// Catalogue : trois onglets (produits, catégories, fournisseurs).
class CatalogScreen extends StatelessWidget {
  const CatalogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.catalogTitle),
          bottom: TabBar(
            tabs: <Widget>[
              Tab(text: l10n.catalogTabProducts),
              Tab(text: l10n.catalogTabCategories),
              Tab(text: l10n.catalogTabSuppliers),
            ],
          ),
        ),
        body: const TabBarView(
          children: <Widget>[
            ProductsView(),
            CategoriesView(),
            SuppliersView(),
          ],
        ),
      ),
    );
  }
}
