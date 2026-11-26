import 'package:drift/drift.dart';

/// Utilisateur unique de l'application (aucun multi-compte).
///
/// Le mot de passe n'est **jamais** stocké en clair : seul le couple
/// (hash, sel) est conservé, calculé via PBKDF2-HMAC-SHA256.
/// Le code de récupération hors-ligne et la réponse à la question secrète
/// sont également hachés.
@DataClassName('UserRow')
class Users extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get email => text().withLength(min: 3, max: 200).unique()();

  /// Empreinte du mot de passe (Base64).
  TextColumn get passwordHash => text()();

  /// Sel aléatoire du mot de passe (Base64).
  TextColumn get passwordSalt => text()();

  /// Algorithme KDF utilisé (`pbkdf2-hmac-sha256`).
  TextColumn get kdfAlgorithm =>
      text().withDefault(const Constant('pbkdf2-hmac-sha256'))();

  /// Nombre d'itérations du KDF (durcissement).
  IntColumn get kdfIterations => integer().withDefault(const Constant(210000))();

  /// Empreinte du code de récupération hors-ligne (Base64).
  TextColumn get recoveryCodeHash => text()();

  /// Sel aléatoire du code de récupération (Base64).
  TextColumn get recoveryCodeSalt => text()();

  /// Indice affiché pour aider à retrouver le code de récupération.
  TextColumn get recoveryCodeHint => text().nullable()();

  /// Question secrète (texte libre saisi par l'utilisateur).
  TextColumn get secretQuestion => text()();

  /// Empreinte de la réponse à la question secrète (Base64).
  TextColumn get secretAnswerHash => text()();

  TextColumn get secretAnswerSalt => text()();

  /// Nombre d'échecs consécutifs sur la question secrète (remis à zéro dès
  /// une réussite ou un déblocage).
  IntColumn get secretAnswerFailures => integer().withDefault(const Constant(0))();

  /// Nombre de blocages déjà déclenchés : la durée double à chaque série
  /// d'échecs (15 min, 30 min, 60 min…).
  IntColumn get secretAnswerLockLevel =>
      integer().withDefault(const Constant(0))();

  /// Fin du blocage temporaire de la question secrète (`null` si non bloqué).
  DateTimeColumn get secretAnswerLockedUntil => dateTime().nullable()();

  /// Verrouillage biométrique optionnel (empreinte / Face ID).
  BoolColumn get biometricEnabled =>
      boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  DateTimeColumn get lastLoginAt => dateTime().nullable()();
}
