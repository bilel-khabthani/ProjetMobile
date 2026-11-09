import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lost_found_ai/core/ai/photo_similarity.dart';

// Petite image PNG 1x1 rouge (valide).
const List<int> _pngBytes = [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0xDA, 0x63, 0xFC, 0xCF, 0xC0, 0x50,
  0x0F, 0x00, 0x04, 0x85, 0x01, 0x80, 0x84, 0xA9, 0x8C, 0x21, 0x00, 0x00,
  0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
];

void main() {
  test('PhotoSimilarityEngine decodes two real images', () async {
    final engine = PhotoSimilarityEngine(
      client: MockClient((request) async => http.Response.bytes(_pngBytes, 200)),
    );

    final result = await engine.compare(
      leftUrl: 'http://10.0.2.2:8000/storage/items/a.png',
      rightUrl: 'http://10.0.2.2:8000/storage/items/b.png',
    );

    expect(result.available, isTrue);
    expect(result.score, inInclusiveRange(0, 100));
  });

  test('PhotoSimilarityEngine survives a non-image payload', () async {
    final engine = PhotoSimilarityEngine(
      client: MockClient(
        (request) async => http.Response.bytes(Uint8List.fromList([1, 2, 3]), 200),
      ),
    );

    final result = await engine.compare(
      leftUrl: 'http://10.0.2.2:8000/storage/items/a.png',
      rightUrl: 'http://10.0.2.2:8000/storage/items/b.png',
    );

    expect(result.available, isFalse);
  });
}
