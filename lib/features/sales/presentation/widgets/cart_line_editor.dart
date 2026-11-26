import 'package:flutter/material.dart';

import '../../../../core/quantity/quantity.dart';
import '../../../../domain/entities/app_settings.dart';
import '../../../../domain/entities/cart_line.dart';
import '../../../../domain/enums/enums.dart';
import '../../../../domain/units/units.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../sales_helpers.dart';

/// Résultat de l'édition d'une ligne de panier.
typedef CartLineEdit = ({PackagingUnit packagingUnit, Qty quantity});

/// Ouvre l'éditeur d'une ligne : conditionnement et quantité.
Future<CartLineEdit?> showCartLineEditor(
  BuildContext context, {
  required CartLine line,
  required AppSettings settings,
}) {
  return showDialog<CartLineEdit>(
    context: context,
    builder: (BuildContext dialogContext) =>
        _CartLineEditorDialog(line: line, settings: settings),
  );
}

class _CartLineEditorDialog extends StatefulWidget {
  const _CartLineEditorDialog({required this.line, required this.settings});

  final CartLine line;
  final AppSettings settings;

  @override
  State<_CartLineEditorDialog> createState() => _CartLineEditorDialogState();
}

class _CartLineEditorDialogState extends State<_CartLineEditorDialog> {
  late final TextEditingController _quantity;
  late PackagingUnit _unit;
  String? _error;

  @override
  void initState() {
    super.initState();
    _unit = widget.line.packagingUnit;
    _quantity = TextEditingController(
      text: _textFor(widget.line.baseQuantity, _unit),
    );
  }

  @override
  void dispose() {
    _quantity.dispose();
    super.dispose();
  }

  /// Texte de saisie correspondant à une quantité de base, dans [unit].
  String _textFor(Qty baseQuantity, PackagingUnit unit) {
    final Qty inUnit = UnitConverter.fromBaseUnit(
      baseQuantity,
      unit,
      widget.line.packaging,
    );
    final bool withDecimals = unit == PackagingUnit.base &&
        widget.line.packaging.baseUnit == StockBaseUnit.kilogram;
    return withDecimals
        ? inUnit.toDecimal().toString()
        : (inUnit.milliUnits ~/ Qty.scale).toString();
  }

  void _selectUnit(PackagingUnit unit) {
    setState(() {
      _unit = unit;
      _quantity.text = _textFor(widget.line.baseQuantity, unit);
      _error = null;
    });
  }

  void _submit() {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final Qty? parsed = parsePackagingQuantity(
      _quantity.text,
      _unit,
      widget.line.packaging.baseUnit,
    );
    if (parsed == null) {
      setState(() => _error = l10n.validationNumberInvalid);
      return;
    }
    if (!parsed.isPositive) {
      setState(() => _error = l10n.validationPositiveNumber);
      return;
    }
    Navigator.of(context).pop<CartLineEdit>(
      (packagingUnit: _unit, quantity: parsed),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<PackagingUnit> units = widget.line.packaging.availableUnits;

    return AlertDialog(
      title: Text(l10n.saleEditLineTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            widget.line.productName,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          if (units.length > 1) ...<Widget>[
            const SizedBox(height: 12),
            Text(l10n.salePackagingLabel),
            const SizedBox(height: 8),
            SegmentedButton<PackagingUnit>(
              showSelectedIcon: false,
              segments: <ButtonSegment<PackagingUnit>>[
                for (final PackagingUnit unit in units)
                  ButtonSegment<PackagingUnit>(
                    value: unit,
                    label: Text(
                      packagingUnitLabel(
                        l10n,
                        unit,
                        widget.line.packaging.baseUnit,
                      ),
                    ),
                  ),
              ],
              selected: <PackagingUnit>{_unit},
              onSelectionChanged: (Set<PackagingUnit> selection) =>
                  _selectUnit(selection.first),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _quantity,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: l10n.fieldQuantity,
              errorText: _error,
              suffixText: packagingUnitLabel(
                l10n,
                _unit,
                widget.line.packaging.baseUnit,
              ),
            ),
            onSubmitted: (String value) => _submit(),
          ),
        ],
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
