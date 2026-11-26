import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_stock/core/pdf/ticket_pdf.dart';
import 'package:gestion_stock/core/pdf/widget_capture.dart';
import 'package:image/image.dart' as img;

/// Fausse capture : une petite image PNG valide (10 × 20 px).
WidgetCapture tinyCapture() {
  final Uint8List png = Uint8List.fromList(
    img.encodePng(img.Image(width: 10, height: 20)),
  );
  return WidgetCapture(png: png, widthPx: 10, heightPx: 20);
}

void main() {
  test('génère un PDF valide pour un rouleau de 58 mm', () async {
    final Uint8List pdf = await buildTicketPdf(tinyCapture(), paperWidthMm: 58);

    expect(pdf.length, greaterThan(0));
    expect(String.fromCharCodes(pdf.take(4)), '%PDF');
  });

  test('génère un PDF valide pour un rouleau de 80 mm', () async {
    final Uint8List pdf = await buildTicketPdf(tinyCapture(), paperWidthMm: 80);

    expect(pdf.length, greaterThan(0));
    expect(String.fromCharCodes(pdf.take(4)), '%PDF');
  });
}
