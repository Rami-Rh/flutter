import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

import '../../core/security/biometric_authenticator.dart';
import '../../core/security/password_hasher.dart';
import '../../data/repositories/drift_user_repository.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/user_repository.dart';
import 'database_providers.dart';

/// Hachage des secrets (PBKDF2-HMAC-SHA256).
final Provider<PasswordHasher> passwordHasherProvider =
    Provider<PasswordHasher>(
  (Ref ref) => const PasswordHasher(),
  name: 'passwordHasherProvider',
);

/// Contrat d'accès au compte utilisateur (implémenté en Drift).
final Provider<UserRepository> userRepositoryProvider =
    Provider<UserRepository>(
  (Ref ref) => DriftUserRepository(
    ref.watch(databaseProvider),
    hasher: ref.watch(passwordHasherProvider),
  ),
  name: 'userRepositoryProvider',
);

/// Vérification biométrique native (empreinte / Face ID).
final Provider<BiometricAuthenticator> biometricAuthenticatorProvider =
    Provider<BiometricAuthenticator>(
  (Ref ref) => LocalAuthBiometricAuthenticator(),
  name: 'biometricAuthenticatorProvider',
);

/// Utilisateur enregistré, ou `null` si le compte n'existe pas encore.
final FutureProvider<AppUser?> currentUserProvider = FutureProvider<AppUser?>(
  (Ref ref) => ref.watch(userRepositoryProvider).getUser(),
  name: 'currentUserProvider',
);

/// État d'authentification de l'application.
enum AuthStatus {
  /// Aucun compte : il faut configurer le premier accès.
  needsSetup,

  /// Compte créé mais code de récupération non encore confirmé : à afficher
  /// une seule fois avant d'entrer dans l'application.
  awaitingRecoveryConfirmation,

  /// Compte existant, session verrouillée (mot de passe ou biométrie).
  locked,

  /// Utilisateur authentifié : l'application est utilisable.
  authenticated,
}

/// Vue immuable de l'état d'authentification.
@immutable
class AuthState {
  const AuthState({
    required this.status,
    this.user,
    this.pendingRecoveryCode,
  });

  final AuthStatus status;
  final AppUser? user;

  /// Code de récupération venant d'être généré, à afficher **une seule fois**
  /// (état [AuthStatus.awaitingRecoveryConfirmation]).
  final String? pendingRecoveryCode;

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get needsSetup => status == AuthStatus.needsSetup;
  bool get isAwaitingRecoveryConfirmation =>
      status == AuthStatus.awaitingRecoveryConfirmation;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AuthState &&
          other.status == status &&
          other.user == user &&
          other.pendingRecoveryCode == pendingRecoveryCode);

  @override
  int get hashCode => Object.hash(status, user, pendingRecoveryCode);
}

/// Orchestre le cycle de vie de la session (logique d'authentification).
///
/// Détient l'état exposé à l'UI et délègue toute la persistance à
/// [UserRepository]. Aucune chaîne affichée n'est définie ici : les erreurs
/// remontent sous forme d'`AppFailure` traduit par la couche UI.
class AuthController extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() async {
    final repository = ref.watch(userRepositoryProvider);
    final hasUser = await repository.hasUser();
    return AuthState(
      status: hasUser ? AuthStatus.locked : AuthStatus.needsSetup,
    );
  }

  UserRepository get _repository => ref.read(userRepositoryProvider);

  /// Crée le compte : le code de récupération est **généré ici** puis exposé
  /// pour affichage unique. La session n'est ouverte qu'après confirmation.
  Future<void> register({
    required String email,
    required String password,
    required String secretQuestion,
    required String secretAnswer,
    String? recoveryCodeHint,
  }) async {
    final recoveryCode = RecoveryCode.generate();
    final user = await _repository.register(
      UserRegistration(
        email: email,
        password: password,
        recoveryCode: recoveryCode,
        recoveryCodeHint: recoveryCodeHint,
        secretQuestion: secretQuestion,
        secretAnswer: secretAnswer,
      ),
    );
    state = AsyncValue<AuthState>.data(
      AuthState(
        status: AuthStatus.awaitingRecoveryConfirmation,
        user: user,
        pendingRecoveryCode: recoveryCode,
      ),
    );
  }

  /// L'utilisateur confirme avoir sauvegardé son code : la session s'ouvre.
  void confirmRecoveryCodeSaved() {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncValue<AuthState>.data(
      AuthState(status: AuthStatus.authenticated, user: current.user),
    );
  }

  /// Connexion par email + mot de passe.
  Future<void> login({
    required String email,
    required String password,
  }) async {
    final user = await _repository.authenticate(
      email: email,
      password: password,
    );
    state = AsyncValue<AuthState>.data(
      AuthState(status: AuthStatus.authenticated, user: user),
    );
  }

  /// Connexion biométrique : n'aboutit que si l'option est activée pour le
  /// compte. [reason] est le libellé traduit affiché par le système.
  Future<void> loginWithBiometrics({required String reason}) async {
    final user = await _repository.getUser();
    if (user == null || !user.biometricEnabled) {
      state = const AsyncValue<AuthState>.data(
        AuthState(status: AuthStatus.locked),
      );
      return;
    }
    final granted = await ref
        .read(biometricAuthenticatorProvider)
        .authenticate(reason: reason);
    if (!granted) {
      state = const AsyncValue<AuthState>.data(
        AuthState(status: AuthStatus.locked),
      );
      return;
    }
    await _repository.recordLogin();
    final refreshed = await _repository.getUser();
    state = AsyncValue<AuthState>.data(
      AuthState(status: AuthStatus.authenticated, user: refreshed ?? user),
    );
  }

  /// Verrouille la session (les données restent locales).
  void logout() {
    state = const AsyncValue<AuthState>.data(
      AuthState(status: AuthStatus.locked),
    );
  }

  /// Vrai si le code de récupération fourni est correct (sans limitation).
  Future<bool> verifyRecoveryCode({
    required String email,
    required String recoveryCode,
  }) =>
      _repository.verifyRecoveryCode(email: email, recoveryCode: recoveryCode);

  /// Vrai si la réponse secrète est correcte ; lève `recoveryLocked` si le
  /// dispositif est bloqué ou vient de l'être.
  Future<bool> verifySecretAnswer({
    required String email,
    required String answer,
  }) =>
      _repository.verifySecretAnswer(email: email, answer: answer);

  /// État du verrouillage de la question secrète (essais, déblocage).
  Future<RecoveryLockStatus> recoveryStatus() => _repository.recoveryStatus();

  /// Régénère le code de récupération (mot de passe courant exigé) et le
  /// retourne en clair pour affichage unique.
  Future<String> regenerateRecoveryCode({required String password}) =>
      _repository.regenerateRecoveryCode(password: password);

  /// Remplace le mot de passe après récupération (l'UI exige au préalable la
  /// vérification du code de récupération **ou** de la réponse secrète).
  Future<void> resetPassword({
    required String email,
    required String newPassword,
  }) =>
      _repository.resetPassword(email: email, newPassword: newPassword);

  /// Active / désactive l'option biométrique du compte.
  Future<void> setBiometricEnabled(bool enabled) async {
    await _repository.setBiometricEnabled(enabled);
    final current = state.valueOrNull;
    final currentUser = current?.user;
    if (current != null && currentUser != null) {
      state = AsyncValue<AuthState>.data(
        AuthState(
          status: current.status,
          user: currentUser.copyWith(biometricEnabled: enabled),
        ),
      );
    }
    ref.invalidate(currentUserProvider);
  }
}

/// Contrôleur d'authentification exposé à l'interface.
final AsyncNotifierProvider<AuthController, AuthState> authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthState>(
  AuthController.new,
  name: 'authControllerProvider',
);
