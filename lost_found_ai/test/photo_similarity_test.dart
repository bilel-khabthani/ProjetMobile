import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lost_found_ai/core/ai/photo_similarity.dart';

void main() {
  group('PhotoFingerprint', () {
    test('identical solid images score 100', () {
      final pixels = _solidRgba(72, 64, 0xFFFF0000);
      final left = PhotoFingerprint.fromRgba(pixels, 72, 64);
      final right = PhotoFingerprint.fromRgba(pixels, 72, 64);

      expect(left.compareWith(right).score, 100);
    });

    test('different colors score lower than identical ones', () {
      final red = PhotoFingerprint.fromRgba(_solidRgba(72, 64, 0xFFFF0000), 72, 64);
      final otherRed = PhotoFingerprint.fromRgba(
        _solidRgba(72, 64, 0xFFFF0000),
        72,
        64,
      );
      final blue = PhotoFingerprint.fromRgba(
        _solidRgba(72, 64, 0xFF0000FF),
        72,
        64,
      );

      final identical = red.compareWith(otherRed);
      final different = red.compareWith(blue);

      expect(identical.score, 100);
      expect(different.score, lessThan(identical.score));
    });

    test('ignores fully transparent pixels in the histogram', () {
      final transparent = _solidRgba(72, 64, 0x00FF0000);
      final fingerprint = PhotoFingerprint.fromRgba(transparent, 72, 64);

      expect(fingerprint.histogram.every((value) => value == 0), isTrue);
    });
  });

  group('PhotoSimilarity', () {
    test('labels the score ranges in French', () {
      expect(
        const PhotoSimilarity(
          score: 90,
          shapeScore: 90,
          colorScore: 90,
          available: true,
        ).label,
        'Photos très proches',
      );
      expect(
        const PhotoSimilarity(
          score: 20,
          shapeScore: 20,
          colorScore: 20,
          available: true,
        ).label,
        'Photos peu ressemblantes',
      );
    });

    test('exposes an unavailable result with a readable reason', () {
      final result = PhotoSimilarity.unavailable();

      expect(result.available, isFalse);
      expect(result.message, isNotNull);
    });
  });

  group('PhotoSimilarityEngine', () {
    test('reports unavailable without urls', () async {
      final result = await PhotoSimilarityEngine().compare(
        leftUrl: null,
        rightUrl: null,
      );

      expect(result.available, isFalse);
      expect(result.message, isNotNull);
    });

    test('reports unavailable when only one url is provided', () async {
      final result = await PhotoSimilarityEngine().compare(
        leftUrl: 'http://10.0.2.2:8000/storage/items/a.jpg',
        rightUrl: null,
      );

      expect(result.available, isFalse);
    });
  });
}

Uint8List _solidRgba(int width, int height, int argb) {
  final bytes = Uint8List(width * height * 4);
  final alpha = (argb >> 24) & 0xFF;
  final red = (argb >> 16) & 0xFF;
  final green = (argb >> 8) & 0xFF;
  final blue = argb & 0xFF;

  for (var index = 0; index < bytes.length; index += 4) {
    bytes[index] = red;
    bytes[index + 1] = green;
    bytes[index + 2] = blue;
    bytes[index + 3] = alpha;
  }

  return bytes;
}
