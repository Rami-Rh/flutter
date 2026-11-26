import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers/settings_providers.dart';
import '../../../../domain/entities/app_settings.dart';
import '../../../../domain/entities/catalog.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../catalog_helpers.dart';
import 'stock_status_chip.dart';

/// Ligne de produit affichée dans la liste du catalogue.
class ProductTile extends ConsumerWidget {
  const ProductTile({
    required this.product,
    required this.onTap,
    required this.onDelete,
    this.categoryName,
    this.supplierName,
    super.key,
  });

  final Product product;
  final String? categoryName;
  final String? supplierName;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppSettings settings =
        ref.watch(settingsProvider).valueOrNull ?? AppSettings.defaults;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final List<String> details = <String>[
      product.barcode,
      if (categoryName != null && categoryName!.isNotEmpty) categoryName!,
      if (supplierName != null && supplierName!.isNotEmpty) supplierName!,
    ];

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            product.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.titleMedium,
                          ),
                        ),
                        if (!product.isActive) ...<Widget>[
                          const SizedBox(width: 8),
                          _InactiveBadge(label: l10n.productInactiveLabel),
                        ],
                        const SizedBox(width: 8),
                        StockStatusChip(status: product.stockStatus),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      details.join(' • '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        Text(
                          formatMoney(settings, product.retailPrice),
                          style: textTheme.labelLarge,
                        ),
                        const Spacer(),
                        Text(
                          '${formatQuantity(settings, product.quantityOnHand, product.packaging.baseUnit)}'
                          ' ${baseUnitLabel(l10n, product.packaging.baseUnit)}',
                          style: textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: l10n.actionDelete,
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Marqueur discret pour un produit désactivé.
class _InactiveBadge extends StatelessWidget {
  const _InactiveBadge({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outline),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: scheme.outline, fontSize: 11),
      ),
    );
  }
}
