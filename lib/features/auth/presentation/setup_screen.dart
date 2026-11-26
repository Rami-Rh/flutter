import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/l10n/failure_messages.dart';
import '../../../app/providers/auth_providers.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'auth_validators.dart';
import 'widgets/auth_feedback.dart';

/// Premier accès : création du compte unique (email, mot de passe, question
/// secrète). Le code de récupération est généré puis affiché sur l'écran
/// suivant, une seule fois.
class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirmation = TextEditingController();
  final TextEditingController _question = TextEditingController();
  final TextEditingController _answer = TextEditingController();
  final TextEditingController _hint = TextEditingController();

  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    _question.dispose();
    _answer.dispose();
    _hint.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).register(
            email: _email.text,
            password: _password.text,
            secretQuestion: _question.text.trim(),
            secretAnswer: _answer.text,
            recoveryCodeHint:
                _hint.text.trim().isEmpty ? null : _hint.text.trim(),
          );
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _error = failureMessage(l10n, error));
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.authSetupTitle)),
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
                      l10n.authSetupSubtitle,
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
                      textInputAction: TextInputAction.next,
                      decoration:
                          InputDecoration(labelText: l10n.authPasswordLabel),
                      validator: (String? value) =>
                          validatePassword(l10n, value),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _confirmation,
                      obscureText: true,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: l10n.authConfirmPasswordLabel,
                      ),
                      validator: (String? value) => validatePasswordConfirmation(
                        l10n,
                        value,
                        _password.text,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _question,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: l10n.authSecretQuestionLabel,
                      ),
                      validator: (String? value) =>
                          validateRequired(l10n, value),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _answer,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: l10n.authSecretAnswerLabel,
                      ),
                      validator: (String? value) =>
                          validateRequired(l10n, value),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _hint,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: l10n.authRecoveryHintLabel,
                      ),
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 24),
                    AuthProgressButton(
                      label: l10n.authCreateAccount,
                      loading: _submitting,
                      onPressed: _submit,
                    ),
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
