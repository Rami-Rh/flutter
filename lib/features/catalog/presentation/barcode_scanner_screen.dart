import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../l10n/generated/app_localizations.dart';

/// Écran de scan d'un code-barres (caméra) ; renvoie le code lu via
/// `Navigator.pop`.
class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  /// Empêche de renvoyer plusieurs fois le même code (la caméra détecte en
  /// continu).
  bool _handled = false;

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final String? value = capture.barcodes
        .map((Barcode barcode) => barcode.rawValue)
        .firstWhere(
          (String? raw) => raw != null && raw.trim().isNotEmpty,
          orElse: () => null,
        );
    if (value == null) return;
    _handled = true;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.scannerTitle)),
      body: Stack(
        children: <Widget>[
          MobileScanner(onDetect: _onDetect),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                l10n.scannerHint,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  shadows: <Shadow>[
                    Shadow(blurRadius: 6, color: Colors.black54),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
