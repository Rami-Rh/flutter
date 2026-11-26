import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/auth_providers.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'widgets/auth_feedback.dart';

/// Affichage **unique** du code de récupération généré à la création du compte.
///
/// L'utilisateur doit cocher qu'il l'a sauvegardé pour entrer dans
/// l'application (la session s'ouvre alors).
class RecoveryCodeScreen extends ConsumerStatefulWidget {
  const RecoveryCodeScreen({super.key});

  @override
  ConsumerState<RecoveryCodeScreen> createState() => _RecoveryCodeScreenState();
}

class _RecoveryCodeScreenState extends ConsumerState<RecoveryCodeScreen> {
  bool _saved = false;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String? code =
        ref.watch(authControllerProvider).valueOrNull?.pendingRecoveryCode;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.authRecoveryCodeTitle)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: code == null
                  ? AuthErrorBanner(message: l10n.errorUnknown)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Text(
                          l10n.authRecoveryCodeIntro,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 24),
                        _RecoveryCodeBox(code: code),
                        const SizedBox(height: 24),
                        CheckboxListTile(
                          value: _saved,
                          onChanged: (bool? value) =>
                              setState(() => _saved = value ?? false),
                          title: Text(l10n.authRecoveryCodeSavedLabel),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                        ),
                        const SizedBox(height: 16),
                        AuthProgressButton(
                          label: l10n.authContinue,
                          onPressed: _saved
                              ? () => ref
                                  .read(authControllerProvider.notifier)
                                  .confirmRecoveryCodeSaved()
                              : null,
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Cadre mettant en évidence le code (sélectionnable pour le copier).
class _RecoveryCodeBox extends StatelessWidget {
  const _RecoveryCodeBox({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: SelectableText(
        code,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
        ),
      ),
    );
  }
}
