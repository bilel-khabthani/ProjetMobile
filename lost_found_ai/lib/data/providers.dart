import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_config.dart';
import 'api_repository.dart';
import 'mock_repository.dart';
import 'models/item_match.dart';
import 'models/reward.dart';
import 'models/trust.dart';
import 'models/item.dart';

/// Source de donnees active. Les deux classes exposent la meme surface, donc
/// les ecrans ne changent pas selon le mode choisi.
final apiRepositoryProvider = Provider<ApiRepository>(
  (ref) => ApiRepository(),
);

final mockRepositoryProvider = Provider<MockRepository>((ref) => MockRepository());

/// Bascule entre API reelle et demonstration hors ligne.
final repositoryProvider = Provider<ApiRepository>(
  (ref) => ref.watch(apiRepositoryProvider),
);

/// Indique a l'interface si l'on est en mode demonstration.
final useMockDataProvider = Provider<bool>((ref) => AppConfig.useMockData);

class SessionNotifier extends StateNotifier<AppUser?> {
  SessionNotifier(this._api) : super(null);

  final ApiRepository _api;

  Future<void> signUp({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    if (AppConfig.useMockData) {
      final mock = MockRepository();
      state = await mock.signUp(name: name, email: email, password: password);
      return;
    }

    state = await _api.signUp(
      name: name,
      email: email,
      phone: phone,
      password: password,
    );
  }

  Future<void> signIn({required String email, required String password}) async {
    if (AppConfig.useMockData) {
      final mock = MockRepository();
      state = await mock.signIn(email: email, password: password);
      return;
    }

    state = await _api.signIn(email: email, password: password);
  }

  /// Module 1 : consomme le dernier code OTP renvoye par l'API (demo).
  String? consumeDemoOtp() => _api.consumeDemoOtp();

  /// Renvoie un code de verification pour le numero de la session courante.
  Future<String?> resendOtp() async {
    final phone = state?.phone ?? '';
    if (phone.isEmpty) return null;
    return _api.requestOtp(phone);
  }

  /// Valide le code saisi : le profil est rafraichi avec phone_verified=true,
  /// ce qui libere automatiquement l'acces aux services (garde du routeur).
  Future<void> verifyPhone({required String code}) async {
    final phone = state?.phone ?? '';
    if (phone.isEmpty) return;
    state = await _api.verifyOtp(phone: phone, code: code);
  }

  Future<String?> forgotPassword({required String email}) =>
      _api.forgotPassword(email: email);

  Future<void> resetPassword({
    required String email,
    required String code,
    required String password,
    required String passwordConfirmation,
  }) => _api.resetPassword(
    email: email,
    code: code,
    password: password,
    passwordConfirmation: passwordConfirmation,
  );

  Future<void> logout() async {
    try {
      await _api.logout();
    } catch (_) {}
    state = null;
  }

  Future<void> updateMe({
    required String name,
    required String email,
    String? password,
    String? passwordConfirmation,
    String? phone,
  }) async {
    state = await _api.updateMe(
      name: name,
      email: email,
      password: password,
      passwordConfirmation: passwordConfirmation,
      phone: phone,
    );
  }

  /// Appelee par main() avant runApp : restaure une session deja ouverte
  /// (jeton persiste + GET /me) pour eviter une reconnexion a chaque demarrage.
  Future<void> restore() async {
    if (AppConfig.useMockData) return;
    state = await _api.restoreSession();
  }
}

final sessionProvider = StateNotifierProvider<SessionNotifier, AppUser?>(
  (ref) => SessionNotifier(ref.watch(apiRepositoryProvider)),
);

final matchesProvider = FutureProvider<List<ItemMatch>>((ref) async {
  if (AppConfig.useMockData) {
    return MockRepository().fetchMatches();
  }
  return ref.watch(repositoryProvider).fetchMatches();
});

final matchProvider = FutureProvider.family<ItemMatch, String>((ref, id) async {
  if (AppConfig.useMockData) {
    return MockRepository().fetchMatch(id);
  }
  return ref.watch(repositoryProvider).fetchMatch(id);
});

/// Module 4 : score de confiance de l'utilisateur connecte.
final trustProvider = FutureProvider<TrustSummary>((ref) async {
  if (AppConfig.useMockData) {
    return const TrustSummary(
      score: 72,
      recoveredCount: 3,
      canChat: true,
      inProbation: false,
      history: [],
    );
  }
  return ref.watch(repositoryProvider).fetchTrust();
});

class VerificationResult {
  const VerificationResult({required this.success, required this.matchId});

  final bool success;
  final String matchId;
}

final verificationProvider =
    StateNotifierProvider<VerificationNotifier, VerificationResult?>(
      (ref) => VerificationNotifier(ref.watch(repositoryProvider)),
    );

class VerificationNotifier extends StateNotifier<VerificationResult?> {
  VerificationNotifier(this._repository) : super(null);

  final ApiRepository _repository;

  bool _busy = false;
  bool get busy => _busy;

  Future<bool> submit({required String matchId, required String answer}) async {
    _busy = true;
    final ok = await _repository.verifyAnswer(matchId: matchId, answer: answer);
    state = VerificationResult(success: ok, matchId: matchId);
    _busy = false;
    return ok;
  }

  void reset() => state = null;
}

/// Module 5 : envoi d'une reclamation depuis l'ecran de correspondance.
final claimProvider = StateNotifierProvider<ClaimNotifier, bool>(
  (ref) => ClaimNotifier(ref.watch(repositoryProvider)),
);

class ClaimNotifier extends StateNotifier<bool> {
  ClaimNotifier(this._repository) : super(false);

  final ApiRepository _repository;

  bool _sending = false;
  bool get sending => _sending;

  String? _error;
  String? get error => _error;

  Future<bool> send({
    required String type,
    required String description,
    String? matchId,
  }) async {
    _sending = true;
    _error = null;
    try {
      await _repository.fileClaim(
        type: type,
        description: description,
        matchId: matchId,
      );
      state = true;
      return true;
    } on Object catch (error) {
      _error = error.toString();
      return false;
    } finally {
      _sending = false;
    }
  }

  void reset() => state = false;
}
final myItemsProvider = FutureProvider<List<Item>>((ref) async {
  if (AppConfig.useMockData) {
    return const [];
  }
  return ref.watch(repositoryProvider).fetchMyItems();
});


final nearbyFoundProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  if (AppConfig.useMockData) {
    return const [];
  }
  return ref.watch(repositoryProvider).fetchNearbyFound();
});

// --- Module 4 : Providers Récompenses, Coupons & Gamification ---

final rewardsProvider = FutureProvider<List<Reward>>((ref) async {
  if (AppConfig.useMockData) {
    return ref.watch(mockRepositoryProvider).fetchRewards();
  }
  return ref.watch(repositoryProvider).fetchRewards();
});

final myCouponsProvider = FutureProvider<List<UserCoupon>>((ref) async {
  if (AppConfig.useMockData) {
    return ref.watch(mockRepositoryProvider).fetchMyCoupons();
  }
  return ref.watch(repositoryProvider).fetchMyCoupons();
});

final rewardWalletProvider = FutureProvider<RewardWallet>((ref) async {
  if (AppConfig.useMockData) {
    return ref.watch(mockRepositoryProvider).fetchRewardWallet();
  }
  return ref.watch(repositoryProvider).fetchRewardWallet();
});

