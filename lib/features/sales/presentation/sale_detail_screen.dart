import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/l10n/failure_messages.dart';
import '../../../app/providers/sale_providers.dart';
import '../../../app/providers/settings_providers.dart';
import '../../../app/router/app_router.dart';
import '../../../domain/entities/app_settings.dart';
import '../../../domain/entities/sale.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../catalog/presentation/catalog_helpers.dart';
import '../../catalog/presentation/widgets/catalog_states.dart';
import '../../catalog/presentation/widgets/confirm_dialog.dart';
import 'sales_helpers.dart';
import 'widgets/sale_tile.dart';

/// Détail d'une vente : lignes, totaux et annulation (remise en stock).
class SaleDetailScreen extends ConsumerWidget {
  const SaleDetailScreen({required this.saleId, super.key});

  final int saleId;

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool confirmed = await confirmAction(
      context,
      title: l10n.deleteConfirmTitle,
      message: l10n.saleCancelConfirm,
      confirmLabel: l10n.actionConfirm,
      cancelLabel: l10n.actionCancel,
    );
    if (!confirmed) return;

    try {
      await ref.read(saleControllerProvider).cancel(saleId);
      ref.invalidate(saleDetailProvider(saleId));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.saleCancelDone)),
      );
      Navigator.of(context).pop();
    } on Object catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failureMessage(l10n, error))),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppSettings settings =
        ref.watch(settingsProvider).valueOrNull ?? AppSettings.defaults;
    final AsyncValue<SaleWithProducts?> detail =
        ref.watch(saleDetailProvider(saleId));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.saleDetailTitle),
        actions: <Widget>[
          IconButton(
            tooltip: l10n.saleTicketAction,
            onPressed: () => context.push(AppRoutes.saleTicketPath(saleId)),
            icon: const Icon(Icons.receipt_long_outlined),
          ),
        ],
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stackTrace) =>
            CatalogErrorView(message: failureMessage(l10n, error)),
        data: (SaleWithProducts? data) {
          if (data == null) {
            return CatalogEmptyView(message: l10n.errorNotFound);
          }
          return _SaleDetailView(
            data: data,
            settings: settings,
            onCancel: () {
              _cancel(context, ref);
            },
          );
        },
      ),
    );
  }
}

class _SaleDetailView extends StatelessWidget {
  const _SaleDetailView({
    required this.data,
    required this.settings,
    required this.onCancel,
  });

  final SaleWithProducts data;
  final AppSettings settings;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final Sale sale = data.sale;
    final String locale = settings.language.code;

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      formatSaleDate(locale, sale.date),
                      style: textTheme.titleMedium,
                    ),
                    const Spacer(),
                    Text(
                      formatSaleTime(locale, sale.date),
                      style: textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    SaleBadge(
                      label: saleModeLabel(l10n, sale.mode),
                      background: scheme.secondaryContainer,
                      foreground: scheme.onSecondaryContainer,
                    ),
                    if (sale.isCancelled)
                      SaleBadge(
                        label: l10n.saleCancelledLabel,
                        background: scheme.errorContainer,
                        foreground: scheme.onErrorContainer,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Text(
            l10n.saleItemsCount(sale.itemCount),
            style: textTheme.titleSmall,
          ),
        ),
        for (final SaleItem item in sale.items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _SaleItemTile(
              item: item,
              settings: settings,
              baseUnit: saleItemBaseUnit(item, data.productOf(item.productId)),
            ),
          ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: <Widget>[
                _SummaryRow(
                  label: l10n.reportSubtotal,
                  value: formatMoney(settings, sale.subtotal),
                ),
                _SummaryRow(
                  label: l10n.reportDiscount,
                  value: formatMoney(settings, sale.discount),
                ),
                const Divider(height: 20),
                _SummaryRow(
                  label: l10n.reportTotal,
                  value: formatMoney(settings, sale.total),
                  emphasized: true,
                ),
              ],
            ),
          ),
        ),
        if (!sale.isCancelled) ...<Widget>[
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onCancel,
            icon: const Icon(Icons.undo),
            label: Text(l10n.saleCancelAction),
          ),
        ],
      ],
    );
  }
}

/// Ligne d'article d'une vente : nom, quantité vendue et total.
class _SaleItemTile extends StatelessWidget {
  const _SaleItemTile({
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
    return Card(
      child: ListTile(
        title: Text(item.productName ?? ''),
        subtitle: Text(
          '${formatSaleItemQuantity(settings, item, baseUnit)} '
          '${packagingUnitLabel(l10n, item.packagingUnit, baseUnit)}',
        ),
        trailing: Text(
          formatMoney(settings, item.lineTotal),
          style: Theme.of(context).textTheme.labelLarge,
        ),
      ),
    );
  }
}

/// Ligne « libellé — montant » du récapitulatif de vente.
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final TextStyle? style = emphasized
        ? textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)
        : textTheme.bodyMedium;
    return Row(
      children: <Widget>[
        Text(label, style: style),
        const Spacer(),
        Text(value, style: style),
      ],
    );
  }
}
