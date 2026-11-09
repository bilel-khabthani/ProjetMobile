import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lost_found_ai/core/perceptual_hash.dart';

const _gradient =
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAIAAACQkWg2AAAACXBIWXMAAA7EAAAOxAGVKw4bAAAAHUlEQVQokWNkYGgQYGAgHrEwCDCQBEY1jGoYOhoAHgoCnh4ePFsAAAAASUVORK5CYII=';

const _reversedGradient =
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAIAAACQkWg2AAAACXBIWXMAAA7EAAAOxAGVKw4bAAAAHklEQVQokWP8z9DwgYGBeMTCIMBAEhjVMKph6GgAABZREL3jlg6YAAAAAElFTkSuQmCC';

Uint8List _bytes(String base64) => base64Decode(base64);

void main() {
  test('produces a stable 64-bit hash for the same image', () async {
    final first = await PerceptualHash.of(_bytes(_gradient));
    final second = await PerceptualHash.of(_bytes(_gradient));

    expect(first, isNotNull);
    expect(first, hasLength(64));
    expect(first, matches(RegExp(r'^[01]{64}$')));
    expect(first, second);
  });

  test('produces a different hash for a reversed gradient', () async {
    final original = await PerceptualHash.of(_bytes(_gradient));
    final reversed = await PerceptualHash.of(_bytes(_reversedGradient));

    expect(original, isNotNull);
    expect(reversed, isNotNull);
    expect(original, isNot(reversed));
  });

  test('returns null for bytes that are not an image', () async {
    expect(await PerceptualHash.of(Uint8List.fromList([1, 2, 3, 4])), isNull);
  });
}
