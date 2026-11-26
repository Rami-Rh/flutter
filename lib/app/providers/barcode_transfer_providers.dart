import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:meta/meta.dart';

import '../../core/files/barcode_file_codec.dart';
import '../../core/files/file_share_gateway.dart';
import '../../core/money/money.dart';
import '../../core/pdf/report_exporter.dart';
import '../../core/quantity/quantity.dart';
import '../../domain/entities/catalog.dart';
import '../../domain/repositories/category_repository.dart';
import '../../domain/repositories/product_repository.dart';
import '../../domain/services/barcode_transfer.dart';
import '../../domain/units/units.dart';
import 'repository_providers.dart';

/// Tous les produits (actifs ou non), pour l'export et la génération des
/// étiquettes : l'export ne doit pas dépendre des filtres de l'écran catalogue.
final FutureProvider<List<Product>> barcodeCatalogProvider =
    FutureProvider<List<Product>>(
  (Ref ref) => ref.watch(productRepositoryProvider).getAll(onlyActive: false),
  name: 'barcodeCatalogProvider',
);

/// Bilan d'un import de codes-barres.
@immutable
class BarcodeImportSummary {
  const BarcodeImportSummary({
    required this.created,
    required this.assigned,
    required this.unchanged,
    required this.unresolved,
    required this.invalid,
  });

  /// Produits créés (option « créer les produits manquants »).
  final int created;

  /// Produits existants auxquels le code-barres a été rattaché.
  final int assigned;

  /// Codes-barres déjà présents en base (aucune action).
  final int unchanged;

  /// Lignes sans correspondance, création désactivée.
  final int unresolved;

  /// Lignes rejetées lors de l'analyse.
  final int invalid;

  /// Nombre total de lignes traitées.
  int get total => created + assigned + unchanged + unresolved + invalid;
}

/// Nom de fichier daté de l'export (`codes-barres-2026-11-26.csv`).
String barcodeExportFileName(String extension, {DateTime? now}) =>
    'codes-barres-${DateFormat('yyyy-MM-dd').format(now ?? DateTime.now())}'
    '.$extension';

/// Import / export des codes-barres (CSV, Excel, PDF) et partage des fichiers.
class BarcodeTransferController {
  BarcodeTransferController(this._ref);

  final Ref _ref;

  static const String _xlsxMime =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

  ProductRepository get _products => _ref.read(productRepositoryProvider);

  CategoryRepository get _categories => _ref.read(categoryRepositoryProvider);

  FileShareGateway get _share => _ref.read(fileShareGatewayProvider);

  /// Produits exportés (tous, actifs ou non).
  Future<List<Product>> products() => _products.getAll(onlyActive: false);

  /// Table exportée (en-tête + lignes), catégories résolues par leur nom.
  Future<List<List<String>>> _table() async {
    final List<Product> products = await products();
    final List<Category> categories = await _categories.getAll();
    final Map<int, String> names = <int, String>{
      for (final Category category in categories)
        if (category.id != null) category.id!: category.name,
    };
    return BarcodeTransfer.toTable(products, categoryNames: names);
  }

  /// Exporte le catalogue en CSV et ouvre le partage. Renvoie le nombre de
  /// produits exportés.
  Future<int> exportCsv() async {
    final List<List<String>> table = await _table();
    final Uint8List bytes =
        Uint8List.fromList(utf8.encode(BarcodeFileCodec.encodeCsv(table)));
    await _share.shareBytes(
      bytes,
      fileName: barcodeExportFileName('csv'),
      mimeType: 'text/csv',
    );
    return table.length - 1;
  }

  /// Exporte le catalogue en classeur Excel et ouvre le partage.
  Future<int> exportExcel() async {
    final List<List<String>> table = await _table();
    await _share.shareBytes(
      BarcodeFileCodec.encodeXlsx(table),
      fileName: barcodeExportFileName('xlsx'),
      mimeType: _xlsxMime,
    );
    return table.length - 1;
  }

  /// Partage le PDF du contenu imprimable référencé par [boundaryKey].
  Future<void> exportPdf(GlobalKey boundaryKey) => _ref
      .read(reportExporterProvider)
      .shareReport(boundaryKey, fileName: barcodeExportFileName('pdf'));

  /// Importe les codes-barres contenus dans [bytes] (fichier [fileName]).
  ///
  /// Chaque ligne rattache son code-barres au produit portant ce nom ; si
  /// [createMissing] est vrai, une ligne sans correspondance crée un produit.
  Future<BarcodeImportSummary> importFile(
    String fileName,
    Uint8List bytes, {
    required bool createMissing,
  }) async {
    final List<List<String>> rows = _decode(fileName, bytes);
    final BarcodeImport parsed = BarcodeTransfer.parseTable(rows);

    final List<Product> all = await _products.getAll(onlyActive: false);
    final Map<String, Product> byBarcode = <String, Product>{
      for (final Product product in all) product.barcode: product,
    };
    final Map<String, Product> byName = <String, Product>{};
    for (final Product product in all) {
      byName.putIfAbsent(product.name.trim().toLowerCase(), () => product);
    }

    int created = 0;
    int assigned = 0;
    int unchanged = 0;
    int unresolved = 0;

    for (final BarcodeRecord record in parsed.records) {
      if (byBarcode.containsKey(record.barcode)) {
        unchanged++;
        continue;
      }

      final Product? match = byName[record.name.trim().toLowerCase()];
      if (match != null) {
        final Product updated = match.copyWith(barcode: record.barcode);
        await _products.update(updated);
        byBarcode[record.barcode] = updated;
        assigned++;
        continue;
      }

      if (!createMissing) {
        unresolved++;
        continue;
      }

      final Product product = Product(
        name: record.name,
        barcode: record.barcode,
        packaging: PackagingConfig.pieces(),
        purchasePrice: record.purchasePrice ?? Money.zero,
        retailPrice: record.retailPrice ?? Money.zero,
        wholesalePrice: record.wholesalePrice ?? Money.zero,
        quantityOnHand: record.quantity ?? Qty.zero,
      );
      final int id = await _products.create(product);
      final Product saved = product.copyWith(id: id);
      byBarcode[record.barcode] = saved;
      byName.putIfAbsent(record.name.trim().toLowerCase(), () => saved);
      created++;
    }

    return BarcodeImportSummary(
      created: created,
      assigned: assigned,
      unchanged: unchanged,
      unresolved: unresolved,
      invalid: parsed.errors.length,
    );
  }

  /// Décode le fichier importé selon son extension.
  List<List<String>> _decode(String fileName, Uint8List bytes) {
    final String lower = fileName.toLowerCase();
    if (lower.endsWith('.xlsx')) {
      return BarcodeFileCodec.decodeXlsx(bytes);
    }
    return BarcodeFileCodec.decodeCsv(utf8.decode(bytes, allowMalformed: true));
  }
}

/// Import / export des codes-barres (surchargé dans les tests).
final Provider<BarcodeTransferController> barcodeTransferControllerProvider =
    Provider<BarcodeTransferController>(
  BarcodeTransferController.new,
  name: 'barcodeTransferControllerProvider',
);
