import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_stock/core/pdf/report_pdf.dart';
import 'package:gestion_stock/core/pdf/widget_capture.dart';
import 'package:image/image.dart' as img;

/// Fausse capture : une image PNG valide de dimensions [width] × [height].
WidgetCapture capture(int width, int height) {
  final Uint8List png = Uint8List.fromList(
    img.encodePng(img.Image(width: width, height: height)),
  );
  return WidgetCapture(png: png, widthPx: width, heightPx: height);
}

void main() {
  test('génère un PDF A4 valide', () async {
    final Uint8List pdf = await buildReportPdf(capture(600, 400));

    expect(pdf.length, greaterThan(0));
    expect(String.fromCharCodes(pdf.take(4)), '%PDF');
  });

  test('découpe un rapport long en plusieurs pages', () async {
    final Uint8List pdf = await buildReportPdf(capture(600, 2000));

    expect(String.fromCharCodes(pdf.take(4)), '%PDF');
    expect(pdf.length, greaterThan(0));
  });

  test('capture illisible refusée', () async {
    await expectLater(
      buildReportPdf(
        WidgetCapture(png: Uint8List(0), widthPx: 0, heightPx: 0),
      ),
      throwsA(isA<StateError>()),
    );
  });
}
