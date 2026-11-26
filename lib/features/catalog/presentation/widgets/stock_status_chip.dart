import 'package:flutter/material.dart';

import '../../../../domain/enums/enums.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../catalog_helpers.dart';

/// Pastille colorée indiquant l'état de stock d'un produit.
class StockStatusChip extends StatelessWidget {
  const StockStatusChip({required this.status, super.key});

  final StockStatus status;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final (Color background, Color foreground) = switch (status) {
      StockStatus.inStock => (
          scheme.secondaryContainer,
          scheme.onSecondaryContainer,
        ),
      StockStatus.low => (
          scheme.tertiaryContainer,
          scheme.onTertiaryContainer,
        ),
      StockStatus.outOfStock => (scheme.errorContainer, scheme.onErrorContainer),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        stockStatusLabel(l10n, status),
        style: TextStyle(
          color: foreground,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
