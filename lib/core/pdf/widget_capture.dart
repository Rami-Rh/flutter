import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

/// Résultat de la rasterisation d'un widget : PNG et dimensions en pixels.
@immutable
class WidgetCapture {
  const WidgetCapture({
    required this.png,
    required this.widthPx,
    required this.heightPx,
  });

  /// Image encodée en PNG.
  final Uint8List png;
  final int widthPx;
  final int heightPx;
}

/// Rasterise en PNG le widget enveloppé par un `RepaintBoundary` référencé par
/// [boundaryKey].
///
/// Le rendu passe par le moteur de texte de Flutter : l'arabe (ligatures, sens
/// RTL) est donc mis en forme correctement — ce que ni ESC/POS ni les polices
/// PDF par défaut ne savent faire. La même capture sert à l'impression
/// thermique, au ticket PDF et aux rapports PDF.
Future<WidgetCapture> captureWidgetBoundary(
  GlobalKey boundaryKey, {
  double pixelRatio = 1,
}) async {
  final BuildContext? context = boundaryKey.currentContext;
  final RenderObject? object = context?.findRenderObject();
  if (object is! RenderRepaintBoundary) {
    throw StateError('Le contenu doit être enveloppé dans un RepaintBoundary.');
  }
  final ui.Image image = await object.toImage(pixelRatio: pixelRatio);
  try {
    final ByteData? data =
        await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) {
      throw StateError('Encodage en PNG impossible.');
    }
    return WidgetCapture(
      png: data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      widthPx: image.width,
      heightPx: image.height,
    );
  } finally {
    image.dispose();
  }
}
