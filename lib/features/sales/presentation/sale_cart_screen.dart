import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/l10n/failure_messages.dart';
import '../../../app/providers/sale_providers.dart';
import '../../../app/providers/settings_providers.dart';
import '../../../core/money/money.dart';
import '../../../core/quantity/quantity.dart';
import '../../../domain/entities/app_settings.dart';
import '../../../domain/entities/cart_line.dart';
import '../../../domain/enums/enums.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../catalog/presentation/catalog_helpers.dart';
import '../../catalog/presentation/widgets/catalog_states.dart';
import '../../catalog/presentation/widgets/confirm_dialog.dart';
import 'widgets/cart_line_editor.dart';
import 'widgets/cart_line_tile.dart';
import 'widgets/product_picker_sheet.dart';

/// Composition d'une nouvelle vente : panier, mode de vente, remise, encaissement.
class SaleCartScreen extends ConsumerStatefulWidget {
  const SaleCartScreen({super.key});

  @override
  ConsumerState<SaleCartScreen> createState() => _SaleCartScreenState();
}

class _SaleCartScreenState extends ConsumerState<SaleCartScreen> {
  bool _submitting = false;

  CartNotifier get _cart => ref.read(cartProvider.notifier);

  Future<void> _editLine(int index, CartLine line, AppSettings settings) async {
    final CartLineEdit? edit = await showCartLineEditor(
      context,
      line: line,
      settings: settings,
    );
    if (edit == null) return;
    _cart.updateLine(
      index,
      packagingUnit: edit.packagingUnit,
      quantity: edit.quantity,
    );
  }

  Future<void> _editDiscount() async {
    final Money current = ref.read(cartProvider).discount;
    final Money? discount = await showDialog<Money>(
      context: context,
      builder: (BuildContext dialogContext) => _DiscountDialog(initial: current),
    );
    if (discount == null) return;
    _cart.setDiscount(discount);
  }

  Future<void> _clearCart() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool confirmed = await confirmAction(
      context,
      title: l10n.deleteConfirmTitle,
      message: l10n.deleteConfirmBody,
      confirmLabel: l10n.saleClearAction,
      cancelLabel: l10n.actionCancel,
    );
    if (!confirmed) return;
    _cart.clear();
  }

  Future<void> _checkout() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final CartState cart = ref.read(cartProvider);
    if (cart.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    try {
      await ref.read(saleControllerProvider).checkout(cart.toDraft());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.saleCheckoutDone)),
      );
      Navigator.of(context).pop();
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failureMessage(l10n, error))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppSettings settings =
        ref.watch(settingsProvider).valueOrNull ?? AppSettings.defaults;
    final CartState cart = ref.watch(cartProvider);
    final CartNotifier notifier = ref.read(cartProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.saleNewAction),
        actions: <Widget>[
          if (!cart.isEmpty)
            IconButton(
              tooltip: l10n.saleClearAction,
              onPressed: () {
                unawaited(_clearCart());
              },
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          unawaited(showProductPickerSheet(context));
        },
        icon: const Icon(Icons.add),
        label: Text(l10n.saleAddProductAction),
      ),
      body: cart.isEmpty
          ? CatalogEmptyView(message: l10n.saleCartEmpty)
          : Column(
              children: <Widget>[
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    itemCount: cart.lines.length,
                    itemBuilder: (BuildContext context, int index) {
                      final CartLine line = cart.lines[index];
                      final Qty? available =
                          notifier.productOf(line.productId)?.quantityOnHand;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: CartLineTile(
                          line: line,
                          settings: settings,
                          insufficientStock:
                              available != null && line.baseQuantity > available,
                          onStep: (int direction) =>
                              notifier.stepQuantity(index, direction),
                          onEdit: () {
                            unawaited(_editLine(index, line, settings));
                          },
                          onRemove: () => notifier.removeLine(index),
                        ),
                      );
                    },
                  ),
                ),
                _TotalsPanel(
                  cart: cart,
                  settings: settings,
                  submitting: _submitting,
                  onModeChanged: notifier.setMode,
                  onEditDiscount: () {
                    unawaited(_editDiscount());
                  },
                  onCheckout: () {
                    unawaited(_checkout());
                  },
                ),
              ],
            ),
    );
  }
}

/// Bandeau récapitulatif : mode de vente, remise, total et encaissement.
class _TotalsPanel extends StatelessWidget {
  const _TotalsPanel({
    required this.cart,
    required this.settings,
    required this.submitting,
    required this.onModeChanged,
    required this.onEditDiscount,
    required this.onCheckout,
  });

  final CartState cart;
  final AppSettings settings;
  final bool submitting;
  final ValueChanged<SaleMode> onModeChanged;
  final VoidCallback onEditDiscount;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final CartTotals totals = cart.totals;

    return Material(
      elevation: 3,
      color: scheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SegmentedButton<SaleMode>(
                showSelectedIcon: false,
                segments: <ButtonSegment<SaleMode>>[
                  ButtonSegment<SaleMode>(
                    value: SaleMode.retail,
                    label: Text(
                      l10n.saleModeRetail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ButtonSegment<SaleMode>(
                    value: SaleMode.wholesale,
                    label: Text(
                      l10n.saleModeWholesale,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                selected: <SaleMode>{cart.mode},
                onSelectionChanged: (Set<SaleMode> selection) =>
                    onModeChanged(selection.first),
              ),
              const SizedBox(height: 12),
              _AmountRow(
                label: l10n.reportSubtotal,
                value: formatMoney(settings, totals.subtotal),
              ),
              _AmountRow(
                label: l10n.reportDiscount,
                value: formatMoney(settings, totals.discount),
                trailing: IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: l10n.actionEdit,
                  onPressed: onEditDiscount,
                  icon: const Icon(Icons.edit_outlined),
                ),
              ),
              const Divider(height: 16),
              _AmountRow(
                label: l10n.reportTotal,
                value: formatMoney(settings, totals.total),
                emphasized: true,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: submitting ? null : onCheckout,
                icon: submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : const Icon(Icons.check),
                label: Text(l10n.saleCheckoutAction),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ligne « libellé — montant » du récapitulatif.
class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.value,
    this.trailing,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final Widget? trailing;
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
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Saisie de la remise appliquée au panier (vide = aucune remise).
class _DiscountDialog extends StatefulWidget {
  const _DiscountDialog({required this.initial});

  final Money initial;

  @override
  State<_DiscountDialog> createState() => _DiscountDialogState();
}

class _DiscountDialogState extends State<_DiscountDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initial.isZero ? '' : widget.initial.toDecimal().toString(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String text = _controller.text.trim();
    if (text.isEmpty) {
      Navigator.of(context).pop(Money.zero);
      return;
    }
    final Money? discount = parseMoney(text);
    if (discount == null) {
      setState(() => _error = l10n.validationNumberInvalid);
      return;
    }
    Navigator.of(context).pop(discount);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.reportDiscount),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: l10n.reportDiscount,
          errorText: _error,
        ),
        onSubmitted: (String value) => _submit(),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(l10n.actionConfirm),
        ),
      ],
    );
  }
}
