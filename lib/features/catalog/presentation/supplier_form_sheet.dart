import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/l10n/failure_messages.dart';
import '../../../app/providers/catalog_providers.dart';
import '../../../domain/entities/catalog.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Affiche le formulaire de fournisseur (création ou modification).
Future<void> showSupplierFormSheet(
  BuildContext context, {
  Supplier? supplier,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext sheetContext) =>
        SupplierFormSheet(supplier: supplier),
  );
}

/// Formulaire de création / modification d'un fournisseur.
class SupplierFormSheet extends ConsumerStatefulWidget {
  const SupplierFormSheet({this.supplier, super.key});

  /// Fournisseur à modifier ; `null` pour une création.
  final Supplier? supplier;

  @override
  ConsumerState<SupplierFormSheet> createState() => _SupplierFormSheetState();
}

class _SupplierFormSheetState extends ConsumerState<SupplierFormSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _company;
  late final TextEditingController _phone;
  late final TextEditingController _notes;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final Supplier? supplier = widget.supplier;
    _name = TextEditingController(text: supplier?.name ?? '');
    _company = TextEditingController(text: supplier?.companyName ?? '');
    _phone = TextEditingController(text: supplier?.phone ?? '');
    _notes = TextEditingController(text: supplier?.notes ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _company.dispose();
    _phone.dispose();
    _notes.dispose();
    super.dispose();
  }

  String? _emptyToNull(TextEditingController controller) {
    final String value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  Future<void> _submit() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });

    final Supplier supplier = Supplier(
      id: widget.supplier?.id,
      name: _name.text.trim(),
      companyName: _emptyToNull(_company),
      phone: _emptyToNull(_phone),
      notes: _emptyToNull(_notes),
      createdAt: widget.supplier?.createdAt,
      updatedAt: widget.supplier?.updatedAt,
    );

    try {
      final CatalogController controller = ref.read(catalogControllerProvider);
      if (widget.supplier == null) {
        await controller.createSupplier(supplier);
      } else {
        await controller.updateSupplier(supplier);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _error = failureMessage(l10n, error);
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool isEditing = widget.supplier != null;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                isEditing ? l10n.supplierEditTitle : l10n.supplierNewTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              if (_error != null) ...<Widget>[
                Text(_error!, style: TextStyle(color: scheme.error)),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _name,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: l10n.fieldName),
                validator: (String? value) =>
                    (value == null || value.trim().isEmpty)
                        ? l10n.validationRequired
                        : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _company,
                textInputAction: TextInputAction.next,
                decoration:
                    InputDecoration(labelText: l10n.fieldCompanyName),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: l10n.fieldPhone),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _notes,
                maxLines: 2,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(labelText: l10n.fieldNotes),
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : Text(l10n.actionSave),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
