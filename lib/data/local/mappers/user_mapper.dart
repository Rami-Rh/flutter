import '../../../domain/entities/user.dart';
import '../database.dart';

/// `users` → [AppUser]
///
/// Les colonnes sensibles (empreintes, sels, algorithme KDF) ne sont
/// **jamais** exposées au domaine.
extension UserRowMapper on UserRow {
  AppUser toEntity() => AppUser(
        id: id,
        email: email,
        secretQuestion: secretQuestion,
        recoveryCodeHint: recoveryCodeHint,
        biometricEnabled: biometricEnabled,
        createdAt: createdAt,
        updatedAt: updatedAt,
        lastLoginAt: lastLoginAt,
      );
}
