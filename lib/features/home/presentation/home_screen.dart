import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers/auth_providers.dart';
import '../../../app/router/app_router.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Écran d'accueil : confirme la session ouverte, donne accès au catalogue et
/// permet de verrouiller la session. Les autres modules métier (ventes,
/// rapports…) viendront ensuite.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String? email =
        ref.watch(authControllerProvider).valueOrNull?.user?.email;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.homeTitle),
        actions: <Widget>[
          IconButton(
            tooltip: l10n.homeLockAction,
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
            icon: const Icon(Icons.lock_outline),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              l10n.homeWelcome,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (email != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                email,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.push(AppRoutes.sales),
              icon: const Icon(Icons.point_of_sale_outlined),
              label: Text(l10n.salesOpenAction),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: () => context.push(AppRoutes.catalog),
              icon: const Icon(Icons.inventory_2_outlined),
              label: Text(l10n.catalogOpenAction),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: () => context.push(AppRoutes.reports),
              icon: const Icon(Icons.insights_outlined),
              label: Text(l10n.reportsOpenAction),
            ),
          ],
        ),
      ),
    );
  }
}
