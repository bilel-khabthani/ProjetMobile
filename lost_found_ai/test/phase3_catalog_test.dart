import 'package:flutter_test/flutter_test.dart';
import 'package:lost_found_ai/data/api_client.dart';
import 'package:lost_found_ai/data/models/item.dart';
import 'package:lost_found_ai/features/objects/data/models/object_model.dart';
import 'package:lost_found_ai/features/objects/data/models/object_filter.dart';
import 'package:lost_found_ai/features/objects/presentation/screens/objects_list_screen.dart';

void main() {
  group('ObjectFilter sort', () {
    test('defaults to recent and survives copyWith', () {
      const filter = ObjectFilter();
      final sorted = filter.copyWith(sort: 'oldest');

      expect(filter.sort, 'recent');
      expect(sorted.sort, 'oldest');
      expect(filter == sorted, isFalse);
      expect(
        filter.copyWith(sort: 'title').toQueryParams()['sort'],
        'title',
      );
    });

    test('is included in the API query parameters', () {
      final params = const ObjectFilter(
        sort: 'title',
        limit: 20,
        offset: 40,
      ).toQueryParams();

      expect(params['sort'], 'title');
      expect(params['per_page'], 20);
      expect(params['page'], 3);
    });
  });

  group('catalog accessibility labels', () {
    test('combines type, title, place, distance, date and status', () {
      final object = LostFoundObject(
        id: '1',
        userId: 1,
        type: ItemType.lost,
        category: ItemCategory.bag,
        title: 'Sac noir',
        description: 'Un sac',
        status: ItemStatus.active,
        latitude: 36.1,
        longitude: 1.5,
        placeLabel: 'Bibliothèque',
        occurredAt: DateTime(2024, 1, 2),
        distanceKm: 1.25,
      );

      expect(
        buildObjectCardSemanticsLabel(object),
        'Perdu, Sac noir, Bibliothèque, 1.3 km, Le 2/1/2024, Active',
      );
    });

    test('falls back to the category label when the place is empty', () {
      final object = LostFoundObject(
        id: '2',
        userId: 2,
        type: ItemType.found,
        category: ItemCategory.keys,
        title: 'Trousseau',
        description: 'Clés',
        status: ItemStatus.matched,
        latitude: 36.2,
        longitude: 1.6,
        placeLabel: '',
        occurredAt: DateTime(2024, 3, 4),
      );

      expect(
        buildObjectCardSemanticsLabel(object),
        contains('Trouvé, Trousseau, Clés, Le 4/3/2024, Correspondance'),
      );
    });
  });

  group('catalog error messages', () {
    test('uses the ApiException validation message', () {
      expect(
        catalogFriendlyErrorMessage(
          ApiException(422, 'Validation failed', {
            'errors': {'title': ['Le titre est requis.']},
          }),
        ),
        'Le titre est requis.',
      );
    });

    test('falls back to a readable French message', () {
      expect(
        catalogFriendlyErrorMessage(Object()),
        contains('catalogue est momentanément indisponible'),
      );
    });
  });
}
