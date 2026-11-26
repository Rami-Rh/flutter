import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/l10n/failure_messages.dart';
import '../../../app/providers/catalog_providers.dart';
import '../../../domain/entities/catalog.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'supplier_form_sheet.dart';
import 'widgets/catalog_states.dart';
import 'widgets/confirm_dialog.dart';

/// Onglet « Fournisseurs » : liste et CRUD.
class SuppliersView extends ConsumerWidget {
  const SuppliersView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<List<Supplier>> suppliers = ref.watch(suppliersProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showSupplierFormSheet(context),
        icon: const Icon(Icons.add),
        label: Text(l10n.actionAdd),
      ),
      body: suppliers.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stackTrace) =>
            CatalogErrorView(message: failureMessage(l10n, error)),
        data: (List<Supplier> items) {
          if (items.isEmpty) {
            return CatalogEmptyView(message: l10n.catalogEmptySuppliers);
          }
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 96),
            itemCount: items.length,
            separatorBuilder: (BuildContext context, int index) =>
                const Divider(height: 1),
            itemBuilder: (BuildContext context, int index) {
              final Supplier supplier = items[index];
              final String? phone = supplier.phone?.trim();
              return ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.local_shipping_outlined),
                ),
                title: Text(supplier.displayName),
                subtitle: Text(
                  <String>[
                    supplier.name,
                    if (phone != null && phone.isNotEmpty) phone,
                  ].join(' • '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (phone != null && phone.isNotEmpty)
                      IconButton(
                        tooltip: l10n.supplierCall,
                        onPressed: () => _call(phone),
                        icon: const Icon(Icons.phone_outlined),
                      ),
                    IconButton(
                      tooltip: l10n.actionDelete,
                      onPressed: () => _delete(context, ref, supplier),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
                onTap: () => showSupplierFormSheet(context, supplier: supplier),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _call(String phone) async {
    try {
      await launchUrl(
        Uri(scheme: 'tel', path: phone),
        mode: LaunchMode.externalApplication,
      );
    } on Object catch (_) {
      // Aucune application téléphone disponible : action ignorée.
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Supplier supplier,
  ) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool confirmed = await confirmAction(
      context,
      title: l10n.deleteConfirmTitle,
      message: l10n.supplierDeleteConfirm,
      confirmLabel: l10n.actionDelete,
      cancelLabel: l10n.actionCancel,
    );
    if (!confirmed) return;

    try {
      await ref.read(catalogControllerProvider).deleteSupplier(supplier.id!);
    } on Object catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failureMessage(l10n, error))),
      );
    }
  }
}
