import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_stock/core/printing/ticket_printer.dart';

void main() {
  group('printerWidthDots', () {
    test('384 points pour un rouleau de 58 mm', () {
      expect(printerWidthDots(58), 384);
    });

    test('576 points pour un rouleau de 80 mm', () {
      expect(printerWidthDots(80), 576);
    });
  });

  group('ticketFileName', () {
    test('dérive le nom du fichier de l\'identifiant de vente', () {
      expect(ticketFileName(7), 'ticket-7.pdf');
    });

    test('tolère une vente sans identifiant', () {
      expect(ticketFileName(null), 'ticket-0.pdf');
    });
  });
}
