import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/l10n/failure_messages.dart';
import '../../../app/providers/sale_providers.dart';
import '../../../app/providers/settings_providers.dart';
import '../../../core/errors/failures.dart';
import '../../../core/printing/printer_gateway.dart';
import '../../../core/printing/ticket_printer.dart';
import '../../../domain/entities/app_settings.dart';
import '../../../domain/entities/catalog.dart';
import '../../../domain/entities/sale.dart';
import '../../../domain/units/units.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../catalog/presentation/catalog_helpers.dart';
import '../../catalog/presentation/widgets/catalog_states.dart';
import 'sales_helpers.dart';

/// Aperçu d'un ticket de vente, avec impression ESC/POS et partage du PDF.
///
/// Le ticket est rendu à l'écran (noir sur blanc, arabe correctement mis en
/// forme) dans un `RepaintBoundary` : cette image unique sert à la fois à
/// l'impression thermique (58/80 mm) et au PDF partagé.
class SaleTicketScreen extends ConsumerStatefulWidget {
  const SaleTicketScreen({required this.saleId, super.key});

  final int saleId;

  @override
  ConsumerState<SaleTicketScreen> createState() => _SaleTicketScreenState();
}

class _SaleTicketScreenState extends ConsumerState<SaleTicketScreen> {
  final GlobalKey _boundaryKey = GlobalKey();
  bool _busy = false;

  /// Adresse de l'imprimante : celle mémorisée, sinon choix parmi les appareils
  /// appairés (et mémorisation du choix). `null` si l'utilisateur renonce.
  Future<String?> _resolvePrinterAddress(
    TicketPrinter printer,
    AppSettings settings,
  ) async {
    final String? saved = settings.printerAddress;
    if (saved != null && saved.trim().isNotEmpty) return saved;

    if (!await printer.bluetoothEnabled()) {
      throw const AppFailure(
        FailureCode.printerUnavailable,
        debugMessage: 'Bluetooth désactivé.',
      );
    }
    final List<PrinterDevice> devices = await printer.devices();
    if (!mounted) return null;
    if (devices.isEmpty) {
      throw const AppFailure(
        FailureCode.printerUnavailable,
        debugMessage: 'Aucune imprimante appairée.',
      );
    }
    if (devices.length == 1) {
      await _rememberPrinter(devices.first);
      return devices.first.address;
    }
    final PrinterDevice? chosen = await showPrinterPicker(context, devices);
    if (chosen == null) return null;
    await _rememberPrinter(chosen);
    return chosen.address;
  }

  Future<void> _rememberPrinter(PrinterDevice device) =>
      ref.read(settingsControllerProvider).update(
            (AppSettings current) => current.copyWith(
              printerAddress: device.address,
              printerName: device.name,
            ),
          );

  Future<void> _print(AppSettings settings) async {
    if (_busy) return;
    final AppLocalizations l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      final TicketPrinter printer = ref.read(ticketPrinterProvider);
      final String? address = await _resolvePrinterAddress(printer, settings);
      if (address == null) return;
      await printer.printTicket(
        _boundaryKey,
        paperWidthMm: settings.paperWidthMm,
        address: address,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.saleTicketPrintDone)),
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

  Future<void> _sharePdf(AppSettings settings) async {
    if (_busy) return;
    final AppLocalizations l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(ticketPrinterProvider).shareTicketPdf(
            _boundaryKey,
            paperWidthMm: settings.paperWidthMm,
            fileName: ticketFileName(widget.saleId),
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
    final AsyncValue<SaleWithProducts?> detail =
        ref.watch(saleDetailProvider(widget.saleId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.saleTicketTitle)),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stackTrace) =>
            CatalogErrorView(message: failureMessage(l10n, error)),
        data: (SaleWithProducts? data) {
          if (data == null) {
            return CatalogEmptyView(message: l10n.errorNotFound);
          }
          return Column(
            children: <Widget>[
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: SizedBox(
                      width: 320,
                      child: RepaintBoundary(
                        key: _boundaryKey,
                        child: SaleTicketView(
                          sale: data.sale,
                          products: data.products,
                          settings: settings,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              _TicketActions(
                busy: _busy,
                onPrint: () {
                  unawaited(_print(settings));
                },
                onShare: () {
                  unawaited(_sharePdf(settings));
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Barre d'actions : impression thermique et partage du PDF.
class _TicketActions extends StatelessWidget {
  const _TicketActions({
    required this.busy,
    required this.onPrint,
    required this.onShare,
  });

  final bool busy;
  final VoidCallback onPrint;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Material(
      elevation: 3,
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: <Widget>[
              Expanded(
                child: FilledButton.icon(
                  onPressed: busy ? null : onPrint,
                  icon: const Icon(Icons.print_outlined),
                  label: Text(l10n.saleTicketPrintAction),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : onShare,
                  icon: const Icon(Icons.ios_share),
                  label: Text(l10n.saleTicketShareAction),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rendu **imprimable** du ticket : noir sur blanc, indépendant du thème.
///
/// Les couleurs sont figées (une imprimante thermique ne restitue que le noir) ;
/// la mise en page suit la direction du texte (RTL en arabe).
class SaleTicketView extends StatelessWidget {
  const SaleTicketView({
    required this.sale,
    required this.products,
    required this.settings,
    super.key,
  });

  final Sale sale;
  final Map<int, Product> products;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String locale = settings.language.code;
    final String? storeName = settings.storeName?.trim();
    const TextStyle small = TextStyle(fontSize: 11);
    const TextStyle bold = TextStyle(fontWeight: FontWeight.bold);

    return DefaultTextStyle(
      style: const TextStyle(color: Colors.black, fontSize: 12, height: 1.3),
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              storeName == null || storeName.isEmpty
                  ? l10n.appTitle
                  : storeName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (sale.isCancelled)
              Text(
                '*** ${l10n.saleCancelledLabel} ***',
                textAlign: TextAlign.center,
                style: bold,
              ),
            const SizedBox(height: 4),
            Text(
              '${formatSaleDate(locale, sale.date)}  '
              '${formatSaleTime(locale, sale.date)}',
              textAlign: TextAlign.center,
              style: small,
            ),
            Text(
              '${saleModeLabel(l10n, sale.mode)} • '
              '${l10n.saleItemsCount(sale.itemCount)}',
              textAlign: TextAlign.center,
              style: small,
            ),
            const _TicketDivider(),
            Row(
              children: <Widget>[
                Expanded(flex: 3, child: Text(l10n.saleTicketQuantityHeader)),
                const SizedBox(width: 6),
                Expanded(flex: 5, child: Text(l10n.fieldName)),
                const SizedBox(width: 6),
                Expanded(
                  flex: 3,
                  child: Text(
                    l10n.saleTicketAmountHeader,
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
            const _TicketDivider(),
            for (final SaleItem item in sale.items)
              _TicketItemRow(
                item: item,
                settings: settings,
                baseUnit: saleItemBaseUnit(item, products[item.productId]),
              ),
            const _TicketDivider(),
            _TicketAmountRow(
              label: l10n.reportSubtotal,
              value: formatMoney(settings, sale.subtotal),
            ),
            _TicketAmountRow(
              label: l10n.reportDiscount,
              value: formatMoney(settings, sale.discount),
            ),
            const _TicketDivider(),
            _TicketAmountRow(
              label: l10n.reportTotal,
              value: formatMoney(settings, sale.total),
              emphasized: true,
            ),
            if (sale.note != null && sale.note!.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text('${l10n.fieldNotes} : ${sale.note!.trim()}', style: small),
            ],
          ],
        ),
      ),
    );
  }
}

/// Ligne d'article du ticket : quantité, nom et montant.
class _TicketItemRow extends StatelessWidget {
  const _TicketItemRow({
    required this.item,
    required this.settings,
    required this.baseUnit,
  });

  final SaleItem item;
  final AppSettings settings;
  final StockBaseUnit baseUnit;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            flex: 3,
            child: Text(
              '${formatSaleItemQuantity(settings, item, baseUnit)} '
              '${packagingUnitLabel(l10n, item.packagingUnit, baseUnit)}',
            ),
          ),
          const SizedBox(width: 6),
          Expanded(flex: 5, child: Text(item.productName ?? '')),
          const SizedBox(width: 6),
          Expanded(
            flex: 3,
            child: Text(
              formatMoney(settings, item.lineTotal),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

/// Ligne « libellé — montant » du pied de ticket.
class _TicketAmountRow extends StatelessWidget {
  const _TicketAmountRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final TextStyle? style =
        emphasized ? const TextStyle(fontWeight: FontWeight.bold) : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: <Widget>[
          Text(label, style: style),
          const Spacer(),
          Text(value, style: style),
        ],
      ),
    );
  }
}

/// Séparateur noir fin (indépendant du thème, contrairement à `Divider`).
class _TicketDivider extends StatelessWidget {
  const _TicketDivider();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: SizedBox(height: 1, child: ColoredBox(color: Colors.black)),
      );
}

/// Feuille de choix parmi les imprimantes disponibles.
Future<PrinterDevice?> showPrinterPicker(
  BuildContext context,
  List<PrinterDevice> devices,
) {
  return showModalBottomSheet<PrinterDevice>(
    context: context,
    useSafeArea: true,
    builder: (BuildContext context) {
      final AppLocalizations l10n = AppLocalizations.of(context);
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.saleTicketSelectPrinter,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final PrinterDevice device in devices)
              ListTile(
                leading: const Icon(Icons.print_outlined),
                title: Text(device.name),
                subtitle: Text(device.address),
                onTap: () => Navigator.of(context).pop(device),
              ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}
