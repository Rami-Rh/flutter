import 'package:flutter/material.dart';

import '../../../../domain/entities/app_settings.dart';
import '../../../../domain/entities/cart_line.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../catalog/presentation/catalog_helpers.dart';
import '../sales_helpers.dart';

/// Ligne de panier : conditionnement, quantité, total et actions rapides.
///
/// Un appui sur la carte ouvre l'éditeur de ligne ; les boutons `+` / `−`
/// ajustent la quantité et l'icône corbeille retire la ligne.
class CartLineTile extends StatelessWidget {
  const CartLineTile({
    required this.line,
    required this.settings,
    required this.onStep,
    required this.onEdit,
    required this.onRemove,
    this.insufficientStock = false,
    super.key,
  });

  final CartLine line;
  final AppSettings settings;

  /// Vrai si la quantité demandée dépasse le stock disponible.
  final bool insufficientStock;

  /// Ajuste la quantité : `-1` pour décrémenter, `1` pour incrémenter.
  final ValueChanged<int> onStep;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      line.productName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${formatPackagingQuantity(settings, line)} '
                      '${packagingUnitLabel(l10n, line.packagingUnit, line.packaging.baseUnit)}',
                      style: textTheme.bodyMedium,
                    ),
                    if (insufficientStock) ...<Widget>[
                      const SizedBox(height: 4),
                      Row(
                        children: <Widget>[
                          Icon(Icons.warning_amber, size: 14, color: scheme.error),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              l10n.saleStockWarning,
                              style: textTheme.bodySmall
                                  ?.copyWith(color: scheme.error),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    formatMoney(settings, line.lineTotal),
                    style: textTheme.labelLarge,
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => onStep(-1),
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => onStep(1),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                tooltip: l10n.actionDelete,
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
