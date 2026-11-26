import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';

import '../../../../domain/entities/app_settings.dart';
import '../../../../domain/entities/catalog.dart';
import '../../../catalog/presentation/catalog_helpers.dart';
import 'barcode_label_view.dart';

/// Rendu **imprimable** de la liste des codes-barres du catalogue.
///
/// Une ligne par produit (nom, code-barres en image et en clair, catégorie,
/// prix de détail). Noir sur blanc, indépendant du thème : la capture de ce
/// widget devient le PDF A4 partagé.
class BarcodePrintListView extends StatelessWidget {
  const BarcodePrintListView({
    required this.products,
    required this.settings,
    required this.title,
    required this.countLabel,
    super.key,
  });

  final List<Product> products;
  final AppSettings settings;
  final String title;
  final String countLabel;

  @override
  Widget build(BuildContext context) {
    final String? storeName = settings.storeName?.trim();
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.black, fontSize: 12, height: 1.3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              storeName == null || storeName.isEmpty
                  ? title
                  : '$storeName — $title',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(countLabel, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            for (int index = 0; index < products.length; index++)
              _BarcodePrintRow(
                product: products[index],
                settings: settings,
                index: index + 1,
              ),
          ],
        ),
      ),
    );
  }
}

/// Une ligne de la liste imprimable : index, nom, code-barres et prix.
class _BarcodePrintRow extends StatelessWidget {
  const _BarcodePrintRow({
    required this.product,
    required this.settings,
    required this.index,
  });

  final Product product;
  final AppSettings settings;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          SizedBox(width: 24, child: Text('$index.')),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  product.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(product.barcode),
                Text(
                  formatMoney(settings, product.retailPrice),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          BarcodeWidget(
            barcode: barcodeFor(product.barcode),
            data: product.barcode,
            width: 120,
            height: 40,
            drawText: false,
            color: Colors.black,
            backgroundColor: Colors.white,
            errorBuilder: (BuildContext context, String error) =>
                const SizedBox(width: 120, height: 40),
          ),
        ],
      ),
    );
  }
}
