import 'package:drift/drift.dart';

import '../../core/errors/failures.dart';
import '../../core/security/password_hasher.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/user_repository.dart';
import '../local/database.dart';
import '../local/mappers/user_mapper.dart';

/// Implémentation Drift du contrat [UserRepository].
///
/// Le compte est **unique** : la table `users` ne contient jamais plus d'une
/// ligne. Tous les secrets sont hachés via [PasswordHasher] avant d'être
/// persistés ; l'email, la réponse secrète et le code de récupération sont
/// normalisés pour rendre la vérification tolérante à la saisie.
///
/// Le recours à la **question secrète** est limité en essais
/// ([RecoveryLockStatus.maxAttempts]) : au-delà, un blocage temporaire est
/// appliqué, sa durée doublant à chaque nouvelle série d'échecs. Le **code de
/// récupération** reste utilisable seul, sans limitation.
class DriftUserRepository implements UserRepository {
  DriftUserRepository(
    this._db, {
    PasswordHasher hasher = const PasswordHasher(),
  }) : _hasher = hasher;

  final AppDatabase _db;
  final PasswordHasher _hasher;

  @override
  Stream<AppUser?> watchUser() {
    final stmt = _db.select(_db.users)..limit(1);
    return stmt.watchSingleOrNull().map((row) => row?.toEntity());
  }

  @override
  Future<AppUser?> getUser() async => (await _userRow())?.toEntity();

  @override
  Future<bool> hasUser() async => await _userRow() != null;

  @override
  Future<AppUser> register(UserRegistration registration) async {
    if (await hasUser()) {
      throw const AppFailure(
        FailureCode.duplicateEmail,
        debugMessage: 'Un compte existe déjà.',
      );
    }

    final email = _normalizeEmail(registration.email);
    final question = registration.secretQuestion.trim();
    final answer = _normalizeAnswer(registration.secretAnswer);
    final recoveryCode = RecoveryCode.normalize(registration.recoveryCode);

    if (email.isEmpty) {
      throw const AppFailure(
        FailureCode.validation,
        debugMessage: 'Email manquant.',
      );
    }
    if (!PasswordPolicy.isAcceptable(registration.password)) {
      throw const AppFailure(
        FailureCode.weakPassword,
        debugMessage: 'Mot de passe trop court.',
      );
    }
    if (question.isEmpty || answer.isEmpty || recoveryCode.isEmpty) {
      throw const AppFailure(
        FailureCode.validation,
        debugMessage: 'Dispositif de récupération incomplet.',
      );
    }

    final passwordSalt = PasswordHasher.generateSalt();
    final recoverySalt = PasswordHasher.generateSalt();
    final answerSalt = PasswordHasher.generateSalt();

    final passwordHash = await _hasher.hash(
      registration.password,
      saltBase64: passwordSalt,
    );
    final recoveryHash = await _hasher.hash(
      recoveryCode,
      saltBase64: recoverySalt,
    );
    final answerHash = await _hasher.hash(answer, saltBase64: answerSalt);

    final now = DateTime.now();
    final id = await _db.into(_db.users).insert(
          UsersCompanion.insert(
            email: email,
            passwordHash: passwordHash,
            passwordSalt: passwordSalt,
            kdfIterations: Value<int>(_hasher.iterations),
            recoveryCodeHash: recoveryHash,
            recoveryCodeSalt: recoverySalt,
            recoveryCodeHint: Value<String?>(
              _trimOrNull(registration.recoveryCodeHint),
            ),
            secretQuestion: question,
            secretAnswerHash: answerHash,
            secretAnswerSalt: answerSalt,
            createdAt: now,
            updatedAt: now,
          ),
        );
    return (await _rowById(id))!.toEntity();
  }

  @override
  Future<AppUser> authenticate({
    required String email,
    required String password,
  }) async {
    final row = await _userRow();
    if (row == null || _normalizeEmail(email) != row.email) {
      throw const AppFailure(
        FailureCode.invalidCredentials,
        debugMessage: 'Identifiants inconnus.',
      );
    }
    if (!await _verifyPassword(row, password)) {
      throw const AppFailure(
        FailureCode.invalidCredentials,
        debugMessage: 'Mot de passe incorrect.',
      );
    }
    await recordLogin();
    return (await _rowById(row.id))!.toEntity();
  }

  @override
  Future<bool> verifyRecoveryCode({
    required String email,
    required String recoveryCode,
  }) async {
    final row = await _requireRow(email);
    return _hasher.verify(
      RecoveryCode.normalize(recoveryCode),
      hashBase64: row.recoveryCodeHash,
      saltBase64: row.recoveryCodeSalt,
      iterations: row.kdfIterations,
    );
  }

  @override
  Future<bool> verifySecretAnswer({
    required String email,
    required String answer,
  }) async {
    final row = await _requireRow(email);
    final now = DateTime.now();

    if (_isLocked(row, now)) {
      throw AppFailure(
        FailureCode.recoveryLocked,
        debugMessage: 'Question secrète bloquée jusqu\'à ${row.secretAnswerLockedUntil}.',
      );
    }

    final valid = await _hasher.verify(
      _normalizeAnswer(answer),
      hashBase64: row.secretAnswerHash,
      saltBase64: row.secretAnswerSalt,
      iterations: row.kdfIterations,
    );

    if (valid) {
      await _resetLock(row);
      return true;
    }

    final failures = row.secretAnswerFailures + 1;
    if (failures >= RecoveryLockStatus.maxAttempts) {
      // Série épuisée : blocage de durée doublée par rapport au précédent.
      final duration = RecoveryLockStatus.durationForLevel(
        row.secretAnswerLockLevel,
      );
      await _writeLock(
        row.id,
        failures: 0,
        lockLevel: row.secretAnswerLockLevel + 1,
        lockedUntil: now.add(duration),
      );
      throw AppFailure(
        FailureCode.recoveryLocked,
        debugMessage: 'Trop d\'échecs : blocage de ${duration.inMinutes} min.',
      );
    }

    await _writeLock(
      row.id,
      failures: failures,
      lockLevel: row.secretAnswerLockLevel,
      lockedUntil: null,
    );
    return false;
  }

  @override
  Future<RecoveryLockStatus> recoveryStatus() async {
    final row = await _userRow();
    if (row == null) {
      return const RecoveryLockStatus(
        remainingAttempts: RecoveryLockStatus.maxAttempts,
        lockLevel: 0,
      );
    }
    final now = DateTime.now();
    final locked = _isLocked(row, now);
    return RecoveryLockStatus(
      remainingAttempts: locked
          ? 0
          : RecoveryLockStatus.maxAttempts - row.secretAnswerFailures,
      lockLevel: row.secretAnswerLockLevel,
      lockedUntil: locked ? row.secretAnswerLockedUntil : null,
    );
  }

  @override
  Future<String> regenerateRecoveryCode({required String password}) async {
    final row = await _userRow();
    if (row == null) {
      throw const AppFailure(
        FailureCode.notFound,
        debugMessage: 'Aucun compte enregistré.',
      );
    }
    if (!await _verifyPassword(row, password)) {
      throw const AppFailure(
        FailureCode.invalidCredentials,
        debugMessage: 'Mot de passe incorrect.',
      );
    }

    final code = RecoveryCode.generate();
    final salt = PasswordHasher.generateSalt();
    final hash = await _hasher.hash(
      RecoveryCode.normalize(code),
      saltBase64: salt,
    );
    await (_db.update(_db.users)..where((t) => t.id.equals(row.id))).write(
      UsersCompanion(
        recoveryCodeHash: Value<String>(hash),
        recoveryCodeSalt: Value<String>(salt),
        secretAnswerFailures: const Value<int>(0),
        secretAnswerLockLevel: const Value<int>(0),
        secretAnswerLockedUntil: const Value<DateTime?>(null),
        updatedAt: Value<DateTime>(DateTime.now()),
      ),
    );
    return code;
  }

  @override
  Future<void> resetPassword({
    required String email,
    required String newPassword,
  }) async {
    final row = await _requireRow(email);
    if (!PasswordPolicy.isAcceptable(newPassword)) {
      throw const AppFailure(
        FailureCode.weakPassword,
        debugMessage: 'Mot de passe trop court.',
      );
    }
    final salt = PasswordHasher.generateSalt();
    final hash = await _hasher.hash(newPassword, saltBase64: salt);
    await (_db.update(_db.users)..where((t) => t.id.equals(row.id))).write(
      UsersCompanion(
        passwordHash: Value<String>(hash),
        passwordSalt: Value<String>(salt),
        updatedAt: Value<DateTime>(DateTime.now()),
      ),
    );
    // L'identité a été prouvée : on lève tout blocage résiduel.
    await _resetLock(await _rowById(row.id));
  }

  @override
  Future<void> setBiometricEnabled(bool enabled) async {
    final row = await _userRow();
    if (row == null) {
      throw const AppFailure(
        FailureCode.notFound,
        debugMessage: 'Aucun compte à mettre à jour.',
      );
    }
    await (_db.update(_db.users)..where((t) => t.id.equals(row.id))).write(
      UsersCompanion(
        biometricEnabled: Value<bool>(enabled),
        updatedAt: Value<DateTime>(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> recordLogin() async {
    final row = await _userRow();
    if (row == null) return;
    final now = DateTime.now();
    await (_db.update(_db.users)..where((t) => t.id.equals(row.id))).write(
      UsersCompanion(
        lastLoginAt: Value<DateTime>(now),
        updatedAt: Value<DateTime>(now),
      ),
    );
  }

  /// Ligne unique de l'utilisateur, ou `null` si le compte n'existe pas.
  Future<UserRow?> _userRow() =>
      (_db.select(_db.users)..limit(1)).getSingleOrNull();

  Future<UserRow?> _rowById(int id) =>
      (_db.select(_db.users)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Exige l'existence du compte et la correspondance de l'email.
  Future<UserRow> _requireRow(String email) async {
    final row = await _userRow();
    if (row == null) {
      throw const AppFailure(
        FailureCode.notFound,
        debugMessage: 'Aucun compte enregistré.',
      );
    }
    if (_normalizeEmail(email) != row.email) {
      throw const AppFailure(
        FailureCode.invalidCredentials,
        debugMessage: 'Email ne correspondant pas au compte.',
      );
    }
    return row;
  }

  Future<bool> _verifyPassword(UserRow row, String password) => _hasher.verify(
        password,
        hashBase64: row.passwordHash,
        saltBase64: row.passwordSalt,
        iterations: row.kdfIterations,
      );

  static bool _isLocked(UserRow row, DateTime now) {
    final until = row.secretAnswerLockedUntil;
    return until != null && until.isAfter(now);
  }

  Future<void> _writeLock(
    int id, {
    required int failures,
    required int lockLevel,
    required DateTime? lockedUntil,
  }) =>
      (_db.update(_db.users)..where((t) => t.id.equals(id))).write(
        UsersCompanion(
          secretAnswerFailures: Value<int>(failures),
          secretAnswerLockLevel: Value<int>(lockLevel),
          secretAnswerLockedUntil: Value<DateTime?>(lockedUntil),
          updatedAt: Value<DateTime>(DateTime.now()),
        ),
      );

  Future<void> _resetLock(UserRow? row) async {
    if (row == null) return;
    await _writeLock(
      row.id,
      failures: 0,
      lockLevel: 0,
      lockedUntil: null,
    );
  }

  static String _normalizeEmail(String email) => email.trim().toLowerCase();

  /// Réponse secrète : casse et espaces ignorés.
  static String _normalizeAnswer(String answer) =>
      answer.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  static String? _trimOrNull(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}
