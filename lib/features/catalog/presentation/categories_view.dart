import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/l10n/failure_messages.dart';
import '../../../app/providers/catalog_providers.dart';
import '../../../domain/entities/catalog.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'catalog_helpers.dart';
import 'category_form_sheet.dart';
import 'widgets/catalog_states.dart';
import 'widgets/confirm_dialog.dart';

/// Onglet « Catégories » : liste et CRUD.
class CategoriesView extends ConsumerWidget {
  const CategoriesView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<List<Category>> categories = ref.watch(categoriesProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showCategoryFormSheet(context),
        icon: const Icon(Icons.add),
        label: Text(l10n.actionAdd),
      ),
      body: categories.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stackTrace) =>
            CatalogErrorView(message: failureMessage(l10n, error)),
        data: (List<Category> items) {
          if (items.isEmpty) {
            return CatalogEmptyView(message: l10n.catalogEmptyCategories);
          }
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 96),
            itemCount: items.length,
            separatorBuilder: (BuildContext context, int index) =>
                const Divider(height: 1),
            itemBuilder: (BuildContext context, int index) {
              final Category category = items[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: colorFromHex(
                    category.colorHex,
                    Theme.of(context).colorScheme.primaryContainer,
                  ),
                ),
                title: Text(category.name),
                trailing: IconButton(
                  tooltip: l10n.actionDelete,
                  onPressed: () => _delete(context, ref, category),
                  icon: const Icon(Icons.delete_outline),
                ),
                onTap: () =>
                    showCategoryFormSheet(context, category: category),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Category category,
  ) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool confirmed = await confirmAction(
      context,
      title: l10n.deleteConfirmTitle,
      message: l10n.categoryDeleteConfirm,
      confirmLabel: l10n.actionDelete,
      cancelLabel: l10n.actionCancel,
    );
    if (!confirmed) return;

    try {
      await ref.read(catalogControllerProvider).deleteCategory(category.id!);
    } on Object catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failureMessage(l10n, error))),
      );
    }
  }
}
