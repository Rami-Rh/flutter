import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers/settings_providers.dart';
import '../../../../domain/entities/app_settings.dart';
import '../../../../domain/entities/sale.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../catalog/presentation/catalog_helpers.dart';
import '../sales_helpers.dart';

/// Ligne d'une vente enregistrée (liste du jour ou d'une période).
class SaleTile extends ConsumerWidget {
  const SaleTile({required this.sale, required this.onTap, super.key});

  final Sale sale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppSettings settings =
        ref.watch(settingsProvider).valueOrNull ?? AppSettings.defaults;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: <Widget>[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    formatSaleTime(settings.language.code, sale.date),
                    style: textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    saleModeLabel(l10n, sale.mode),
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      formatMoney(settings, sale.total),
                      style: textTheme.titleMedium,
                    ),
                    if (sale.isCancelled) ...<Widget>[
                      const SizedBox(height: 4),
                      SaleBadge(
                        label: l10n.saleCancelledLabel,
                        background: scheme.errorContainer,
                        foreground: scheme.onErrorContainer,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pastille compacte utilisée par les listes de ventes.
class SaleBadge extends StatelessWidget {
  const SaleBadge({
    required this.label,
    required this.background,
    required this.foreground,
    super.key,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: foreground, fontSize: 11),
      ),
    );
  }
}
