import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'widget_capture.dart';

/// Construit un PDF A4 **multi-pages** à partir de la capture d'un rapport.
///
/// Le rapport est capturé en image (l'arabe est ainsi rendu fidèlement, sans
/// police embarquée) puis découpé verticalement en bandes de la hauteur d'une
/// page A4 : chaque bande devient une page, ce qui évite les pages
/// démesurément longues pour les périodes chargées.
Future<Uint8List> buildReportPdf(
  WidgetCapture capture, {
  PdfPageFormat pageFormat = PdfPageFormat.a4,
}) async {
  final img.Image? source = img.decodeImage(capture.png);
  if (source == null) {
    throw StateError('Rapport illisible : PNG non décodable.');
  }
  if (source.width == 0 || source.height == 0) {
    throw StateError('Rapport vide : image de dimensions nulles.');
  }

  /// Hauteur (en pixels de la capture) d'une page à la largeur du rapport.
  final double scale = source.width / pageFormat.width;
  final int pageHeightPx = math.max(1, (pageFormat.height * scale).floor());

  final pw.Document document = pw.Document();
  for (int top = 0; top < source.height; top += pageHeightPx) {
    final int height = math.min(pageHeightPx, source.height - top);
    final img.Image slice = img.copyCrop(
      source,
      x: 0,
      y: top,
      width: source.width,
      height: height,
    );
    final pw.MemoryImage pageImage = pw.MemoryImage(
      Uint8List.fromList(img.encodePng(slice)),
    );
    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          pageFormat.width,
          pageFormat.width * height / source.width,
        ),
        margin: pw.EdgeInsets.zero,
        build: (pw.Context context) => pw.Image(pageImage, fit: pw.BoxFit.fill),
      ),
    );
  }
  return document.save();
}
