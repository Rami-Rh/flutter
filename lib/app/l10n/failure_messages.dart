import '../../core/errors/failures.dart';
import '../../l10n/generated/app_localizations.dart';

/// Traduit une erreur ([AppFailure] ou inconnue) en message localisé.
///
/// C'est le seul endroit où les [FailureCode] sont associés à des chaînes :
/// la logique ne renvoie jamais de texte affichable.
String failureMessage(AppLocalizations l10n, Object? error) {
  final FailureCode code =
      error is AppFailure ? error.code : FailureCode.unknown;
  return switch (code) {
    FailureCode.unknown => l10n.errorUnknown,
    FailureCode.database => l10n.errorDatabase,
    FailureCode.validation => l10n.errorValidation,
    FailureCode.notFound => l10n.errorNotFound,
    FailureCode.duplicateBarcode => l10n.errorDuplicateBarcode,
    FailureCode.duplicateEmail => l10n.errorDuplicateEmail,
    FailureCode.duplicateCategoryName => l10n.errorDuplicateCategoryName,
    FailureCode.invalidCredentials => l10n.errorInvalidCredentials,
    FailureCode.weakPassword => l10n.errorWeakPassword,
    FailureCode.recoveryCodeInvalid => l10n.errorRecoveryCodeInvalid,
    FailureCode.secretAnswerInvalid => l10n.errorSecretAnswerInvalid,
    FailureCode.recoveryLocked => l10n.errorRecoveryLocked,
    FailureCode.categoryInUse => l10n.errorCategoryInUse,
    FailureCode.insufficientStock => l10n.errorInsufficientStock,
    FailureCode.encryption => l10n.errorEncryption,
    FailureCode.storage => l10n.errorStorage,
    FailureCode.permissionDenied => l10n.errorPermissionDenied,
    FailureCode.printerUnavailable => l10n.errorPrinterUnavailable,
    FailureCode.importInvalidFormat => l10n.errorImportInvalidFormat,
  };
}
