import 'package:flutter/material.dart';

/// État vide réutilisable (liste sans contenu ou recherche sans résultat).
class CatalogEmptyView extends StatelessWidget {
  const CatalogEmptyView({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: scheme.outline, fontSize: 16),
        ),
      ),
    );
  }
}

/// État d'erreur réutilisable (message déjà localisé par l'appelant).
class CatalogErrorView extends StatelessWidget {
  const CatalogErrorView({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.error_outline, color: scheme.error, size: 40),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
