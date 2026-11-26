import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:meta/meta.dart';

import '../constants/app_constants.dart';

/// Comparaison de deux suites d'octets à **temps constant**.
///
/// Évite qu'un attaquant déduise une information du temps de comparaison.
bool constantTimeEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var difference = 0;
  for (var i = 0; i < a.length; i++) {
    difference |= a[i] ^ b[i];
  }
  return difference == 0;
}

/// Règles de robustesse des mots de passe (partagées UI / logique).
abstract final class PasswordPolicy {
  /// Longueur minimale exigée.
  static const int minLength = 6;

  /// Vrai si [password] respecte la politique minimale.
  static bool isAcceptable(String password) => password.length >= minLength;
}

/// Hachage et vérification des secrets, **100 % hors-ligne**.
///
/// Algorithme : **PBKDF2-HMAC-SHA256** avec un sel aléatoire par secret et un
/// grand nombre d'itérations (durcissement contre les attaques par force brute).
/// Aucun secret n'est jamais stocké en clair ni transmis sur le réseau.
@immutable
class PasswordHasher {
  const PasswordHasher({this.iterations = defaultIterations});

  /// Itérations par défaut (alignées sur `users_table.dart`).
  static const int defaultIterations = 210000;

  /// Nom de l'algorithme persisté avec l'utilisateur.
  static const String algorithmName = 'pbkdf2-hmac-sha256';

  /// Longueur du sel (octets) avant encodage Base64.
  static const int saltLengthBytes = 16;

  /// Longueur de l'empreinte (octets) avant encodage Base64.
  static const int keyLengthBytes = 32;

  /// Nombre d'itérations appliqué à chaque dérivation.
  final int iterations;

  /// Génère un sel aléatoire cryptographiquement sûr, encodé en Base64.
  static String generateSalt({Random? random}) {
    final rng = random ?? Random.secure();
    final bytes = Uint8List(saltLengthBytes);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = rng.nextInt(256);
    }
    return base64Encode(bytes);
  }

  /// Calcule l'empreinte Base64 de [secret] pour [saltBase64].
  Future<String> hash(
    String secret, {
    required String saltBase64,
    int? iterations,
  }) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations ?? this.iterations,
      bits: keyLengthBytes * 8,
    );
    final key = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(secret)),
      nonce: base64Decode(saltBase64),
    );
    return base64Encode(await key.extractBytes());
  }

  /// Vrai si [secret] correspond à l'empreinte [hashBase64].
  Future<bool> verify(
    String secret, {
    required String hashBase64,
    required String saltBase64,
    int? iterations,
  }) async {
    final candidate = await hash(
      secret,
      saltBase64: saltBase64,
      iterations: iterations,
    );
    return constantTimeEquals(base64Decode(candidate), base64Decode(hashBase64));
  }
}

/// Génération et normalisation du **code de récupération hors-ligne**.
///
/// Le code est affiché une seule fois à l'utilisateur lors de l'inscription ;
/// seule son empreinte est conservée. La normalisation garantit qu'une saisie
/// avec ou sans tirets / minuscules reste valide.
abstract final class RecoveryCode {
  /// Alphabet sans caractères ambigus (`I`, `O`, `0`, `1`).
  static const String alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  /// Taille d'un groupe de lecture (ex. `A1B2-C3D4`).
  static const int groupSize = 4;

  /// Génère un code aléatoire lisible, groupé par [groupSize].
  static String generate({
    int length = AppConstants.recoveryCodeLength,
    Random? random,
  }) {
    final rng = random ?? Random.secure();
    final buffer = StringBuffer();
    for (var i = 0; i < length; i++) {
      if (i > 0 && i % groupSize == 0) buffer.write('-');
      buffer.write(alphabet[rng.nextInt(alphabet.length)]);
    }
    return buffer.toString();
  }

  /// Retire les séparateurs et met en majuscules (`a1b2-c3d4` → `A1B2C3D4`).
  static String normalize(String code) =>
      code.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');
}
