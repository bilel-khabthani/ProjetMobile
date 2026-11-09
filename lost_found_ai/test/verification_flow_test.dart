import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_found_ai/core/ai/text_agreement_engine.dart';
import 'package:lost_found_ai/core/app_config.dart';
import 'package:lost_found_ai/core/app_strings.dart';
import 'package:lost_found_ai/data/api_client.dart';
import 'package:lost_found_ai/data/api_repository.dart';
import 'package:lost_found_ai/data/models/item.dart';
import 'package:lost_found_ai/data/models/item_match.dart';
import 'package:lost_found_ai/data/models/swipe_candidate.dart';
import 'package:lost_found_ai/data/providers.dart';
import 'package:lost_found_ai/features/match/verification_sheet.dart';

void main() {
  group('VerificationOutcome', () {
    test('parses the API payload and clamps the score', () {
      final outcome = VerificationOutcome.fromJson({
        'score': 140,
        'decision': 'YES',
        'matched': ['bande', 'rouge', '  '],
        'contradictions': ['noir ↔ blanc'],
        'neutral': false,
      });

      expect(outcome.score, 100);
      expect(outcome.decision, VerificationDecision.yes);
      expect(outcome.accepted, isTrue);
      expect(outcome.matched, ['bande', 'rouge']);
      expect(outcome.contradictions, ['noir ↔ blanc']);
    });

    test('defaults to a refused answer when fields are missing', () {
      final outcome = VerificationOutcome.fromJson(null);

      expect(outcome.score, 0);
      expect(outcome.decision, VerificationDecision.no);
      expect(outcome.neutral, isFalse);
    });

    test('maps the decision codes', () {
      expect(VerificationDecision.fromCode('OUI'), VerificationDecision.yes);
      expect(
        VerificationDecision.fromCode('UNSURE'),
        VerificationDecision.unsure,
      );
      expect(VerificationDecision.fromCode(null), VerificationDecision.no);
    });
  });

  group('ApiRepository', () {
    test('parses photos, agreement and verification from the match payload', () async {
      final repository = ApiRepository(client: _FakeApiClient(_matchPayload()));
      final match = await repository.fetchMatch('match-1');

      expect(match.id, 'match-1');
      expect(match.status, 'VERIFIED');
      expect(match.isVerified, isTrue);
      expect(match.verificationAttempts, 2);
      expect(
        match.myItemImageUrl,
        '${AppConfig.serverBaseUrl}/storage/items/lost.jpg',
      );
      expect(
        match.foundItemImageUrl,
        '${AppConfig.serverBaseUrl}/storage/items/found.jpg',
      );
      expect(match.agreement?.score, 82);
      expect(match.agreement?.shared, contains('bande'));
      expect(
        match.verificationOutcome?.decision,
        VerificationDecision.yes,
      );
      expect(match.verificationOutcome?.matched, contains('bande'));
    });

    test('sends the free-text answer and parses the outcome', () async {
      Map<String, dynamic>? sent;
      final repository = ApiRepository(
        client: _CapturingApiClient(
          {
            'verification': {
              'score': 95,
              'decision': 'YES',
              'matched': ['bande'],
              'contradictions': [],
              'neutral': false,
            },
          },
          (body) => sent = body,
        ),
      );

      final outcome = await repository.verifyAnswer(
        matchId: 'match-1',
        answer: '  bande rouge  ',
      );

      expect(sent?['answer_text'], 'bande rouge');
      expect(outcome.accepted, isTrue);
      expect(outcome.score, 95);
    });

    test('SwipeCandidate parses the item photos', () {
      final candidate = SwipeCandidate.fromJson({
        'id': 'match-1',
        'lost_item': {
          'title': 'Sac Nike noir',
          'image_url': '/storage/items/lost.jpg',
        },
        'found_item': {
          'title': 'Sac noir à bande rouge',
          'image_url': '/storage/items/found.jpg',
        },
        'ai': {'verdict': 'STRONG', 'confidence': 90},
      });

      expect(
        candidate.lostImageUrl,
        '${AppConfig.serverBaseUrl}/storage/items/lost.jpg',
      );
      expect(
        candidate.foundImageUrl,
        '${AppConfig.serverBaseUrl}/storage/items/found.jpg',
      );
    });
  });

  group('VerificationSheet', () {
    testWidgets('accepts a free-text answer and shows the success state', (
      tester,
    ) async {
      final repository = ApiRepository(
        client: _FakeApiClient({
          'verification': {
            'score': 96,
            'decision': 'YES',
            'matched': ['bande', 'rouge'],
            'contradictions': [],
            'neutral': false,
          },
        }),
      );

      await tester.pumpWidget(_sheetApp(repository));

      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();

      expect(find.text('Quelle est la couleur de la bande ?'), findsOneWidget);
      expect(find.text('Ce que le moteur a compris'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'La bande est rouge.');
      await tester.ensureVisible(find.text(AppStrings.verify));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.verify));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.answerCorrect), findsOneWidget);
      expect(find.text('bande'), findsWidgets);
    });

    testWidgets('shows the contradictions when the answer is refused', (
      tester,
    ) async {
      final repository = ApiRepository(
        client: _FakeApiClient({
          'verification': {
            'score': 18,
            'decision': 'NO',
            'matched': [],
            'contradictions': ['noir ↔ blanc'],
            'neutral': false,
          },
        }),
      );

      await tester.pumpWidget(_sheetApp(repository));

      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Il est blanc.');
      await tester.ensureVisible(find.text(AppStrings.verify));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.verify));
      await tester.pumpAndSettle();

      expect(find.text('Réponse refusée'), findsOneWidget);
      expect(find.text('noir ↔ blanc'), findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);
    });

    testWidgets('keeps the question visible when the answer is empty', (
      tester,
    ) async {
      final repository = ApiRepository(client: _FakeApiClient({}));

      await tester.pumpWidget(_sheetApp(repository));

      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text(AppStrings.verify));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.verify));
      await tester.pump();

      expect(find.text('Écrivez votre réponse avant de valider.'), findsOneWidget);
      expect(find.text('Quelle est la couleur de la bande ?'), findsOneWidget);
    });
  });
}

Widget _sheetApp(ApiRepository repository) {
  return ProviderScope(
    overrides: [repositoryProvider.overrideWithValue(repository)],
    child: MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showVerificationSheet(context, _match),
              child: const Text('Ouvrir'),
            ),
          ),
        ),
      ),
    ),
  );
}

final _match = ItemMatch(
  id: 'match-1',
  myItemTitle: 'Sac Nike noir',
  myItemPlace: 'Vestiaire A',
  myItemTimeLabel: '09 novembre 2026 a 09:00',
  myItemCategory: ItemCategory.bag,
  foundItemTitle: 'Sac noir à bande rouge',
  foundItemPlace: 'Cafétéria',
  foundItemTimeLabel: '09 novembre 2026 a 11:05',
  foundItemCategory: ItemCategory.bag,
  finderName: 'Karim Mansouri',
  finderInitials: 'KM',
  finderReputation: 92,
  finderRecoveredCount: 12,
  scores: const MatchScores(
    image: 50,
    location: 94,
    time: 96,
    text: 91,
    global: 91,
  ),
  verificationQuestion: 'Quelle est la couleur de la bande ?',
  minutesAgo: 30,
  status: 'PENDING',
  agreement: const TextAgreement(
    score: 82,
    shared: ['bande', 'rouge'],
    contradictions: [],
  ),
);

Map<String, dynamic> _matchPayload() {
  return {
    'id': 'match-1',
    'status': 'VERIFIED',
    'verification_attempts': 2,
    'created_at': '2026-11-09T10:00:00Z',
    'decision': {
      'engine': 'YES',
      'agreement': {
        'score': 82,
        'shared': ['bande', 'rouge'],
        'contradictions': ['noir ↔ blanc'],
      },
      'verification': {
        'score': 90,
        'decision': 'YES',
        'matched': ['bande'],
        'contradictions': [],
        'neutral': false,
      },
    },
    'lost_item': {
      'title': 'Sac Nike noir',
      'place_label': 'Vestiaire A',
      'category': 'sac',
      'occurred_at': '2026-11-09T09:00:00Z',
      'image_url': '/storage/items/lost.jpg',
    },
    'found_item': {
      'title': 'Sac noir à bande rouge',
      'place_label': 'Cafétéria',
      'category': 'sac',
      'occurred_at': '2026-11-09T11:05:00Z',
      'image_url': '/storage/items/found.jpg',
      'user': {
        'name': 'Karim Mansouri',
        'trust_score': 92,
        'recovered_count': 12,
      },
    },
    'scores': {
      'dimensions': {
        'photo': 50,
        'location': 94,
        'time': 96,
        'description': 91,
      },
      'global': 91,
    },
  };
}

class _FakeApiClient extends ApiClient {
  _FakeApiClient(this.payload);

  final Map<String, dynamic> payload;

  @override
  Future<dynamic> get(String path) async => payload;

  @override
  Future<dynamic> post(String path, Map<String, dynamic> body) async => payload;
}

class _CapturingApiClient extends ApiClient {
  _CapturingApiClient(this.payload, this.onPost);

  final Map<String, dynamic> payload;
  final void Function(Map<String, dynamic> body) onPost;

  @override
  Future<dynamic> post(String path, Map<String, dynamic> body) async {
    onPost(body);
    return payload;
  }
}
