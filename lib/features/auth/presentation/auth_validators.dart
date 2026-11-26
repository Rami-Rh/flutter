import '../../../core/security/password_hasher.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Règles de validation communes aux formulaires d'authentification.
///
/// Chaque fonction renvoie `null` si la valeur est valide, sinon le message
/// localisé à afficher sous le champ.

final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

String? validateRequired(AppLocalizations l10n, String? value) =>
    (value == null || value.trim().isEmpty) ? l10n.validationRequired : null;

String? validateEmail(AppLocalizations l10n, String? value) {
  final String text = value?.trim() ?? '';
  if (text.isEmpty) return l10n.validationRequired;
  return _emailPattern.hasMatch(text) ? null : l10n.validationEmailInvalid;
}

String? validatePassword(AppLocalizations l10n, String? value) {
  final String text = value ?? '';
  if (text.isEmpty) return l10n.validationRequired;
  return PasswordPolicy.isAcceptable(text) ? null : l10n.errorWeakPassword;
}

String? validatePasswordConfirmation(
  AppLocalizations l10n,
  String? value,
  String expected,
) =>
    value == expected ? null : l10n.validationPasswordsMismatch;
