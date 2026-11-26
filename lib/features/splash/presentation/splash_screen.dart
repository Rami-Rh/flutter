import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';

/// Écran d'attente affiché le temps de déterminer l'état de la session
/// (compte existant ou configuration du premier accès).
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(l10n.authLoading),
          ],
        ),
      ),
    );
  }
}
