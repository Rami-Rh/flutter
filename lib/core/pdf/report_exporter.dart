import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'pdf_share_gateway.dart';
import 'report_pdf.dart';
import 'widget_capture.dart';

/// Rasterise un rapport affiché par Flutter puis ouvre le partage de son PDF.
///
/// Le rendu passe par Flutter (arabe mis en forme, RTL garanti) : la même
/// capture sert de source unique au PDF A4 multi-pages.
class ReportExporter {
  const ReportExporter(this._share);

  final PdfShareGateway _share;

  /// Capture le rapport référencé par [boundaryKey] et partage le PDF obtenu.
  Future<void> shareReport(
    GlobalKey boundaryKey, {
    required String fileName,
    double pixelRatio = 3,
  }) async {
    final WidgetCapture capture =
        await captureWidgetBoundary(boundaryKey, pixelRatio: pixelRatio);
    final Uint8List pdf = await buildReportPdf(capture);
    await _share.sharePdf(pdf, fileName: fileName);
  }
}

/// Export PDF des rapports (surchargé dans les tests).
final Provider<ReportExporter> reportExporterProvider =
    Provider<ReportExporter>(
  (Ref ref) => ReportExporter(ref.watch(pdfShareGatewayProvider)),
  name: 'reportExporterProvider',
);
