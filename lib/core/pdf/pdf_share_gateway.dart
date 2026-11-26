import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

/// Ouverture du partage système d'un PDF (enregistrement, e-mail, impression…).
///
/// Abstrait pour que les tests n'invoquent pas le canal natif de `printing`.
abstract class PdfShareGateway {
  /// Ouvre la feuille de partage du système pour [bytes].
  Future<void> sharePdf(Uint8List bytes, {required String fileName});
}

/// Implémentation réelle, déléguée à `printing`.
class SystemPdfShareGateway implements PdfShareGateway {
  const SystemPdfShareGateway();

  @override
  Future<void> sharePdf(Uint8List bytes, {required String fileName}) async {
    await Printing.sharePdf(bytes: bytes, filename: fileName);
  }
}

/// Partage de PDF du système (surchargé dans les tests).
final Provider<PdfShareGateway> pdfShareGatewayProvider =
    Provider<PdfShareGateway>(
  (Ref ref) => const SystemPdfShareGateway(),
  name: 'pdfShareGatewayProvider',
);
