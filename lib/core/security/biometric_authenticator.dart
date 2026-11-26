import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Verrouillage biométrique local (empreinte / Face ID).
///
/// L'interface isole le plugin natif pour que la logique d'authentification
/// reste testable ; le libellé demandé à l'OS est fourni par l'UI (traduit),
/// jamais codé en dur ici.
abstract interface class BiometricAuthenticator {
  /// Vrai si l'appareil possède un capteur biométrique utilisable.
  Future<bool> isAvailable();

  /// Demande une authentification biométrique ; vrai si l'utilisateur est
  /// reconnu. [reason] est affiché par le dialogue système (texte traduit).
  Future<bool> authenticate({required String reason});
}

/// Implémentation réelle basée sur `local_auth`.
///
/// Toute erreur de plateforme est absorbée en `false` : la biométrie est une
/// commodité optionnelle, jamais un point de blocage (le mot de passe reste
/// toujours disponible).
class LocalAuthBiometricAuthenticator implements BiometricAuthenticator {
  LocalAuthBiometricAuthenticator({LocalAuthentication? authentication})
      : _authentication = authentication ?? LocalAuthentication();

  final LocalAuthentication _authentication;

  @override
  Future<bool> isAvailable() async {
    try {
      final supported = await _authentication.isDeviceSupported();
      final canCheck = await _authentication.canCheckBiometrics;
      return supported && canCheck;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<bool> authenticate({required String reason}) async {
    try {
      return await _authentication.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } on PlatformException {
      return false;
    }
  }
}
