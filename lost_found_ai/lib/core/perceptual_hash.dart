import 'dart:typed_data';
import 'dart:ui' as ui;

/// Empreinte perceptuelle d'une image (difference hash, 64 bits).
///
/// Le calcul est fait sur l'appareil car le serveur ne decode pas tous les
/// formats (notamment le JPEG). L'empreinte est envoyee avec la photo et
/// utilisee par le moteur de matching pour comparer deux annonces.
class PerceptualHash {
  const PerceptualHash._();

  static const int _width = 9;
  static const int _height = 8;

  /// Retourne 64 caracteres `0`/`1`, ou null si l'image ne peut pas etre lue.
  static Future<String?> of(Uint8List bytes) async {
    ui.Codec? codec;
    ui.Image? decoded;
    ui.Image? scaled;
    ui.Picture? picture;

    try {
      codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      decoded = frame.image;

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawImageRect(
        decoded,
        ui.Rect.fromLTWH(
          0,
          0,
          decoded.width.toDouble(),
          decoded.height.toDouble(),
        ),
        ui.Rect.fromLTWH(0, 0, _width.toDouble(), _height.toDouble()),
        ui.Paint()..filterQuality = ui.FilterQuality.medium,
      );
      picture = recorder.endRecording();
      scaled = await picture.toImage(_width, _height);

      final data = await scaled.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) return null;

      final pixels = data.buffer.asUint8List();
      final bits = StringBuffer();

      for (var y = 0; y < _height; y++) {
        for (var x = 0; x < _width - 1; x++) {
          bits.write(
            _grayAt(pixels, x, y) < _grayAt(pixels, x + 1, y) ? '1' : '0',
          );
        }
      }

      final hash = bits.toString();
      return hash.length == 64 ? hash : null;
    } catch (_) {
      return null;
    } finally {
      scaled?.dispose();
      decoded?.dispose();
      picture?.dispose();
      codec?.dispose();
    }
  }

  static int _grayAt(Uint8List pixels, int x, int y) {
    final offset = (y * _width + x) * 4;
    final red = pixels[offset];
    final green = pixels[offset + 1];
    final blue = pixels[offset + 2];
    return (0.299 * red + 0.587 * green + 0.114 * blue).round();
  }
}
