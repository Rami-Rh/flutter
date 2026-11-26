import '../entities/user.dart';

/// Contrat d'accès au compte utilisateur (unique) et à l'authentification.
///
/// Toutes les opérations sont **hors-ligne** : vérification du mot de passe,
/// du code de récupération et de la réponse secrète se fait localement sur
/// les empreintes stockées.
abstract interface class UserRepository {
  /// Flux de l'utilisateur : émet `null` tant qu'aucun compte n'existe.
  Stream<AppUser?> watchUser();

  /// Utilisateur courant, ou `null` si aucun compte n'a encore été créé.
  Future<AppUser?> getUser();

  /// Vrai si un compte a déjà été créé (sinon : écran de configuration).
  Future<bool> hasUser();

  /// Crée le compte unique. Lève `duplicateEmail` si un compte existe déjà,
  /// `weakPassword` si le mot de passe est trop court, `validation` si un
  /// champ de récupération est vide.
  Future<AppUser> register(UserRegistration registration);

  /// Vérifie les identifiants et met à jour la date de dernière connexion.
  ///
  /// Lève `invalidCredentials` en cas d'email ou de mot de passe incorrect.
  Future<AppUser> authenticate({
    required String email,
    required String password,
  });

  /// Vrai si [recoveryCode] correspond à celui enregistré (saisie normalisée).
  Future<bool> verifyRecoveryCode({
    required String email,
    required String recoveryCode,
  });

  /// Vrai si [answer] correspond à la réponse secrète (casse/espaces ignorés).
  ///
  /// La question secrète est limitée en essais : lève `recoveryLocked` si le
  /// dispositif est bloqué (ou vient de se bloquer). Un échec décrémente les
  /// essais restants ; une réussite remet le compteur à zéro.
  Future<bool> verifySecretAnswer({
    required String email,
    required String answer,
  });

  /// État courant du dispositif de secours par question secrète
  /// (essais restants, niveau de blocage, fin de blocage éventuelle).
  Future<RecoveryLockStatus> recoveryStatus();

  /// Régénère le code de récupération après vérification du mot de passe
  /// courant. Retourne le **nouveau code en clair** (affiché une seule fois) ;
  /// lève `invalidCredentials` si le mot de passe est incorrect.
  Future<String> regenerateRecoveryCode({required String password});

  /// Remplace le mot de passe (après vérification du dispositif de secours).
  ///
  /// Une réussite remet à zéro le verrouillage de la question secrète.
  Future<void> resetPassword({
    required String email,
    required String newPassword,
  });

  /// Active / désactive le verrouillage biométrique.
  Future<void> setBiometricEnabled(bool enabled);

  /// Mémorise l'instant de la dernière connexion réussie.
  Future<void> recordLogin();
}
