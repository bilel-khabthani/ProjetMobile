import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_found_ai/data/demo_swipe_deck.dart';
import 'package:lost_found_ai/data/models/item.dart';
import 'package:lost_found_ai/data/models/swipe_candidate.dart';
import 'package:lost_found_ai/features/swipe/widgets/swipe_deck.dart';

void main() {
  group('SwipeCandidate.fromJson', () {
    test('parses the API contract without losing the AI preview', () {
      final candidate = SwipeCandidate.fromJson({
        'id': 'match-42',
        'status': 'PENDING',
        'distance_km': 0.45,
        'scores': {
          'image': 80,
          'location': 91,
          'time': 87,
          'text': 76,
          'global': 84,
        },
        'lost_item': {
          'title': 'Sac Nike noir',
          'description': 'Sac avec une bande rouge.',
          'category': 'sac',
          'place_label': 'Vestiaire A',
        },
        'found_item': {
          'title': 'Sac noir à bande rouge',
          'description': 'Trouvé près du vestiaire.',
          'category': 'sac',
          'place_label': 'Cafétéria',
          'occurred_at': '2026-11-05T11:05:00Z',
          'user': {
            'name': 'Karim Mansouri',
            'trust_score': 92,
            'recovered_count': 12,
          },
        },
        'ai': {
          'verdict': 'STRONG',
          'confidence': 94,
          'summary': 'Les indices convergent.',
          'reasons': ['Même catégorie', 'Bande rouge'],
          'tags': ['Sac', 'Très proche'],
          'icebreaker': 'Bonjour Karim, ce sac est-il le mien ?',
          'source': 'openai',
        },
      });

      expect(candidate.matchId, 'match-42');
      expect(candidate.lostCategory, ItemCategory.bag);
      expect(candidate.foundCategory, ItemCategory.bag);
      expect(candidate.finderName, 'Karim Mansouri');
      expect(candidate.finderInitials, 'KM');
      expect(candidate.scores.global, 84);
      expect(candidate.ai.verdict, AiVerdict.strong);
      expect(candidate.ai.confidence, 94);
      expect(candidate.ai.isLiveAi, isTrue);
      expect(candidate.distanceLabel, 'à 450 m');
    });

    test('falls back to safe defaults when fields are missing', () {
      final candidate = SwipeCandidate.fromJson(const {});

      expect(candidate.matchId, '');
      expect(candidate.lostTitle, 'Votre objet');
      expect(candidate.foundTitle, 'Objet trouvé');
      expect(candidate.ai.verdict, AiVerdict.weak);
      expect(candidate.ai.confidence, 0);
      expect(candidate.ai.reasons, isEmpty);
      expect(candidate.distanceKm, isNull);
    });
  });

  group('AiInsight.fromJson', () {
    test('clamps confidence into the 0-100 range', () {
      expect(AiInsight.fromJson({'confidence': 140}).confidence, 100);
      expect(AiInsight.fromJson({'confidence': -20}).confidence, 0);
    });

    test('drops empty reasons and tags', () {
      final insight = AiInsight.fromJson({
        'reasons': ['Lieu proche', '  ', 42],
        'tags': ['', 'Sac'],
      });

      expect(insight.reasons, ['Lieu proche', '42']);
      expect(insight.tags, ['Sac']);
      expect(insight.source, 'heuristic');
    });
  });

  group('SwipeDeck', () {
    testWidgets('reports a LIKE decision once the fly-out animation ends', (
      tester,
    ) async {
      final controller = SwipeDeckController();
      SwipeCandidate? decidedCandidate;
      SwipeDirection? decidedDirection;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                height: 640,
                child: SwipeDeck(
                  controller: controller,
                  candidates: [demoSwipeDeck.first],
                  onDecide: (candidate, direction) {
                    decidedCandidate = candidate;
                    decidedDirection = direction;
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      controller.swipe(SwipeDirection.like);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(decidedCandidate?.matchId, demoSwipeDeck.first.matchId);
      expect(decidedDirection, SwipeDirection.like);
    });
  });

  test('demo deck exposes candidates that parse like the API payload', () {
    expect(demoSwipeDeck, isNotEmpty);
    for (final candidate in demoSwipeDeck) {
      expect(candidate.matchId, isNotEmpty);
      expect(candidate.foundTitle, isNotEmpty);
      expect(candidate.ai.verdict, isNotNull);
      expect(candidate.ai.confidence, inInclusiveRange(0, 100));
    }
  });
}
