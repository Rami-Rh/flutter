import 'package:meta/meta.dart';

/// Codes d'erreur applicatifs (jamais de texte en dur côté logique :
/// l'UI traduit via les fichiers ARB).
enum FailureCode {
  unknown,
  database,
  validation,
  notFound,
  duplicateBarcode,
  duplicateEmail,
  duplicateCategoryName,
  invalidCredentials,
  weakPassword,
  recoveryCodeInvalid,
  secretAnswerInvalid,
  recoveryLocked,
  categoryInUse,
  insufficientStock,
  encryption,
  storage,
  permissionDenied,
  printerUnavailable,
  importInvalidFormat,
}

/// Erreur métier/technique transportée à travers les couches.
@immutable
class AppFailure implements Exception {
  const AppFailure(
    this.code, {
    this.debugMessage,
    this.cause,
  });

  final FailureCode code;

  /// Message technique (logs uniquement, non affiché à l'utilisateur).
  final String? debugMessage;

  final Object? cause;

  @override
  String toString() =>
      'AppFailure(${code.name}${debugMessage == null ? '' : ': $debugMessage'})';
}
