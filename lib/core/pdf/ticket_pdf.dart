import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'widget_capture.dart';

/// Construit un PDF d'une seule page, à la largeur du papier ([paperWidthMm]),
/// contenant l'image du ticket.
///
/// Le ticket est incorporé en image : l'arabe est donc rendu fidèlement, sans
/// dépendre d'une police arabe embarquée, et le PDF reste shareable/printable.
Future<Uint8List> buildTicketPdf(
  WidgetCapture capture, {
  required int paperWidthMm,
}) {
  final double widthPt = paperWidthMm * PdfPageFormat.mm;
  final double heightPt = capture.widthPx == 0
      ? widthPt
      : widthPt * capture.heightPx / capture.widthPx;
  final pw.MemoryImage image = pw.MemoryImage(capture.png);

  final pw.Document document = pw.Document();
  document.addPage(
    pw.Page(
      pageFormat: PdfPageFormat(widthPt, heightPt),
      margin: pw.EdgeInsets.zero,
      build: (pw.Context context) => pw.Image(image, fit: pw.BoxFit.fill),
    ),
  );
  return document.save();
}
