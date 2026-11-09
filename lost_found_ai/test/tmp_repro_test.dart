import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_found_ai/data/api_client.dart';
import 'package:lost_found_ai/data/api_repository.dart';
import 'package:lost_found_ai/data/providers.dart';
import 'package:lost_found_ai/features/swipe/swipe_screen.dart';

/// Reproduction ciblée : le deck et l'insight renvoyés par l'API réelle.
class _FakeApiClient extends ApiClient {
  _FakeApiClient({required this.deck, required this.insight});

  final Map<String, dynamic> deck;
  final Map<String, dynamic> insight;

  @override
  Future<dynamic> get(String path) async =>
      path.contains('/insight') ? insight : deck;

  @override
  Future<dynamic> post(String path, Map<String, dynamic> body) async => {
    'status': 'ok',
  };
}

Map<String, dynamic> _deckPayload() => {
  'candidates': [
    {
      'id': '01a1c09b-448e-72ed-b97a-1b31b3dbb470',
      'status': 'PENDING',
      'created_at': '2026-11-09T13:59:23+00:00',
      'distance_km': 0.05,
      'scores': {
        'image': 50,
        'location': 100,
        'time': 100,
        'text': 78,
        'global': 96,
      },
      'lost_item': {
        'id': '01a1c09b-4408-70ca-9811-030c277c53b2',
        'type': 'LOST',
        'category': 'sac',
        'title': 'Sac Nike noir',
        'description':
            "Sac a dos Nike noir avec une poche frontale, perdu apres les cours de l'apres-midi.",
        'place_label': 'Batiment B, universite',
        'latitude': 48.857,
        'longitude': 2.3518,
        'occurred_at': '2026-11-07T10:59:23+00:00',
        'status': 'ACTIVE',
        'image_url': '/storage/items/lost.png',
        'user': {
          'id': 26,
          'name': 'Amina Benali',
          'trust_score': 72,
          'recovered_count': 0,
        },
      },
      'found_item': {
        'id': '01a1c09b-4424-71ce-b05e-1a0701ae73b9',
        'type': 'FOUND',
        'category': 'sac',
        'title': 'Sac a dos Nike noir trouve au batiment B',
        'description':
            'Sac a dos Nike noir trouve vers le batiment B, poche frontale fermee par un zip.',
        'place_label': 'Batiment B, universite',
        'latitude': 48.8566,
        'longitude': 2.3522,
        'occurred_at': '2026-11-07T13:59:23+00:00',
        'status': 'ACTIVE',
        'image_url': '/storage/items/found.png',
        'user': {
          'id': 27,
          'name': 'Karim Mansouri',
          'trust_score': 88,
          'recovered_count': 0,
        },
      },
      'ai': {
        'verdict': 'STRONG',
        'confidence': 96,
        'summary':
            'Le texte, le lieu et l’horaire convergent : cette piste mérite une vérification rapide.',
        'reasons': [
          'Détails partagés : noir, sac, poche, dos.',
          'Les deux annonces sont à moins d’un kilomètre l’une de l’autre.',
          'L’écart horaire est compatible avec la perte.',
          'Les deux annonces concernent la même catégorie d’objet.',
        ],
        'tags': ['sac', 'Très proche', 'Même créneau'],
        'icebreaker':
            'Bonjour, votre annonce « Sac a dos Nike noir trouve au batiment B » ressemble à l’objet que j’ai perdu. Pourriez-vous me confirmer un détail distinctif avant que nous convenions d’un rendez-vous ?',
        'agreement': {
          'score': 78,
          'shared': ['noir', 'sac', 'poche', 'dos', 'frontale', 'nike'],
          'contradictions': [],
        },
        'source': 'heuristic',
      },
    },
  ],
  'ai_enabled': false,
  'lost_items_count': 1,
  'message': null,
};

Map<String, dynamic> _insightPayload() => {
  'insight': {
    'verdict': 'STRONG',
    'confidence': 96,
    'summary':
        'Le texte, le lieu et l’horaire convergent : cette piste mérite une vérification rapide.',
    'reasons': [
      'Détails partagés : noir, sac, poche, dos.',
      'Les deux annonces sont à moins d’un kilomètre l’une de l’autre.',
      'L’écart horaire est compatible avec la perte.',
      'Les deux annonces concernent la même catégorie d’objet.',
    ],
    'tags': ['sac', 'Très proche', 'Même créneau'],
    'icebreaker':
        'Bonjour, votre annonce « Sac a dos Nike noir trouve au batiment B » ressemble à l’objet que j’ai perdu. Pourriez-vous me confirmer un détail distinctif avant que nous convenions d’un rendez-vous ?',
    'agreement': {
      'score': 78,
      'shared': ['noir', 'sac', 'poche', 'dos', 'frontale', 'nike'],
      'contradictions': [],
    },
    'source': 'heuristic',
  },
  'ai_enabled': false,
};

Widget _app(ApiRepository repository) => ProviderScope(
  overrides: [repositoryProvider.overrideWithValue(repository)],
  child: const MaterialApp(home: SwipeScreen()),
);

void main() {
  testWidgets('SwipeScreen renders the real deck and opens the AI insight', (
    tester,
  ) async {
    final repository = ApiRepository(
      client: _FakeApiClient(
        deck: _deckPayload(),
        insight: _insightPayload(),
      ),
    );

    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    expect(find.text('Tinder Cards'), findsOneWidget);
    expect(find.text('Sac a dos Nike noir trouve au batiment B'), findsOneWidget);

    // ignore: avoid_print
    print('ANALYSE_IA_COUNT_BEFORE=${find.text('Analyse IA').evaluate().length}');
    // ignore: avoid_print
    print('RECT=${tester.getRect(find.text('Analyse IA').last)}');
    // ignore: avoid_print
    print('SCREEN=${tester.view.physicalSize}');

    // Bouton "Analyse IA" de la barre d'action (le cercle, pas son libellé).
    await tester.tap(find.byIcon(Icons.auto_awesome_rounded).last);
    await tester.pumpAndSettle();

    // ignore: avoid_print
    print('ANALYSE_IA_COUNT_AFTER=${find.text('Analyse IA').evaluate().length}');
    // ignore: avoid_print
    print('POURQUOI=${find.text('Pourquoi cette correspondance ?').evaluate().length}');
    // ignore: avoid_print
    print('COMPARAISON=${find.text('Comparaison des photos').evaluate().length}');

    expect(find.text('Analyse IA'), findsWidgets);
    expect(
      find.textContaining('Détails partagés : noir, sac, poche, dos.'),
      findsWidgets,
    );
    expect(find.text('Comparaison des photos'), findsOneWidget);
  });

  testWidgets('SwipeScreen reports a LIKE decision and keeps working', (
    tester,
  ) async {
    final repository = ApiRepository(
      client: _FakeApiClient(
        deck: _deckPayload(),
        insight: _insightPayload(),
      ),
    );

    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.favorite_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('Deck terminé !'), findsOneWidget);
  });

  testWidgets('SwipeScreen falls back to the demo deck and opens the insight', (
    tester,
  ) async {
    final repository = ApiRepository(client: _ThrowingApiClient());

    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    expect(find.text('Sac noir à bande rouge'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.auto_awesome_rounded).last);
    await tester.pumpAndSettle();

    expect(find.text('Analyse IA'), findsWidgets);
    expect(find.text('Pourquoi cette correspondance ?'), findsOneWidget);
  });
}

class _ThrowingApiClient extends ApiClient {
  @override
  Future<dynamic> get(String path) async => throw ApiException(500, 'Server Error');
}
