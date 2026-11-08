import 'dart:math';

import 'models/item.dart';
import 'models/item_match.dart';
import 'models/reward.dart';

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

  // --- Module 4 Mock Methods ---

  Future<List<Reward>> fetchRewards() async {
    await _delay(_fast);
    return [
      const Reward(
        id: 1,
        title: 'Livraison Offerte Glovo',
        partnerName: 'Glovo Express',
        partnerType: 'DELIVERY',
        description: 'Livraison 100% gratuite sur vos repas et courses.',
        pointsCost: 200,
        discountText: 'Livraison 100% Offerte',
        iconName: 'delivery_dining',
        colorHex: '#FFC244',
        terms: 'Valable sans minimum d\'achat.',
      ),
      const Reward(
        id: 2,
        title: 'Bon Livraison Yassir Express',
        partnerName: 'Yassir Express',
        partnerType: 'DELIVERY',
        description: 'Course ou livraison offerte dans le Grand Tunis.',
        pointsCost: 250,
        discountText: 'Livraison Offerte',
        iconName: 'local_shipping',
        colorHex: '#00A859',
        terms: 'Valable jusqu\'à 10 DT.',
      ),
      const Reward(
        id: 3,
        title: 'Menu Sandwich / Burger -30%',
        partnerName: 'Campus Resto',
        partnerType: 'RESTAURANT',
        description: '30% de remise sur le menu étudiant.',
        pointsCost: 150,
        discountText: '-30% sur votre repas',
        iconName: 'restaurant',
        colorHex: '#E11D48',
        terms: 'Valable au restaurant universitaire.',
      ),
      const Reward(
        id: 4,
        title: 'Pause Café Offerte',
        partnerName: 'Cafétéria Centrale',
        partnerType: 'CAFE',
        description: 'Un café + un croissant offerts.',
        pointsCost: 100,
        discountText: 'Café + Croissant Offert',
        iconName: 'coffee',
        colorHex: '#8B5CF6',
        terms: 'Valable du lundi au samedi.',
      ),
    ];
  }

  Future<List<UserCoupon>> fetchMyCoupons() async {
    await _delay(_fast);
    return [
      UserCoupon(
        id: 'mock-coupon-1',
        title: 'Livraison Offerte Glovo — Restitution',
        partnerName: 'Glovo Express',
        partnerType: 'DELIVERY',
        code: 'GLOVO-CAMPUS-771',
        discountText: 'Livraison 100% Gratuite',
        status: CouponStatus.active,
        source: 'RESTITUTION',
        expiresAt: DateTime.now().add(const Duration(days: 28)),
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        terms: 'Valable sur l\'app Glovo.',
      ),
    ];
  }

  Future<RewardWallet> fetchRewardWallet() async {
    await _delay(_fast);
    return RewardWallet(
      points: 150,
      canSpinFreeToday: true,
      spinCost: 15,
      history: [
        RewardTransaction(
          id: 'tx-1',
          type: 'WELCOME_BONUS',
          points: 150,
          description: 'Bonus citoyen de bienvenue',
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
      ],
    );
  }

  Future<String> sendCouponEmail(String couponId, {String? targetEmail}) async {
    await _delay(_fast);
    return 'Le bon a été envoyé avec succès à ${targetEmail ?? "votre adresse e-mail"} avec le PDF joint.';
  }

  Future<UserCoupon> markCouponUsed(String couponId) async {
    await _delay(_fast);
    return UserCoupon(
      id: couponId,
      title: 'Coupon Utilisé',
      partnerName: 'Partenaire',
      partnerType: 'SHOPPING',
      code: 'USED-1234',
      discountText: 'Utilisé',
      status: CouponStatus.used,
      source: 'MOCK',
      expiresAt: DateTime.now().add(const Duration(days: 30)),
      createdAt: DateTime.now(),
    );
  }

  Future<SpinResult> spinWheel() async {
    await _delay(_medium);
    return const SpinResult(
      prizeIndex: 1,
      prize: WheelPrize(
        index: 1,
        label: '+20 Points',
        type: 'POINTS',
        colorHex: '#3B82F6',
        icon: 'star',
        points: 20,
      ),
      message: 'Bravo ! Vous avez gagné 20 points sur la Roue de la Chance !',
      newBalance: 170,
    );
  }
}
