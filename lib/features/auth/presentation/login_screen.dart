import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/l10n/failure_messages.dart';
import '../../../app/providers/auth_providers.dart';
import '../../../app/router/app_router.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'auth_validators.dart';
import 'widgets/auth_feedback.dart';

/// Connexion : email + mot de passe, et biométrie si elle est activée pour
/// le compte.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    await _run(
      () => ref.read(authControllerProvider.notifier).login(
            email: _email.text,
            password: _password.text,
          ),
    );
  }

  Future<void> _loginWithBiometrics() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    await _run(
      () => ref.read(authControllerProvider.notifier).loginWithBiometrics(
            reason: l10n.authBiometricReason,
          ),
    );
  }

  /// Exécute [action] en gérant les états « en cours » et « erreur ».
  Future<void> _run(Future<void> Function() action) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await action();
    } on Object catch (error) {
      if (mounted) {
        setState(() => _error = failureMessage(l10n, error));
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool biometricEnabled = ref
            .watch(currentUserProvider)
            .valueOrNull
            ?.biometricEnabled ??
        false;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.authLoginTitle)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      l10n.authLoginSubtitle,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 20),
                    if (_error != null) ...<Widget>[
                      AuthErrorBanner(message: _error!),
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      textInputAction: TextInputAction.next,
                      decoration:
                          InputDecoration(labelText: l10n.authEmailLabel),
                      validator: (String? value) => validateEmail(l10n, value),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _password,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      decoration:
                          InputDecoration(labelText: l10n.authPasswordLabel),
                      validator: (String? value) =>
                          validateRequired(l10n, value),
                      onFieldSubmitted: (_) => _login(),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: TextButton(
                        onPressed: _submitting
                            ? null
                            : () => context.go(AppRoutes.forgotPassword),
                        child: Text(l10n.authForgotPassword),
                      ),
                    ),
                    const SizedBox(height: 16),
                    AuthProgressButton(
                      label: l10n.authLogin,
                      loading: _submitting,
                      onPressed: _login,
                    ),
                    if (biometricEnabled) ...<Widget>[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _submitting ? null : _loginWithBiometrics,
                        icon: const Icon(Icons.fingerprint),
                        label: Text(l10n.authBiometric),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
