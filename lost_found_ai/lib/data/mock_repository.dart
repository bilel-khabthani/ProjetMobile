import 'dart:math';

import 'models/item.dart';
import 'models/item_match.dart';

class MockRepository {
  MockRepository();

  static const Duration _fast = Duration(milliseconds: 420);
  static const Duration _medium = Duration(milliseconds: 780);
  static const Duration _slow = Duration(milliseconds: 1500);

  final Map<String, ItemMatch> _matches = {};

  Future<AppUser> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    await _delay(_medium);
    return _buildUser(name, email);
  }

  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    await _delay(_medium);
    return _buildUser('Yasmine Benali', email);
  }

  Future<AppUser> signInWithGoogle({
    String? email,
    String? name,
    String? avatar,
  }) async {
    await _delay(_medium);
    return _buildUser(
      name ?? 'Amina Campus (Google)',
      email ?? 'amina.google@campus.fr',
    );
  }

  Future<List<ItemMatch>> fetchMatches() async {
    await _delay(_fast);
    return _seedMatches();
  }

  Future<ItemMatch> fetchMatch(String id) async {
    await _delay(_fast);
    return _matches[id] ?? _seedMatches().first;
  }

  Future<bool> verifyAnswer({
    required String matchId,
    required String answer,
  }) async {
    await _delay(_medium);
    final normalized = _normalize(answer);
    if (normalized.isEmpty) return false;
    final current = _matches[matchId];
    if (current == null) return false;
    final accepted = matchId == 'match-sac' ? 'bleue' : 'noir';
    return _normalize(accepted).contains(normalized) ||
        normalized.contains(_normalize(accepted));
  }

  Future<void> publishItem({
    required ItemType type,
    required ItemCategory category,
    required String description,
    required String place,
    required DateTime occurredAt,
  }) async {
    await _delay(_slow);
  }

  AppUser _buildUser(String name, String email) {
    final cleaned = name.trim();
    final initials = cleaned.isEmpty
        ? 'LF'
        : cleaned
              .split(RegExp(r'\s+'))
              .where((part) => part.isNotEmpty)
              .take(2)
              .map((part) => part[0].toUpperCase())
              .join();
    return AppUser(
      name: cleaned.isEmpty ? 'Yasmine Benali' : cleaned,
      email: email.trim(),
      initials: initials,
      reputation: 4.8,
      recoveredCount: 3,
    );
  }

  List<ItemMatch> _seedMatches() {
    final base = <ItemMatch>[
      ItemMatch(
        id: 'match-sac',
        myItemTitle: 'Sac Nike noir',
        myItemPlace: 'Bloc A',
        myItemTimeLabel: 'Hier, 10h30',
        myItemCategory: ItemCategory.bag,
        foundItemTitle: 'Sac noir à bande rouge',
        foundItemPlace: 'Cafétéria centrale',
        foundItemTimeLabel: 'Hier, 11h05',
        foundItemCategory: ItemCategory.bag,
        finderName: 'Karim Mansouri',
        finderInitials: 'KM',
        finderReputation: 4.9,
        finderRecoveredCount: 12,
        scores: const MatchScores(
          image: 87,
          location: 94,
          time: 96,
          text: 91,
          global: 91,
        ),
        verificationQuestion:
            'Quelle est la couleur de la petite poche intérieure du sac ?',
        minutesAgo: 2,
      ),
      ItemMatch(
        id: 'match-cles',
        myItemTitle: 'Trousseau de clés',
        myItemPlace: 'Bibliothèque',
        myItemTimeLabel: 'Lundi, 14h',
        myItemCategory: ItemCategory.keys,
        foundItemTitle: 'Trousseau avec étiquette verte',
        foundItemPlace: 'Hall de la bibliothèque',
        foundItemTimeLabel: 'Lundi, 15h20',
        foundItemCategory: ItemCategory.keys,
        finderName: 'Lina Moreau',
        finderInitials: 'LM',
        finderReputation: 4.6,
        finderRecoveredCount: 5,
        scores: const MatchScores(
          image: 68,
          location: 71,
          time: 82,
          text: 75,
          global: 74,
        ),
        verificationQuestion:
            'De quelle couleur est le porte-clés de votre trousseau ?',
        minutesAgo: 26,
      ),
      ItemMatch(
        id: 'match-telephone',
        myItemTitle: 'Téléphone à coque bleue',
        myItemPlace: 'Amphithéâtre B',
        myItemTimeLabel: 'Mardi, 9h',
        myItemCategory: ItemCategory.phone,
        foundItemTitle: 'Téléphone trouvé sur une table',
        foundItemPlace: 'Bibliothèque',
        foundItemTimeLabel: 'Mardi, 18h',
        foundItemCategory: ItemCategory.phone,
        finderName: 'Samuel Roux',
        finderInitials: 'SR',
        finderReputation: 4.3,
        finderRecoveredCount: 2,
        scores: const MatchScores(
          image: 70,
          location: 35,
          time: 48,
          text: 85,
          global: 62,
        ),
        verificationQuestion: 'Quel motif est dessiné sur votre coque ?',
        minutesAgo: 95,
      ),
    ];
    for (final match in base) {
      _matches.putIfAbsent(match.id, () => match);
    }
    final list = base.reversed.toList();
    return list;
  }

  static String _normalize(String value) {
    final cleaned = value
        .toLowerCase()
        .replaceAll(RegExp(r'[àâä]'), 'a')
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[îï]'), 'i')
        .replaceAll(RegExp(r'[ôö]'), 'o')
        .replaceAll(RegExp(r'[ûü]'), 'u')
        .replaceAll(RegExp(r'[ç]'), 'c')
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
        .trim();
    return cleaned;
  }

  static Future<void> _delay(Duration duration) {
    final jitter = Random().nextInt(180);
    return Future<void>.delayed(duration + Duration(milliseconds: jitter));
  }
}
