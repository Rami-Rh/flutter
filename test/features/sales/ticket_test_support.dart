import 'package:flutter/widgets.dart';
import 'package:gestion_stock/core/printing/printer_gateway.dart';
import 'package:gestion_stock/core/printing/ticket_printer.dart';

/// Double de [TicketPrinter] : enregistre les impressions/partages demandés
/// sans toucher au Bluetooth ni au système de fichiers.
class FakeTicketPrinter implements TicketPrinter {
  int printCount = 0;
  int shareCount = 0;

  int? lastPaperWidthMm;
  String? lastAddress;
  String? lastFileName;

  @override
  Future<bool> bluetoothEnabled() async => true;

  @override
  Future<List<PrinterDevice>> devices() async => const <PrinterDevice>[];

  @override
  Future<void> printTicket(
    GlobalKey boundaryKey, {
    required int paperWidthMm,
    required String address,
    double pixelRatio = 2,
  }) async {
    printCount++;
    lastPaperWidthMm = paperWidthMm;
    lastAddress = address;
  }

  @override
  Future<void> shareTicketPdf(
    GlobalKey boundaryKey, {
    required int paperWidthMm,
    required String fileName,
    double pixelRatio = 2,
  }) async {
    shareCount++;
    lastPaperWidthMm = paperWidthMm;
    lastFileName = fileName;
  }
}
