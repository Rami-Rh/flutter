import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/l10n/failure_messages.dart';
import '../../../app/providers/catalog_providers.dart';
import '../../../domain/entities/catalog.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'catalog_helpers.dart';

/// Affiche le formulaire de catégorie (création ou modification).
Future<void> showCategoryFormSheet(
  BuildContext context, {
  Category? category,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext sheetContext) =>
        CategoryFormSheet(category: category),
  );
}

/// Formulaire de création / modification d'une catégorie.
class CategoryFormSheet extends ConsumerStatefulWidget {
  const CategoryFormSheet({this.category, super.key});

  /// Catégorie à modifier ; `null` pour une création.
  final Category? category;

  @override
  ConsumerState<CategoryFormSheet> createState() => _CategoryFormSheetState();
}

class _CategoryFormSheetState extends ConsumerState<CategoryFormSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  String? _colorHex;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.category?.name ?? '');
    _colorHex = widget.category?.colorHex ?? categoryPalette.first;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
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

    final Category category = Category(
      id: widget.category?.id,
      name: _name.text.trim(),
      colorHex: _colorHex,
      createdAt: widget.category?.createdAt,
      updatedAt: widget.category?.updatedAt,
    );

    try {
      final CatalogController controller = ref.read(catalogControllerProvider);
      if (widget.category == null) {
        await controller.createCategory(category);
      } else {
        await controller.updateCategory(category);
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
    final bool isEditing = widget.category != null;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              isEditing ? l10n.categoryEditTitle : l10n.categoryNewTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            if (_error != null) ...<Widget>[
              Text(_error!, style: TextStyle(color: scheme.error)),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: _name,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(labelText: l10n.fieldName),
              validator: (String? value) =>
                  (value == null || value.trim().isEmpty)
                      ? l10n.validationRequired
                      : null,
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),
            Text(l10n.fieldColor, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                for (final String hex in categoryPalette)
                  _ColorSwatch(
                    hex: hex,
                    selected: _colorHex == hex,
                    onTap: () => setState(() => _colorHex = hex),
                  ),
              ],
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
    );
  }
}

/// Pastille de couleur sélectionnable.
class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.hex,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String hex;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        height: 44,
        width: 44,
        decoration: BoxDecoration(
          color: colorFromHex(hex, scheme.primary),
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? scheme.onSurface : Colors.transparent,
            width: 3,
          ),
        ),
        child: selected
            ? const Icon(Icons.check, color: Colors.white, size: 20)
            : null,
      ),
    );
  }
}
