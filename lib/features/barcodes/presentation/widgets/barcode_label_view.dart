import 'package:barcode/barcode.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';

import '../../../../core/barcode/barcode_generator.dart';
import '../../../../domain/entities/app_settings.dart';
import '../../../../domain/entities/catalog.dart';
import '../../../catalog/presentation/catalog_helpers.dart';

/// Rendu **imprimable** d'une étiquette produit : nom, code-barres et prix.
///
/// Les couleurs sont figées (noir sur blanc) car une imprimante thermique ne
/// restitue que le noir ; la largeur [width] correspond à celle du rouleau.
class BarcodeLabelView extends StatelessWidget {
  const BarcodeLabelView({
    required this.product,
    required this.settings,
    this.width = 300,
    super.key,
  });

  final Product product;
  final AppSettings settings;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.black, fontSize: 12, height: 1.2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              product.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: BarcodeWidget(
                barcode: barcodeFor(product.barcode),
                data: product.barcode,
                width: width - 40,
                height: 56,
                drawText: false,
                color: Colors.black,
                backgroundColor: Colors.white,
                errorBuilder: (BuildContext context, String error) => Text(
                  product.barcode,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              product.barcode,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11),
            ),
            const SizedBox(height: 2),
            Text(
              formatMoney(settings, product.retailPrice),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sélectionne le symbole adapté au contenu du code (EAN-13 sinon Code128).
Barcode barcodeFor(String code) =>
    BarcodeValidator.isValidEan13(code) ? Barcode.ean13() : Barcode.code128();
