import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/l10n/failure_messages.dart';
import '../../../app/providers/barcode_transfer_providers.dart';
import '../../../app/providers/settings_providers.dart';
import '../../../core/files/file_pick_gateway.dart';
import '../../../core/printing/ticket_printer.dart';
import '../../../domain/entities/app_settings.dart';
import '../../../domain/entities/catalog.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../catalog/presentation/widgets/catalog_states.dart';
import 'barcode_helpers.dart';
import 'widgets/barcode_label_view.dart';
import 'widgets/barcode_print_list.dart';

/// Import / export des codes-barres (CSV, Excel, PDF) et impression
/// d'étiquettes sur rouleau thermique 58/80 mm.
class BarcodeTransferScreen extends StatelessWidget {
  const BarcodeTransferScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.barcodeTransferTitle),
          bottom: TabBar(
            tabs: <Widget>[
              Tab(text: l10n.barcodeTabExport),
              Tab(text: l10n.barcodeTabImport),
              Tab(text: l10n.barcodeTabLabels),
            ],
          ),
        ),
        body: const TabBarView(
          children: <Widget>[
            _ExportTab(),
            _ImportTab(),
            _LabelsTab(),
          ],
        ),
      ),
    );
  }
}

// --- Export ----------------------------------------------------------------

/// Onglet « Exporter » : CSV, Excel ou PDF de la liste des codes-barres.
class _ExportTab extends ConsumerStatefulWidget {
  const _ExportTab();

  @override
  ConsumerState<_ExportTab> createState() => _ExportTabState();
}

class _ExportTabState extends ConsumerState<_ExportTab> {
  final GlobalKey _boundaryKey = GlobalKey();
  bool _busy = false;

  Future<void> _run(Future<int> Function() job) async {
    if (_busy) return;
    final AppLocalizations l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      final int count = await job();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.barcodeExportDone(count))),
      );
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failureMessage(l10n, error))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sharePdf() async {
    if (_busy) return;
    final AppLocalizations l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(barcodeTransferControllerProvider).exportPdf(_boundaryKey);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.barcodeExportPdfDone)),
      );
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failureMessage(l10n, error))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppSettings settings =
        ref.watch(settingsProvider).valueOrNull ?? AppSettings.defaults;
    final AsyncValue<List<Product>> catalog = ref.watch(barcodeCatalogProvider);

    return catalog.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object error, StackTrace stackTrace) =>
          CatalogErrorView(message: failureMessage(l10n, error)),
      data: (List<Product> products) {
        if (products.isEmpty) {
          return CatalogEmptyView(message: l10n.barcodeExportEmpty);
        }
        return Column(
          children: <Widget>[
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: SizedBox(
                    width: 420,
                    child: RepaintBoundary(
                      key: _boundaryKey,
                      child: BarcodePrintListView(
                        products: products,
                        settings: settings,
                        title: l10n.barcodeExportPdfTitle,
                        countLabel: l10n.barcodeExportCount(products.length),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            _ActionBar(
              busy: _busy,
              children: <Widget>[
                FilledButton.icon(
                  onPressed: _busy
                      ? null
                      : () => unawaited(
                            _run(
                              ref
                                  .read(barcodeTransferControllerProvider)
                                  .exportCsv,
                            ),
                          ),
                  icon: const Icon(Icons.description_outlined),
                  label: Text(l10n.barcodeExportCsvAction),
                ),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: _busy
                      ? null
                      : () => unawaited(
                            _run(
                              ref
                                  .read(barcodeTransferControllerProvider)
                                  .exportExcel,
                            ),
                          ),
                  icon: const Icon(Icons.table_chart_outlined),
                  label: Text(l10n.barcodeExportExcelAction),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => unawaited(_sharePdf()),
                  icon: const Icon(Icons.ios_share),
                  label: Text(l10n.barcodeExportPdfAction),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

// --- Import ----------------------------------------------------------------

/// Onglet « Importer » : rattache des codes-barres depuis un CSV / Excel.
class _ImportTab extends ConsumerStatefulWidget {
  const _ImportTab();

  @override
  ConsumerState<_ImportTab> createState() => _ImportTabState();
}

class _ImportTabState extends ConsumerState<_ImportTab> {
  bool _busy = false;
  bool _createMissing = false;
  PickedFile? _picked;
  BarcodeImportSummary? _summary;

  Future<void> _pick() async {
    final PickedFile? file = await ref
        .read(filePickGatewayProvider)
        .pickDocument(extensions: const <String>['csv', 'xlsx']);
    if (!mounted || file == null) return;
    setState(() {
      _picked = file;
      _summary = null;
    });
  }

  Future<void> _import() async {
    final PickedFile? file = _picked;
    if (_busy || file == null) return;
    final AppLocalizations l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      final BarcodeImportSummary summary = await ref
          .read(barcodeTransferControllerProvider)
          .importFile(file.name, file.bytes, createMissing: _createMissing);
      if (!mounted) return;
      setState(() => _summary = summary);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.barcodeImportDone)),
      );
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failureMessage(l10n, error))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final PickedFile? picked = _picked;
    final BarcodeImportSummary? summary = _summary;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Text(
          l10n.barcodeImportHint,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.barcodeImportCreateMissing),
          value: _createMissing,
          onChanged: _busy
              ? null
              : (bool value) => setState(() => _createMissing = value),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _busy ? null : () => unawaited(_pick()),
          icon: const Icon(Icons.upload_file_outlined),
          label: Text(l10n.barcodeImportPickAction),
        ),
        if (picked != null) ...<Widget>[
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.insert_drive_file_outlined),
            title: Text(picked.name),
            subtitle: Text(l10n.barcodeImportFileReady),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _busy || picked == null ? null : () => unawaited(_import()),
          icon: const Icon(Icons.download_outlined),
          label: Text(l10n.barcodeImportAction),
        ),
        if (summary != null) ...<Widget>[
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.barcodeImportSummary(
                  summary.created,
                  summary.assigned,
                  summary.unchanged,
                  summary.unresolved,
                  summary.invalid,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// --- Étiquettes ------------------------------------------------------------

/// Onglet « Étiquettes » : sélection des produits et impression thermique.
class _LabelsTab extends ConsumerStatefulWidget {
  const _LabelsTab();

  @override
  ConsumerState<_LabelsTab> createState() => _LabelsTabState();
}

class _LabelsTabState extends ConsumerState<_LabelsTab> {
  /// Produit sélectionné → nombre de copies (l'ordre suit celui du catalogue).
  final Map<int, int> _selection = <int, int>{};
  final GlobalKey _boundaryKey = GlobalKey();
  bool _busy = false;

  static const int _maxCopies = 50;
  static const int _maxLabels = 200;

  int get _labelCount =>
      _selection.values.fold(0, (int sum, int copies) => sum + copies);

  void _toggle(int productId, bool selected) {
    setState(() {
      if (selected) {
        _selection[productId] = 1;
      } else {
        _selection.remove(productId);
      }
    });
  }

  void _changeCopies(int productId, int delta) {
    final int current = _selection[productId] ?? 1;
    final int next = (current + delta).clamp(1, _maxCopies);
    setState(() => _selection[productId] = next);
  }

  Future<void> _print(List<Product> products, AppSettings settings) async {
    if (_busy) return;
    final AppLocalizations l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      final TicketPrinter printer = ref.read(ticketPrinterProvider);
      final String? address =
          await resolveBarcodePrinter(context, ref, printer, settings);
      if (address == null) return;
      // Les étiquettes réutilisent la chaîne d'impression raster du ticket :
      // capture Flutter (arabe correct) puis tramage ESC/POS du rouleau.
      await printer.printTicket(
        _boundaryKey,
        paperWidthMm: settings.paperWidthMm,
        address: address,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.barcodeLabelsPrintDone)),
      );
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failureMessage(l10n, error))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppSettings settings =
        ref.watch(settingsProvider).valueOrNull ?? AppSettings.defaults;
    final AsyncValue<List<Product>> catalog = ref.watch(barcodeCatalogProvider);

    return catalog.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object error, StackTrace stackTrace) =>
          CatalogErrorView(message: failureMessage(l10n, error)),
      data: (List<Product> products) {
        if (products.isEmpty) {
          return CatalogEmptyView(message: l10n.barcodeExportEmpty);
        }
        final List<Product> selected = products
            .where((Product product) => _selection.containsKey(product.id))
            .toList(growable: false);
        return Column(
          children: <Widget>[
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Text(
                      l10n.barcodeLabelsHint,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  for (final Product product in products)
                    _LabelSelectorTile(
                      product: product,
                      selected: _selection.containsKey(product.id),
                      copies: _selection[product.id] ?? 1,
                      enabled: !_busy,
                      onToggle: (bool value) =>
                          _toggle(product.id!, value),
                      onDecrease: () => _changeCopies(product.id!, -1),
                      onIncrease: () => _changeCopies(product.id!, 1),
                    ),
                  if (selected.isNotEmpty) ...<Widget>[
                    const Divider(height: 32),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          l10n.barcodeLabelCopies,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: RepaintBoundary(
                        key: _boundaryKey,
                        child: Container(
                          color: Colors.white,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              for (final Product product in selected)
                                for (int copy = 0;
                                    copy < (_selection[product.id] ?? 1);
                                    copy++)
                                  Padding(
                                    padding:
                                        const EdgeInsets.only(bottom: 12),
                                    child: BarcodeLabelView(
                                      product: product,
                                      settings: settings,
                                    ),
                                  ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            _ActionBar(
              busy: _busy,
              children: <Widget>[
                FilledButton.icon(
                  onPressed: _busy || selected.isEmpty
                      ? null
                      : () => unawaited(_print(products, settings)),
                  icon: const Icon(Icons.print_outlined),
                  label: Text(l10n.barcodeLabelsPrintAction),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// Ligne de sélection d'un produit avec réglage du nombre de copies.
class _LabelSelectorTile extends StatelessWidget {
  const _LabelSelectorTile({
    required this.product,
    required this.selected,
    required this.copies,
    required this.enabled,
    required this.onToggle,
    required this.onDecrease,
    required this.onIncrease,
  });

  final Product product;
  final bool selected;
  final int copies;
  final bool enabled;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: selected,
      onChanged: enabled
          ? (bool? value) => onToggle(value ?? false)
          : null,
      title: Text(product.name),
      subtitle: Text(product.barcode),
      secondary: selected
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                IconButton(
                  tooltip: '-',
                  onPressed: enabled ? onDecrease : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text('$copies'),
                IconButton(
                  tooltip: '+',
                  onPressed: enabled ? onIncrease : null,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            )
          : null,
    );
  }
}

/// Barre d'actions commune aux onglets (fond de surface, marge basse sûre).
class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.busy, required this.children});

  final bool busy;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 3,
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
  }
}
