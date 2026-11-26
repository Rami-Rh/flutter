import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

/// Ouvre la feuille de partage du système pour un fichier en mémoire
/// (CSV, Excel…) : enregistrement, e-mail, envoi à un tiers.
///
/// Abstrait pour que les tests n'invoquent pas le canal natif de `share_plus`.
abstract class FileShareGateway {
  /// Partage [bytes] sous le nom [fileName] et le type MIME [mimeType].
  Future<void> shareBytes(
    Uint8List bytes, {
    required String fileName,
    required String mimeType,
  });
}

/// Implémentation réelle, déléguée à `share_plus`.
class SystemFileShareGateway implements FileShareGateway {
  const SystemFileShareGateway();

  @override
  Future<void> shareBytes(
    Uint8List bytes, {
    required String fileName,
    required String mimeType,
  }) async {
    await Share.shareXFiles(
      <XFile>[
        XFile.fromData(bytes, name: fileName, mimeType: mimeType),
      ],
    );
  }
}

/// Partage de fichiers du système (surchargé dans les tests).
final Provider<FileShareGateway> fileShareGatewayProvider =
    Provider<FileShareGateway>(
  (Ref ref) => const SystemFileShareGateway(),
  name: 'fileShareGatewayProvider',
);
