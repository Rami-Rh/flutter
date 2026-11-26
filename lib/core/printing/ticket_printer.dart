import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;

import '../errors/failures.dart';
import '../pdf/pdf_share_gateway.dart';
import '../pdf/ticket_pdf.dart';
import '../pdf/widget_capture.dart';
import 'escpos_formatter.dart';
import 'printer_gateway.dart';

/// Largeur utile du rouleau, en points d'impression (203 dpi).
///
/// 58 mm ≈ 384 points, 80 mm ≈ 576 points : l'image du ticket est redimensionnée
/// à cette largeur avant tramage, sinon l'imprimante rogne les marges.
int printerWidthDots(int paperWidthMm) => paperWidthMm >= 80 ? 576 : 384;

/// Imprime un ticket (rasterisé en bitmap) et produit le PDF partageable.
///
/// L'arabe n'étant pas géré par ESC/POS, le ticket est rendu par Flutter (mise
/// en page RTL garantie) puis converti en image : la même capture sert à
/// l'impression thermique **et** au PDF.
class TicketPrinter {
  const TicketPrinter(this._gateway, this._share);

  final PrinterGateway _gateway;
  final PdfShareGateway _share;

  /// Vrai si le Bluetooth de l'appareil est actif.
  Future<bool> bluetoothEnabled() => _gateway.isBluetoothEnabled();

  /// Imprimantes appairées (Android) ou détectées à proximité (iOS).
  Future<List<PrinterDevice>> devices() => _gateway.pairedDevices();

  /// Rasterise le widget du ticket, l'encode en ESC/POS puis l'envoie à
  /// l'imprimante [address] (connexion automatique si nécessaire).
  Future<void> printTicket(
    GlobalKey boundaryKey, {
    required int paperWidthMm,
    required String address,
    double pixelRatio = 2,
  }) async {
    final WidgetCapture capture =
        await captureWidgetBoundary(boundaryKey, pixelRatio: pixelRatio);
    final img.Image? decoded = img.decodeImage(capture.png);
    if (decoded == null) {
      throw const AppFailure(
        FailureCode.printerUnavailable,
        debugMessage: 'Ticket illisible : PNG non décodable.',
      );
    }
    final img.Image bitmap = img.copyResize(
      decoded,
      width: printerWidthDots(paperWidthMm),
    );
    final List<int> bytes =
        await buildTicketEscPos(bitmap: bitmap, paperWidthMm: paperWidthMm);

    if (!await _gateway.isConnected()) {
      final bool connected = await _gateway.connect(address);
      if (!connected) {
        throw const AppFailure(
          FailureCode.printerUnavailable,
          debugMessage: 'Connexion à l\'imprimante impossible.',
        );
      }
    }
    final bool written = await _gateway.writeBytes(bytes);
    if (!written) {
      throw const AppFailure(
        FailureCode.printerUnavailable,
        debugMessage: 'Envoi du ticket à l\'imprimante refusé.',
      );
    }
  }

  /// Rasterise le widget du ticket et ouvre le partage du PDF correspondant.
  Future<void> shareTicketPdf(
    GlobalKey boundaryKey, {
    required int paperWidthMm,
    required String fileName,
    double pixelRatio = 2,
  }) async {
    final WidgetCapture capture =
        await captureWidgetBoundary(boundaryKey, pixelRatio: pixelRatio);
    final Uint8List pdf =
        await buildTicketPdf(capture, paperWidthMm: paperWidthMm);
    await _share.sharePdf(pdf, fileName: fileName);
  }
}

/// Chaîne d'impression / partage du ticket (surchargée dans les tests).
final Provider<TicketPrinter> ticketPrinterProvider = Provider<TicketPrinter>(
  (Ref ref) => TicketPrinter(
    ref.watch(printerGatewayProvider),
    ref.watch(pdfShareGatewayProvider),
  ),
  name: 'ticketPrinterProvider',
);

/// Nom de fichier du PDF d'une vente (`ticket-7.pdf`).
String ticketFileName(int? saleId) => 'ticket-${saleId ?? 0}.pdf';
