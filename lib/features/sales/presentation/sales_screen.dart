import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/l10n/failure_messages.dart';
import '../../../app/providers/sale_providers.dart';
import '../../../app/router/app_router.dart';
import '../../../domain/entities/sale.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../catalog/presentation/widgets/catalog_states.dart';
import 'widgets/sale_tile.dart';

/// Liste des ventes du jour, avec accès à une nouvelle vente.
class SalesScreen extends ConsumerWidget {
  const SalesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<List<Sale>> sales = ref.watch(todaySalesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.salesTodayTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.saleNew),
        icon: const Icon(Icons.point_of_sale_outlined),
        label: Text(l10n.saleNewAction),
      ),
      body: sales.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stackTrace) =>
            CatalogErrorView(message: failureMessage(l10n, error)),
        data: (List<Sale> items) {
          if (items.isEmpty) {
            return CatalogEmptyView(message: l10n.saleEmptyToday);
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
            itemCount: items.length,
            itemBuilder: (BuildContext context, int index) {
              final Sale sale = items[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SaleTile(
                  sale: sale,
                  onTap: () => context.push(AppRoutes.saleDetailPath(sale.id!)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
