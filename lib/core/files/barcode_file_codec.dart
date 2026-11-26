import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';

/// Encodage et décodage des fichiers d'échange de codes-barres.
///
/// La table manipulée est une liste de lignes de chaînes : le même contenu
/// alimente le CSV et l'Excel, et se relit à l'identique.
abstract final class BarcodeFileCodec {
  /// Sérialise [rows] en CSV (séparateur virgule, guillemets échappés).
  static String encodeCsv(List<List<String>> rows) =>
      const ListToCsvConverter().convert(rows);

  /// Analyse un contenu CSV en table de chaînes.
  ///
  /// Le séparateur (virgule, point-virgule ou tabulation) est détecté
  /// automatiquement et l'éventuel BOM est retiré.
  static List<List<String>> decodeCsv(String content) {
    final String text =
        content.startsWith('\uFEFF') ? content.substring(1) : content;
    final List<List<dynamic>> raw = CsvToListConverter(
      fieldDelimiter: _detectDelimiter(text),
      shouldParseNumbers: false,
    ).convert(text);
    return raw
        .map(
          (List<dynamic> row) => row
              .map((dynamic cell) => cell?.toString().trim() ?? '')
              .toList(),
        )
        .toList();
  }

  /// Sérialise [rows] en classeur XLSX (première feuille).
  static Uint8List encodeXlsx(List<List<String>> rows) {
    final Excel excel = Excel.createExcel();
    final String sheetName = excel.getDefaultSheet() ?? 'Sheet1';
    final Sheet sheet = excel[sheetName];
    for (final List<String> row in rows) {
      sheet.appendRow(
        row.map<CellValue?>((String cell) => TextCellValue(cell)).toList(),
      );
    }
    final List<int>? bytes = excel.save();
    if (bytes == null) {
      throw StateError('Encodage XLSX impossible.');
    }
    return Uint8List.fromList(bytes);
  }

  /// Analyse un classeur XLSX en table de chaînes (feuilles concaténées).
  static List<List<String>> decodeXlsx(Uint8List bytes) {
    final Excel excel = Excel.decodeBytes(bytes);
    final List<List<String>> rows = <List<String>>[];
    for (final Sheet sheet in excel.tables.values) {
      for (final List<Data?> row in sheet.rows) {
        rows.add(row.map((Data? cell) => _cellText(cell?.value)).toList());
      }
    }
    return rows;
  }

  /// Détermine le séparateur de colonnes le plus probable du CSV.
  static String _detectDelimiter(String text) {
    final int end = text.indexOf('\n');
    final String firstLine = end == -1 ? text : text.substring(0, end);
    const List<String> candidates = <String>[',', ';', '\t'];
    String best = ',';
    int bestCount = 0;
    for (final String candidate in candidates) {
      final int count = candidate.allMatches(firstLine).length;
      if (count > bestCount) {
        best = candidate;
        bestCount = count;
      }
    }
    return best;
  }

  /// Convertit une valeur de cellule en chaîne exploitable.
  static String _cellText(CellValue? value) => switch (value) {
        null => '',
        TextCellValue v => v.value.text?.trim() ?? '',
        IntCellValue v => '${v.value}',
        DoubleCellValue v => _numberText(v.value),
        BoolCellValue v => v.value ? 'true' : 'false',
        _ => '',
      };

  /// Formate un nombre lu dans un classeur (affichage uniquement).
  static String _numberText(double value) {
    if (value.isFinite && value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toString();
  }
}
