import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

/// Fichier choisi par l'utilisateur : nom et contenu chargé en mémoire.
@immutable
class PickedFile {
  const PickedFile({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

/// Sélection d'un document sur l'appareil (import CSV / Excel).
///
/// Abstrait pour que les tests n'ouvrent pas le sélecteur natif de
/// `file_picker`.
abstract class FilePickGateway {
  /// Ouvre le sélecteur filtré sur [extensions] ; `null` si l'utilisateur
  /// annule.
  Future<PickedFile?> pickDocument({required List<String> extensions});
}

/// Implémentation réelle, déléguée à `file_picker`.
class SystemFilePickGateway implements FilePickGateway {
  const SystemFilePickGateway();

  @override
  Future<PickedFile?> pickDocument({
    required List<String> extensions,
  }) async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensions,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final PlatformFile file = result.files.first;
    final Uint8List? bytes = file.bytes;
    if (bytes == null) return null;
    return PickedFile(name: file.name, bytes: bytes);
  }
}

/// Sélection de fichiers du système (surchargée dans les tests).
final Provider<FilePickGateway> filePickGatewayProvider =
    Provider<FilePickGateway>(
  (Ref ref) => const SystemFilePickGateway(),
  name: 'filePickGatewayProvider',
);
