import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/l10n/failure_messages.dart';
import '../../../app/providers/auth_providers.dart';
import '../../../app/router/app_router.dart';
import '../../../core/errors/failures.dart';
import '../../../domain/entities/user.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'auth_validators.dart';
import 'widgets/auth_feedback.dart';

/// Méthode de vérification d'identité proposée.
enum _Method { recoveryCode, secretQuestion }

/// Étapes du parcours de récupération.
enum _Step { verify, newPassword, done }

/// Mot de passe oublié : vérification par **code de récupération** (sans
/// limite) **ou** par **question secrète** (limitée en essais avec blocage
/// temporaire), puis définition d'un nouveau mot de passe.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final GlobalKey<FormState> _verifyFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _passwordFormKey = GlobalKey<FormState>();

  final TextEditingController _code = TextEditingController();
  final TextEditingController _answer = TextEditingController();
  final TextEditingController _newPassword = TextEditingController();
  final TextEditingController _confirmation = TextEditingController();

  _Method _method = _Method.recoveryCode;
  _Step _step = _Step.verify;
  bool _submitting = false;
  String? _error;
  int? _remainingAttempts;
  DateTime? _lockedUntil;

  @override
  void dispose() {
    _code.dispose();
    _answer.dispose();
    _newPassword.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  AppUser? get _user => ref.read(currentUserProvider).valueOrNull;

  bool get _isLocked {
    final DateTime? until = _lockedUntil;
    return until != null && until.isAfter(DateTime.now());
  }

  int get _remainingMinutes {
    final DateTime? until = _lockedUntil;
    if (until == null) return 0;
    final int seconds = until.difference(DateTime.now()).inSeconds;
    return seconds <= 0 ? 0 : (seconds / 60).ceil();
  }

  void _switchMethod(_Method method) {
    setState(() {
      _method = method;
      _error = null;
    });
    if (method == _Method.secretQuestion) {
      unawaited(_refreshLockStatus());
    }
  }

  /// Recharge l'état du verrouillage de la question secrète (essais, blocage).
  Future<void> _refreshLockStatus() async {
    if (_user == null) return;
    try {
      final RecoveryLockStatus status =
          await ref.read(authControllerProvider.notifier).recoveryStatus();
      if (!mounted) return;
      setState(() {
        _remainingAttempts = status.remainingAttempts;
        _lockedUntil = status.lockedUntil;
      });
    } on Object catch (error) {
      // Une lecture en échec ne doit pas interrompre le formulaire.
      debugPrint('recoveryStatus: $error');
    }
  }

  Future<void> _verify() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    if (!(_verifyFormKey.currentState?.validate() ?? false)) {
      return;
    }
    final AppUser? user = _user;
    if (user == null) {
      setState(() => _error = l10n.errorUnknown);
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final bool valid = _method == _Method.recoveryCode
          ? await ref.read(authControllerProvider.notifier).verifyRecoveryCode(
                email: user.email,
                recoveryCode: _code.text,
              )
          : await ref.read(authControllerProvider.notifier).verifySecretAnswer(
                email: user.email,
                answer: _answer.text,
              );
      if (!mounted) return;
      if (valid) {
        setState(() => _step = _Step.newPassword);
      } else {
        setState(() {
          _error = _method == _Method.recoveryCode
              ? l10n.errorRecoveryCodeInvalid
              : l10n.errorSecretAnswerInvalid;
        });
      }
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _error = failureMessage(l10n, error));
      if (error is AppFailure && error.code == FailureCode.recoveryLocked) {
        await _refreshLockStatus();
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _resetPassword() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    if (!(_passwordFormKey.currentState?.validate() ?? false)) {
      return;
    }
    final AppUser? user = _user;
    if (user == null) {
      setState(() => _error = l10n.errorUnknown);
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).resetPassword(
            email: user.email,
            newPassword: _newPassword.text,
          );
      if (mounted) {
        setState(() => _step = _Step.done);
      }
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
    final AppUser? user = ref.watch(currentUserProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.authForgotTitle)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: switch (_step) {
                _Step.verify => _buildVerify(l10n, user),
                _Step.newPassword => _buildNewPassword(l10n),
                _Step.done => _buildDone(l10n),
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVerify(AppLocalizations l10n, AppUser? user) {
    final bool locked = _isLocked;
    final String? question = user?.secretQuestion;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          l10n.authForgotSubtitle,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 20),
        if (_error != null) ...<Widget>[
          AuthErrorBanner(message: _error!),
          const SizedBox(height: 16),
        ],
        SegmentedButton<_Method>(
          segments: <ButtonSegment<_Method>>[
            ButtonSegment<_Method>(
              value: _Method.recoveryCode,
              label: Text(l10n.authMethodRecoveryCode),
            ),
            ButtonSegment<_Method>(
              value: _Method.secretQuestion,
              label: Text(l10n.authMethodSecretQuestion),
            ),
          ],
          selected: <_Method>{_method},
          onSelectionChanged: (Set<_Method> selection) =>
              _switchMethod(selection.first),
        ),
        const SizedBox(height: 20),
        Form(
          key: _verifyFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (_method == _Method.recoveryCode)
                TextFormField(
                  controller: _code,
                  autocorrect: false,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.done,
                  decoration:
                      InputDecoration(labelText: l10n.authRecoveryCodeLabel),
                  validator: (String? value) => validateRequired(l10n, value),
                  onFieldSubmitted: (_) => _verify(),
                )
              else ...<Widget>[
                if (question != null) ...<Widget>[
                  Text(
                    question,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 14),
                ],
                TextFormField(
                  controller: _answer,
                  textInputAction: TextInputAction.done,
                  decoration:
                      InputDecoration(labelText: l10n.authSecretAnswerLabel),
                  validator: (String? value) => validateRequired(l10n, value),
                  onFieldSubmitted: (_) => _verify(),
                ),
                if (_remainingAttempts != null && !locked) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    l10n.authAttemptsRemaining(_remainingAttempts!),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ],
          ),
        ),
        if (locked) ...<Widget>[
          const SizedBox(height: 20),
          _LockedNotice(minutes: _remainingMinutes),
        ],
        const SizedBox(height: 24),
        AuthProgressButton(
          label: _method == _Method.recoveryCode
              ? l10n.authVerifyCode
              : l10n.authVerifyAnswer,
          loading: _submitting,
          onPressed: locked ? null : _verify,
        ),
      ],
    );
  }

  Widget _buildNewPassword(AppLocalizations l10n) {
    return Form(
      key: _passwordFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (_error != null) ...<Widget>[
            AuthErrorBanner(message: _error!),
            const SizedBox(height: 16),
          ],
          TextFormField(
            controller: _newPassword,
            obscureText: true,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(labelText: l10n.authNewPasswordLabel),
            validator: (String? value) => validatePassword(l10n, value),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _confirmation,
            obscureText: true,
            textInputAction: TextInputAction.done,
            decoration:
                InputDecoration(labelText: l10n.authConfirmPasswordLabel),
            validator: (String? value) => validatePasswordConfirmation(
                  l10n,
                  value,
                  _newPassword.text,
                ),
          ),
          const SizedBox(height: 24),
          AuthProgressButton(
            label: l10n.authSetPassword,
            loading: _submitting,
            onPressed: _resetPassword,
          ),
        ],
      ),
    );
  }

  Widget _buildDone(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: <Widget>[
                const Icon(Icons.check_circle_outline, size: 48),
                const SizedBox(height: 12),
                Text(
                  l10n.authPasswordResetDone,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        AuthProgressButton(
          label: l10n.authLogin,
          onPressed: () => context.go(AppRoutes.login),
        ),
      ],
    );
  }
}

/// Bandeau indiquant le blocage temporaire et le temps restant.
class _LockedNotice extends StatelessWidget {
  const _LockedNotice({required this.minutes});

  final int minutes;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.lock_clock, color: scheme.onTertiaryContainer),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.authLockedTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.authLockedMessage,
            style: TextStyle(color: scheme.onTertiaryContainer),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.authLockedRemaining(minutes),
            style: TextStyle(color: scheme.onTertiaryContainer),
          ),
        ],
      ),
    );
  }
}
