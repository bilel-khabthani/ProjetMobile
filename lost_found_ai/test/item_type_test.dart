import 'package:flutter_test/flutter_test.dart';
import 'package:lost_found_ai/data/models/item.dart';

void main() {
  test('ItemType.apiValue matches the API contract', () {
    expect(ItemType.lost.apiValue, 'LOST');
    expect(ItemType.found.apiValue, 'FOUND');
  });
}
