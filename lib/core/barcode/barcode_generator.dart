import 'dart:math';

/// Format de code-barres géré par l'application.
enum BarcodeFormat {
  /// Code standard 13 chiffres (produits emballés du commerce).
  ean13,

  /// Code alphanumérique (étiquettes internes, produits en vrac).
  code128,
}

/// Génération et validation de codes-barres.
///
/// - Si le produit possède déjà un code-barres sur son emballage, il est
///   scanné et enregistré tel quel (la validation garantit son intégrité).
/// - Sinon, un code **unique** est généré automatiquement
///   (EAN-13 à préfixe interne `20x`, réservé à la distribution restreinte,
///   ou Code128 pour les produits en vrac).
abstract final class BarcodeValidator {
  /// Vrai si [code] est un EAN-13 valide (13 chiffres + clé de contrôle correcte).
  static bool isValidEan13(String code) {
    if (code.length != 13) return false;
    if (!RegExp(r'^\d{13}$').hasMatch(code)) return false;
    return ean13CheckDigit(code.substring(0, 12)) == code[12];
  }

  /// Vrai si [code] est un Code128 exploitable (ASCII imprimable, non vide).
  static bool isValidCode128(String code) {
    if (code.isEmpty || code.length > 48) return false;
    return RegExp(r'^[\x20-\x7E]+$').hasMatch(code);
  }

  /// Calcule la clé de contrôle EAN-13 pour les 12 premiers chiffres.
  static String ean13CheckDigit(String first12) {
    if (!RegExp(r'^\d{12}$').hasMatch(first12)) {
      throw ArgumentError.value(first12, 'first12', '12 chiffres attendus');
    }
    var sum = 0;
    for (var i = 0; i < 12; i++) {
      final digit = int.parse(first12[i]);
      sum += i.isEven ? digit : digit * 3;
    }
    return ((10 - (sum % 10)) % 10).toString();
  }

  /// Devine le format probable d'un code scanné.
  static BarcodeFormat? detectFormat(String code) {
    if (isValidEan13(code)) return BarcodeFormat.ean13;
    if (isValidCode128(code)) return BarcodeFormat.code128;
    return null;
  }
}

/// Générateur de codes-barres uniques.
///
/// L'unicité est garantie par le paramètre [isTaken], fourni par la couche
/// données (qui interroge la base) : le générateur réessaie jusqu'à obtenir
/// un code libre, puis échoue explicitement au-delà de [maxAttempts].
class BarcodeGenerator {
  BarcodeGenerator({Random? random}) : _random = random ?? Random.secure();

  final Random _random;

  static const int maxAttempts = 100;

  /// Génère un EAN-13 unique.
  ///
  /// [prefix] doit faire 3 chiffres ; `200`–`299` sont réservés aux articles
  /// internes (norme GS1), ce qui évite tout conflit avec les codes fabricants.
  String generateEan13({
    required bool Function(String code) isTaken,
    String prefix = '200',
  }) {
    if (!RegExp(r'^\d{3}$').hasMatch(prefix)) {
      throw ArgumentError.value(prefix, 'prefix', '3 chiffres attendus');
    }
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final body = List.generate(9, (_) => _random.nextInt(10)).join();
      final first12 = '$prefix$body';
      final code = '$first12${BarcodeValidator.ean13CheckDigit(first12)}';
      if (!isTaken(code)) return code;
    }
    throw StateError(
      'Impossible de générer un EAN-13 unique après $maxAttempts essais.',
    );
  }

  /// Génère un Code128 unique (alphanumérique majuscule + chiffres).
  String generateCode128({
    required bool Function(String code) isTaken,
    int length = 12,
    String prefix = 'P',
  }) {
    const alphabet = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final body = List.generate(
        length - prefix.length,
        (_) => alphabet[_random.nextInt(alphabet.length)],
      ).join();
      final code = '$prefix$body';
      if (!isTaken(code)) return code;
    }
    throw StateError(
      'Impossible de générer un Code128 unique après $maxAttempts essais.',
    );
  }

  /// Génère un code selon le format demandé.
  String generate({
    required BarcodeFormat format,
    required bool Function(String code) isTaken,
    String eanPrefix = '200',
  }) {
    return switch (format) {
      BarcodeFormat.ean13 =>
        generateEan13(isTaken: isTaken, prefix: eanPrefix),
      BarcodeFormat.code128 => generateCode128(isTaken: isTaken),
    };
  }
}
