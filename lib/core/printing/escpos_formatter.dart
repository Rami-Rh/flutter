import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:image/image.dart' as img;

/// Encode un ticket déjà **rasterisé** (image bitmap) en commandes ESC/POS.
///
/// L'arabe n'étant pas géré nativement par ESC/POS (pas de ligatures ni de
/// rattachement des lettres), tout le ticket est transmis sous forme d'image
/// tramée : la mise en page et le sens d'écriture (RTL) sont garantis par le
/// rendu Flutter, puis convertis en points noirs/blancs imprimables.
///
/// [paperWidthMm] choisit la largeur de rouleau (58 ou 80 mm).
Future<List<int>> buildTicketEscPos({
  required img.Image bitmap,
  required int paperWidthMm,
  int feedLines = 3,
}) async {
  final CapabilityProfile profile = await CapabilityProfile.load();
  final Generator generator = Generator(
    paperWidthMm >= 80 ? PaperSize.mm80 : PaperSize.mm58,
    profile,
  );

  return <int>[
    ...generator.reset(),
    ...generator.imageRaster(
      bitmap,
      align: PosAlign.center,
      highDensityHorizontal: false,
      highDensityVertical: false,
    ),
    ...generator.feed(feedLines),
    ...generator.cut(),
  ];
}
