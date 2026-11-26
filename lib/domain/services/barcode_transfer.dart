import 'package:meta/meta.dart';

import '../../core/money/money.dart';
import '../../core/quantity/quantity.dart';
import '../entities/catalog.dart';

/// Colonnes du fichier d'échange des codes-barres (CSV / Excel).
///
/// Les noms sont en anglais technique pour rester stables d'une langue à
/// l'autre ; l'analyse accepte aussi des alias français et arabes courants.
abstract final class BarcodeColumns {
  static const String barcode = 'barcode';
  static const String name = 'name';
  static const String category = 'category';
  static const String purchasePrice = 'purchase_price';
  static const String retailPrice = 'retail_price';
  static const String wholesalePrice = 'wholesale_price';
  static const String quantity = 'quantity';

  /// Ordre des colonnes à l'export.
  static const List<String> order = <String>[
    barcode,
    name,
    category,
    purchasePrice,
    retailPrice,
    wholesalePrice,
    quantity,
  ];
}

/// Raison pour laquelle une ligne du fichier n'a pas pu être retenue.
enum BarcodeImportErrorKind {
  /// Colonne code-barres vide.
  missingBarcode,

  /// Colonne nom vide.
  missingName,

  /// Valeur numérique illisible (prix, quantité).
  invalidValue,
}

/// Ligne rejetée lors de l'analyse, avec son numéro (1 = première ligne du
/// fichier, en-tête compris).
@immutable
class BarcodeImportError {
  const BarcodeImportError({required this.line, required this.kind});

  final int line;
  final BarcodeImportErrorKind kind;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BarcodeImportError &&
          other.line == line &&
          other.kind == kind);

  @override
  int get hashCode => Object.hash(line, kind);
}

/// Une ligne exploitable du fichier : code-barres et nom au minimum.
@immutable
class BarcodeRecord {
  const BarcodeRecord({
    required this.barcode,
    required this.name,
    this.categoryName,
    this.purchasePrice,
    this.retailPrice,
    this.wholesalePrice,
    this.quantity,
  });

  final String barcode;
  final String name;
  final String? categoryName;
  final Money? purchasePrice;
  final Money? retailPrice;
  final Money? wholesalePrice;
  final Qty? quantity;
}

/// Résultat de l'analyse d'un fichier : lignes retenues et lignes rejetées.
@immutable
class BarcodeImport {
  const BarcodeImport({required this.records, required this.errors});

  final List<BarcodeRecord> records;
  final List<BarcodeImportError> errors;

  bool get isEmpty => records.isEmpty && errors.isEmpty;
}

/// Traduction entre les produits et la table (liste de lignes) du fichier
/// d'échange, sans dépendance à un format de fichier ni à l'interface.
abstract final class BarcodeTransfer {
  /// Construit la table exportée (en-tête + lignes) à partir des [products].
  ///
  /// [categoryNames] permet de résoudre le nom des catégories (le produit ne
  /// porte qu'un identifiant).
  static List<List<String>> toTable(
    List<Product> products, {
    Map<int, String> categoryNames = const <int, String>{},
  }) {
    return <List<String>>[
      BarcodeColumns.order,
      for (final Product product in products)
        <String>[
          product.barcode,
          product.name,
          product.categoryId == null
              ? ''
              : categoryNames[product.categoryId] ?? '',
          _decimalText(product.purchasePrice.millimes),
          _decimalText(product.retailPrice.millimes),
          _decimalText(product.wholesalePrice.millimes),
          _decimalText(product.quantityOnHand.milliUnits),
        ],
    ];
  }

  /// Analyse une table (issue d'un CSV ou d'un XLSX) en lignes exploitables.
  static BarcodeImport parseTable(List<List<String>> rows) {
    if (rows.isEmpty) {
      return const BarcodeImport(
        records: <BarcodeRecord>[],
        errors: <BarcodeImportError>[],
      );
    }

    final Map<String, int> index = _columnIndex(rows.first);
    final bool hasHeader = index.isNotEmpty;
    final int firstDataRow = hasHeader ? 1 : 0;

    final List<BarcodeRecord> records = <BarcodeRecord>[];
    final List<BarcodeImportError> errors = <BarcodeImportError>[];

    for (int rowIndex = firstDataRow; rowIndex < rows.length; rowIndex++) {
      final List<String> cells = rows[rowIndex];
      final int line = rowIndex + 1;
      if (cells.every((String cell) => cell.trim().isEmpty)) continue;

      final String barcode =
          _cell(cells, index, BarcodeColumns.barcode, hasHeader ? null : 0);
      final String name =
          _cell(cells, index, BarcodeColumns.name, hasHeader ? null : 1);

      if (barcode.isEmpty) {
        errors.add(
          BarcodeImportError(line: line, kind: BarcodeImportErrorKind.missingBarcode),
        );
        continue;
      }
      if (name.isEmpty) {
        errors.add(
          BarcodeImportError(line: line, kind: BarcodeImportErrorKind.missingName),
        );
        continue;
      }

      final String categoryName =
          _cell(cells, index, BarcodeColumns.category, null);
      final String purchaseRaw =
          _cell(cells, index, BarcodeColumns.purchasePrice, null);
      final String retailRaw =
          _cell(cells, index, BarcodeColumns.retailPrice, null);
      final String wholesaleRaw =
          _cell(cells, index, BarcodeColumns.wholesalePrice, null);
      final String quantityRaw =
          _cell(cells, index, BarcodeColumns.quantity, null);

      final int? purchase = _parseMilliOrNull(purchaseRaw);
      final int? retail = _parseMilliOrNull(retailRaw);
      final int? wholesale = _parseMilliOrNull(wholesaleRaw);
      final int? quantity = _parseMilliOrNull(quantityRaw);

      if ((purchaseRaw.isNotEmpty && purchase == null) ||
          (retailRaw.isNotEmpty && retail == null) ||
          (wholesaleRaw.isNotEmpty && wholesale == null) ||
          (quantityRaw.isNotEmpty && quantity == null)) {
        errors.add(
          BarcodeImportError(line: line, kind: BarcodeImportErrorKind.invalidValue),
        );
        continue;
      }

      records.add(
        BarcodeRecord(
          barcode: barcode,
          name: name,
          categoryName: categoryName.isEmpty ? null : categoryName,
          purchasePrice:
              purchase == null ? null : Money.fromMillimes(purchase),
          retailPrice: retail == null ? null : Money.fromMillimes(retail),
          wholesalePrice:
              wholesale == null ? null : Money.fromMillimes(wholesale),
          quantity: quantity == null ? null : Qty.fromMilliUnits(quantity),
        ),
      );
    }

    return BarcodeImport(records: records, errors: errors);
  }

  /// Détecte les colonnes connues dans la ligne d'en-tête [header].
  ///
  /// Renvoie une table vide si aucune colonne reconnue n'est trouvée, ce qui
  /// signifie que le fichier n'a pas d'en-tête (lecture positionnelle).
  static Map<String, int> _columnIndex(List<String> header) {
    final Map<String, int> index = <String, int>{};
    for (int column = 0; column < header.length; column++) {
      final String key = _canonicalColumn(header[column]);
      if (key != null && !index.containsKey(key)) {
        index[key] = column;
      }
    }
    // Un en-tête n'est retenu que s'il porte au moins le code-barres ou le nom.
    if (!index.containsKey(BarcodeColumns.barcode) &&
        !index.containsKey(BarcodeColumns.name)) {
      return const <String, int>{};
    }
    return index;
  }

  /// Normalise un intitulé de colonne vers une clé canonique (ou `null`).
  static String? _canonicalColumn(String raw) {
    final String key = raw
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[\s\-]+'), '_');
    return _columnAliases[key];
  }

  /// Alias acceptés pour chaque clé canonique (anglais / français / arabe).
  static const Map<String, String> _columnAliases = <String, String>{
    'barcode': BarcodeColumns.barcode,
    'code_barre': BarcodeColumns.barcode,
    'code_barres': BarcodeColumns.barcode,
    'codebarre': BarcodeColumns.barcode,
    'codebarres': BarcodeColumns.barcode,
    'الباركود': BarcodeColumns.barcode,
    'الرمز': BarcodeColumns.barcode,
    'name': BarcodeColumns.name,
    'nom': BarcodeColumns.name,
    'designation': BarcodeColumns.name,
    'libelle': BarcodeColumns.name,
    'الاسم': BarcodeColumns.name,
    'اسم': BarcodeColumns.name,
    'category': BarcodeColumns.category,
    'categorie': BarcodeColumns.category,
    'الفئة': BarcodeColumns.category,
    'purchase_price': BarcodeColumns.purchasePrice,
    'prix_achat': BarcodeColumns.purchasePrice,
    'prix_d_achat': BarcodeColumns.purchasePrice,
    'سعر_الشراء': BarcodeColumns.purchasePrice,
    'retail_price': BarcodeColumns.retailPrice,
    'prix_detail': BarcodeColumns.retailPrice,
    'prix_de_detail': BarcodeColumns.retailPrice,
    'prix_vente': BarcodeColumns.retailPrice,
    'سعر_البيع': BarcodeColumns.retailPrice,
    'wholesale_price': BarcodeColumns.wholesalePrice,
    'prix_gros': BarcodeColumns.wholesalePrice,
    'prix_de_gros': BarcodeColumns.wholesalePrice,
    'سعر_الجملة': BarcodeColumns.wholesalePrice,
    'quantity': BarcodeColumns.quantity,
    'quantite': BarcodeColumns.quantity,
    'stock': BarcodeColumns.quantity,
    'الكمية': BarcodeColumns.quantity,
  };

  /// Lit la colonne [key] ; à défaut la colonne [fallback] (mode positionnel).
  static String _cell(
    List<String> cells,
    Map<String, int> index,
    String key,
    int? fallback,
  ) {
    final int? column = index[key] ?? fallback;
    if (column == null || column < 0 || column >= cells.length) return '';
    return cells[column].trim();
  }

  /// Formate des milli-unités entières en décimal exact (« 3.45 », « 2 »).
  static String _decimalText(int milliUnits) {
    final bool negative = milliUnits < 0;
    final int absolute = milliUnits.abs();
    final int whole = absolute ~/ Money.scale;
    final String fraction =
        (absolute % Money.scale).toString().padLeft(3, '0').replaceAll(
              RegExp(r'0+$'),
              '',
            );
    final String text = fraction.isEmpty ? '$whole' : '$whole.$fraction';
    return negative ? '-$text' : text;
  }

  /// Analyse une saisie décimale exacte (au plus 3 décimales) en milli-unités.
  static int? _parseMilliOrNull(String raw) {
    final String text = raw.trim().replaceAll(',', '.');
    if (text.isEmpty) return null;
    final RegExpMatch? match =
        RegExp(r'^(\d+)(?:\.(\d{1,3}))?$').firstMatch(text);
    if (match == null) return null;
    final String fraction = (match.group(2) ?? '').padRight(3, '0');
    return int.parse(match.group(1)!) * Money.scale + int.parse(fraction);
  }
}
