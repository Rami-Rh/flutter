import 'package:meta/meta.dart';

/// Utilisateur de l'application (compte unique, **sans secret exposé**).
///
/// Les empreintes (mot de passe, code de récupération, réponse secrète)
/// restent confinées à la couche données : le domaine et l'UI ne manipulent
/// que ces informations non sensibles.
@immutable
class AppUser {
  const AppUser({
    this.id,
    required this.email,
    this.secretQuestion,
    this.recoveryCodeHint,
    this.biometricEnabled = false,
    this.createdAt,
    this.updatedAt,
    this.lastLoginAt,
  });

  final int? id;
  final String email;

  /// Question secrète choisie à l'inscription (sert à la récupération).
  final String? secretQuestion;

  /// Indice facultatif aidant à retrouver le code de récupération.
  final String? recoveryCodeHint;

  /// Verrouillage biométrique activé (empreinte / Face ID).
  final bool biometricEnabled;

  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastLoginAt;

  AppUser copyWith({
    int? id,
    String? email,
    String? secretQuestion,
    String? recoveryCodeHint,
    bool? biometricEnabled,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastLoginAt,
  }) =>
      AppUser(
        id: id ?? this.id,
        email: email ?? this.email,
        secretQuestion: secretQuestion ?? this.secretQuestion,
        recoveryCodeHint: recoveryCodeHint ?? this.recoveryCodeHint,
        biometricEnabled: biometricEnabled ?? this.biometricEnabled,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppUser &&
          other.id == id &&
          other.email == email &&
          other.secretQuestion == secretQuestion &&
          other.recoveryCodeHint == recoveryCodeHint &&
          other.biometricEnabled == biometricEnabled &&
          other.lastLoginAt == lastLoginAt);

  @override
  int get hashCode => Object.hash(
        id,
        email,
        secretQuestion,
        recoveryCodeHint,
        biometricEnabled,
        lastLoginAt,
      );
}

/// Données saisies à la **création du compte** (premier lancement).
///
/// Regroupe le mot de passe et le dispositif de récupération hors-ligne
/// (code de récupération + question/réponse secrète).
@immutable
class UserRegistration {
  const UserRegistration({
    required this.email,
    required this.password,
    required this.recoveryCode,
    this.recoveryCodeHint,
    required this.secretQuestion,
    required this.secretAnswer,
  });

  final String email;
  final String password;
  final String recoveryCode;
  final String? recoveryCodeHint;
  final String secretQuestion;
  final String secretAnswer;
}

/// État du dispositif de secours par **question secrète** (limité en essais).
///
/// Le code de récupération reste utilisable seul et n'est pas soumis à cette
/// limite ; seule la question secrète est verrouillée après [maxAttempts]
/// échecs, pour une durée qui **double** à chaque nouvelle série.
@immutable
class RecoveryLockStatus {
  const RecoveryLockStatus({
    required this.remainingAttempts,
    required this.lockLevel,
    this.lockedUntil,
  });

  /// Nombre total d'essais autorisés par série.
  static const int maxAttempts = 5;

  /// Durée de base du premier blocage ; doublée à chaque nouveau blocage.
  static const Duration baseLockDuration = Duration(minutes: 15);

  /// Essais encore disponibles avant le prochain blocage.
  final int remainingAttempts;

  /// Nombre de blocages déjà déclenchés (facteur de doublement).
  final int lockLevel;

  /// Fin du blocage courant, ou `null` si aucun blocage actif.
  final DateTime? lockedUntil;

  /// Durée du prochain blocage pour un niveau donné.
  static Duration durationForLevel(int level) =>
      baseLockDuration * (1 << level);

  /// Vrai si le dispositif est bloqué à l'instant [now].
  bool isLockedAt(DateTime now) =>
      lockedUntil != null && lockedUntil!.isAfter(now);

  /// Temps restant avant déblocage à l'instant [now] (`Duration.zero` sinon).
  Duration remainingLockAt(DateTime now) {
    final until = lockedUntil;
    if (until == null || !until.isAfter(now)) return Duration.zero;
    return until.difference(now);
  }
}
