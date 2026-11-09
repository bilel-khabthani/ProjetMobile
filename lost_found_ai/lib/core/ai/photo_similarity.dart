import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:http/http.dart' as http;

/// Empreinte visuelle legere d'une photo.
///
/// Elle combine deux signatures complementaires calculees sur l'appareil :
///
///  - `bits` : un dHash de 64 bits (comparaison des luminosites voisines), tres
///    robuste aux changements d'echelle et de compression ;
///  - `histogram` : un histogramme de couleurs 4x4x4 normalise, qui distingue
///    deux objets de forme proche mais de couleur differente.
///
/// Aucune bibliotheque native ni modele de 50 Mo n'est necessaire : tout tient
/// dans quelques centaines d'octets par photo.
class PhotoFingerprint {
  const PhotoFingerprint({required this.bits, required this.histogram});

  /// 64 bits de luminance (1 = pixel de gauche plus clair que son voisin).
  final List<int> bits;

  /// 64 cases RGB normalisees (somme = 1).
  final List<double> histogram;

  /// Construit une empreinte a partir de pixels RGBA bruts.
  factory PhotoFingerprint.fromRgba(Uint8List rgba, int width, int height) {
    final histogram = List<double>.filled(64, 0);
    var counted = 0;

    for (var index = 0; index + 3 < rgba.length; index += 4) {
      // Les pixels transparents ne portent aucune information de couleur.
      if (rgba[index + 3] < 8) continue;

      final red = rgba[index];
      final green = rgba[index + 1];
      final blue = rgba[index + 2];
      final bucket =
          ((red * 4) >> 8) * 16 + ((green * 4) >> 8) * 4 + ((blue * 4) >> 8);

      histogram[bucket] += 1;
      counted++;
    }

    if (counted > 0) {
      for (var index = 0; index < histogram.length; index++) {
        histogram[index] /= counted;
      }
    }

    // Grille 9x8 de luminosite : 8 comparaisons horizontales par ligne, soit 64 bits.
    const columns = 9;
    const rows = 8;
    final luminance = List<double>.filled(columns * rows, 0);
    final samples = List<int>.filled(columns * rows, 0);

    for (var y = 0; y < height; y++) {
      final cellY = (y * rows) ~/ height;
      for (var x = 0; x < width; x++) {
        final cellX = (x * columns) ~/ width;
        final pixel = (y * width + x) * 4;
        final value =
            0.299 * rgba[pixel] +
            0.587 * rgba[pixel + 1] +
            0.114 * rgba[pixel + 2];
        final cell = cellY * columns + cellX;
        luminance[cell] += value;
        samples[cell] += 1;
      }
    }

    for (var index = 0; index < luminance.length; index++) {
      if (samples[index] > 0) {
        luminance[index] /= samples[index];
      }
    }

    final bits = <int>[];
    for (var row = 0; row < rows; row++) {
      for (var column = 0; column < columns - 1; column++) {
        final left = luminance[row * columns + column];
        final right = luminance[row * columns + column + 1];
        bits.add(left > right ? 1 : 0);
      }
    }

    return PhotoFingerprint(bits: bits, histogram: histogram);
  }

  /// Compare deux empreintes et renvoie un score 0-100.
  PhotoSimilarity compareWith(PhotoFingerprint other) {
    final length = bits.length < other.bits.length
        ? bits.length
        : other.bits.length;
    var difference = 0;
    for (var index = 0; index < length; index++) {
      if (bits[index] != other.bits[index]) difference++;
    }

    final hashScore = length == 0
        ? 0
        : ((length - difference) / length * 100).round();

    var intersection = 0.0;
    for (var index = 0; index < histogram.length; index++) {
      final left = histogram[index];
      final right = other.histogram[index];
      intersection += left < right ? left : right;
    }
    final colorScore = (intersection * 100).round().clamp(0, 100);

    // La forme pese un peu plus que la couleur : deux photos du meme objet
    // peuvent avoir des eclairages tres differents.
    final score = (0.62 * hashScore + 0.38 * colorScore).round().clamp(0, 100);

    return PhotoSimilarity(
      score: score,
      shapeScore: hashScore,
      colorScore: colorScore,
      available: true,
    );
  }
}

/// Resultat de la comparaison de deux photos d'objets.
class PhotoSimilarity {
  const PhotoSimilarity({
    required this.score,
    required this.shapeScore,
    required this.colorScore,
    this.available = false,
    this.message,
  });

  /// Score global 0-100.
  final int score;

  /// Proximite de la forme / composition (dHash).
  final int shapeScore;

  /// Proximite des couleurs (histogramme).
  final int colorScore;

  /// `false` quand les photos n'ont pas pu etre lues (CORS, reseau, format).
  final bool available;

  /// Raison lisible a afficher quand la comparaison est indisponible.
  final String? message;

  factory PhotoSimilarity.unavailable([String? reason]) => PhotoSimilarity(
    score: 0,
    shapeScore: 0,
    colorScore: 0,
    available: false,
    message: reason ?? 'Photos non comparables depuis cet appareil.',
  );

  String get label => switch (score) {
    >= 78 => 'Photos très proches',
    >= 55 => 'Photos probablement similaires',
    >= 35 => 'Photos différentes mais cohérentes',
    _ => 'Photos peu ressemblantes',
  };
}

/// Compare deux photos d'objets entierement sur l'appareil.
class PhotoSimilarityEngine {
  PhotoSimilarityEngine({http.Client? client}) : _client = client;

  final http.Client? _client;

  /// Largeur/hauteur de decodage : multiple de la grille 9x8 pour un
  /// echantillonnage regulier et un cout memoire negligeable.
  static const int _decodeWidth = 72;
  static const int _decodeHeight = 64;

  /// Compare deux URL de photos. Ne leve jamais : renvoie une comparaison
  /// marquee indisponible si une photo ne peut pas etre lue.
  Future<PhotoSimilarity> compare({
    required String? leftUrl,
    required String? rightUrl,
  }) async {
    if (leftUrl == null ||
        leftUrl.trim().isEmpty ||
        rightUrl == null ||
        rightUrl.trim().isEmpty) {
      return PhotoSimilarity.unavailable('Aucune photo à comparer.');
    }

    try {
      final fingerprints = await Future.wait([
        _fingerprint(leftUrl.trim()),
        _fingerprint(rightUrl.trim()),
      ]);
      return fingerprints[0].compareWith(fingerprints[1]);
    } catch (_) {
      // CORS web, image supprimee, format inconnu... le text reste exploitable.
      return PhotoSimilarity.unavailable(
        'Photos non accessibles depuis cet appareil.',
      );
    }
  }

  Future<PhotoFingerprint> _fingerprint(String url) async {
    final bytes = await _load(url);
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: _decodeWidth,
      targetHeight: _decodeHeight,
    );

    try {
      final frame = await codec.getNextFrame();
      final image = frame.image;
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        if (data == null) {
          throw StateError('Pixels indisponibles');
        }
        return PhotoFingerprint.fromRgba(
          data.buffer.asUint8List(),
          image.width,
          image.height,
        );
      } finally {
        image.dispose();
      }
    } finally {
      codec.dispose();
    }
  }

  Future<Uint8List> _load(String url) async {
    if (url.startsWith('data:')) {
      final comma = url.indexOf(',');
      if (comma < 0) throw const FormatException('Data URI invalide');
      return base64Decode(url.substring(comma + 1));
    }

    final client = _client ?? http.Client();
    try {
      final response = await client
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 6));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('HTTP ${response.statusCode}');
      }
      return response.bodyBytes;
    } finally {
      if (_client == null) {
        client.close();
      }
    }
  }
}
