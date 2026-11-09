import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_config.dart';
import 'api_client.dart';
import 'api_repository.dart';
import 'chat_socket.dart';
import 'demo_swipe_deck.dart';
import 'mock_repository.dart';
import 'models/chat_message.dart';
import 'models/item_match.dart';
import 'models/reward.dart';
import 'models/swipe_candidate.dart';
import 'models/trust.dart';
import 'models/item.dart';

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(baseUrl: AppConfig.apiBaseUrl),
);

/// Source de donnees active. Les deux classes exposent la meme surface, donc
/// les ecrans ne changent pas selon le mode choisi.
final apiRepositoryProvider = Provider<ApiRepository>(
  (ref) => ApiRepository(client: ref.watch(apiClientProvider)),
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

  /// Connexion avec Google
  Future<void> signInWithGoogle({
    String? idToken,
    String? email,
    String? name,
    String? googleId,
    String? avatar,
  }) async {
    if (AppConfig.useMockData) {
      final mock = MockRepository();
      state = await mock.signInWithGoogle(
        email: email,
        name: name,
        avatar: avatar,
      );
      return;
    }

    state = await _api.signInWithGoogle(
      idToken: idToken,
      email: email,
      name: name,
      googleId: googleId,
      avatar: avatar,
    );
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

/// Module Tinder Cards : état du deck de correspondances à trier.
class SwipeDeckState {
  SwipeDeckState({
    required List<SwipeCandidate> candidates,
    this.isDemo = false,
    this.message,
    int? initialTotal,
    this.liked = 0,
    this.passed = 0,
  }) : candidates = List.unmodifiable(candidates),
       initialTotal = initialTotal ?? candidates.length;

  final List<SwipeCandidate> candidates;
  final bool isDemo;
  final String? message;
  final int initialTotal;
  final int liked;
  final int passed;

  int get remaining => candidates.length;

  SwipeDeckState copyWith({
    List<SwipeCandidate>? candidates,
    bool? isDemo,
    String? message,
    int? initialTotal,
    int? liked,
    int? passed,
  }) {
    return SwipeDeckState(
      candidates: candidates ?? this.candidates,
      isDemo: isDemo ?? this.isDemo,
      message: message ?? this.message,
      initialTotal: initialTotal ?? this.initialTotal,
      liked: liked ?? this.liked,
      passed: passed ?? this.passed,
    );
  }
}

/// Charge le deck et applique les décisions de façon optimiste.
class SwipeDeckNotifier extends AsyncNotifier<SwipeDeckState> {
  @override
  Future<SwipeDeckState> build() => _load();

  Future<SwipeDeckState> _load() async {
    final repository = ref.read(repositoryProvider);
    try {
      final candidates = await repository.fetchSwipeDeck();
      return SwipeDeckState(candidates: candidates);
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) rethrow;
      return SwipeDeckState(
        candidates: demoSwipeDeck,
        isDemo: true,
        message: error.message,
      );
    } catch (_) {
      return SwipeDeckState(
        candidates: demoSwipeDeck,
        isDemo: true,
        message: 'Serveur indisponible',
      );
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  Future<void> decide(
    SwipeCandidate candidate,
    SwipeDirection direction,
  ) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final remaining = current.candidates
        .where((item) => item.matchId != candidate.matchId)
        .toList();
    state = AsyncData(
      current.copyWith(
        candidates: remaining,
        liked: current.liked + (direction == SwipeDirection.like ? 1 : 0),
        passed: current.passed + (direction == SwipeDirection.pass ? 1 : 0),
      ),
    );

    if (current.isDemo) return;

    try {
      await ref
          .read(repositoryProvider)
          .recordSwipeDecision(
            matchId: candidate.matchId,
            direction: direction,
            aiConfidence: candidate.ai.confidence,
          );
    } catch (_) {
      // La carte est déjà retirée : on ne bloque pas l'utilisateur.
    }
  }

  /// Analyse IA détaillée.
  Future<AiInsight> insight(SwipeCandidate candidate) async {
    if (state.valueOrNull?.isDemo ?? false) return candidate.ai;
    try {
      return await ref
          .read(repositoryProvider)
          .fetchSwipeInsight(candidate.matchId);
    } catch (_) {
      return candidate.ai;
    }
  }
}

final swipeDeckProvider =
    AsyncNotifierProvider<SwipeDeckNotifier, SwipeDeckState>(
      SwipeDeckNotifier.new,
    );

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

final catalogProvider = FutureProvider.autoDispose
    .family<List<Item>, ItemCatalogQuery>((ref, query) async {
      if (AppConfig.useMockData) return const [];
      return ref.watch(repositoryProvider).fetchCatalog(query);
    });

final itemProvider = FutureProvider.autoDispose.family<Item, String>((
  ref,
  id,
) async {
  return ref.watch(repositoryProvider).fetchItem(id);
});

class ChatState {
  const ChatState({
    this.messages = const [],
    this.loading = true,
    this.sending = false,
    this.connected = false,
    this.loadingOlder = false,
    this.hasMore = false,
    this.error,
  });

  final List<ChatMessage> messages;
  final bool loading;
  final bool sending;
  final bool connected;
  final bool loadingOlder;
  final bool hasMore;
  final String? error;

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? loading,
    bool? sending,
    bool? connected,
    bool? loadingOlder,
    bool? hasMore,
    String? error,
    bool clearError = false,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      loading: loading ?? this.loading,
      sending: sending ?? this.sending,
      connected: connected ?? this.connected,
      loadingOlder: loadingOlder ?? this.loadingOlder,
      hasMore: hasMore ?? this.hasMore,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Etat de la messagerie d'une correspondance : chargement, envoi et
/// abonnement temps reel via Reverb.
class ChatNotifier extends StateNotifier<ChatState> {
  ChatNotifier(this._repository, this.matchId) : super(const ChatState()) {
    _socket = ChatSocket(
      matchId: matchId,
      token: _repository.token,
      currentUserId: _repository.currentUserId,
      onMessage: _onSocketMessage,
      onMessagesRead: _onMessagesRead,
      onStateChanged: (connected) {
        if (mounted) {
          state = state.copyWith(connected: connected);
        }
      },
    );
    unawaited(load());
  }

  static const int _pageSize = 50;
  static const Duration _pollInterval = Duration(seconds: 10);

  final ApiRepository _repository;
  final String matchId;
  late final ChatSocket _socket;

  Timer? _pollTimer;
  bool _polling = false;
  int _pollTicks = 0;

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);

    try {
      final messages = await _repository.fetchMessages(
        matchId,
        limit: _pageSize,
      );
      if (!mounted) return;

      state = state.copyWith(
        messages: messages,
        loading: false,
        hasMore: messages.length >= _pageSize,
      );

      _markReadSilently();
      unawaited(_socket.connect());
      _ensurePolling();
    } on ApiException catch (error) {
      if (!mounted) return;
      state = state.copyWith(loading: false, error: error.message);
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(
        loading: false,
        error: 'Messagerie indisponible. Verifiez votre connexion.',
      );
    }
  }

  /// Charge la page precedente. Retourne une erreur affichable si besoin.
  Future<String?> loadOlder() async {
    if (state.loadingOlder || !state.hasMore || state.messages.isEmpty) {
      return null;
    }

    state = state.copyWith(loadingOlder: true, clearError: true);

    try {
      final older = await _repository.fetchMessages(
        matchId,
        before: state.messages.first.createdAt,
        limit: _pageSize,
      );
      if (!mounted) return null;

      state = state.copyWith(
        messages: _mergeMessages(older, state.messages),
        loadingOlder: false,
        hasMore: older.length >= _pageSize,
      );
      return null;
    } on ApiException catch (error) {
      if (mounted) {
        state = state.copyWith(loadingOlder: false, error: error.message);
      }
      return error.message;
    } catch (_) {
      const message = "Impossible de charger l'historique.";
      if (mounted) {
        state = state.copyWith(loadingOlder: false, error: message);
      }
      return message;
    }
  }

  /// Retourne un message d'erreur a afficher, ou null en cas de succes.
  Future<String?> send(String text) async {
    final body = text.trim();
    if (body.isEmpty) return null;

    state = state.copyWith(sending: true, clearError: true);

    try {
      final message = await _repository.sendMessage(
        matchId: matchId,
        body: body,
      );
      if (!mounted) return null;

      state = state.copyWith(
        messages: _mergeMessages(state.messages, [message]),
        sending: false,
      );
      return null;
    } on ApiException catch (error) {
      if (mounted) {
        state = state.copyWith(sending: false, error: error.message);
      }
      return error.message;
    } catch (_) {
      const message = "Impossible d'envoyer le message.";
      if (mounted) {
        state = state.copyWith(sending: false, error: message);
      }
      return message;
    }
  }

  Future<String?> report(String messageId, {String? reason}) async {
    try {
      await _repository.reportMessage(
        matchId: matchId,
        messageId: messageId,
        reason: reason,
      );
      return null;
    } on ApiException catch (error) {
      return error.message;
    } catch (_) {
      return 'Signalement impossible pour le moment.';
    }
  }

  void _onSocketMessage(ChatMessage message) {
    if (!mounted) return;

    if (state.messages.any((item) => item.id == message.id)) return;

    state = state.copyWith(messages: _mergeMessages(state.messages, [message]));

    if (!message.isMine) {
      _markReadSilently();
    }
  }

  void _onMessagesRead(Set<String> messageIds, DateTime readAt) {
    if (!mounted) return;

    final messages = state.messages
        .map(
          (message) => message.isMine && messageIds.contains(message.id)
              ? message.copyWith(readAt: readAt)
              : message,
        )
        .toList(growable: false);

    state = state.copyWith(messages: messages);
  }

  /// Filet de securite quand Reverb n'est pas disponible : on interroge l'API
  /// toutes les 10 s pour recuperer les nouveaux messages et les accuses de
  /// lecture. Toutes les 40 s, on recharge la derniere page pour synchroniser
  /// aussi les statuts de lecture.
  void _ensurePolling() {
    _pollTimer ??= Timer.periodic(_pollInterval, (_) => _poll());
  }

  Future<void> _poll() async {
    if (_polling || !mounted) return;
    _polling = true;

    try {
      _pollTicks++;
      if (_pollTicks % 4 == 0) {
        await _refreshLatest();
      } else {
        await _fetchNew();
      }
    } catch (_) {
      // Le prochain tick retentera ; l'ecran garde les messages deja affiches.
    } finally {
      _polling = false;
    }
  }

  Future<void> _fetchNew() async {
    if (state.messages.isEmpty) {
      await _refreshLatest();
      return;
    }

    final last = state.messages.last.createdAt.subtract(
      const Duration(seconds: 1),
    );
    final fresh = await _repository.fetchMessages(
      matchId,
      after: last,
      limit: _pageSize,
    );
    if (!mounted || fresh.isEmpty) return;

    state = state.copyWith(messages: _mergeMessages(state.messages, fresh));

    if (fresh.any((message) => !message.isMine)) {
      _markReadSilently();
    }
  }

  Future<void> _refreshLatest() async {
    final latest = await _repository.fetchMessages(matchId, limit: _pageSize);
    if (!mounted || latest.isEmpty) return;

    final latestIds = latest.map((message) => message.id).toSet();
    final older = state.messages
        .where((message) => !latestIds.contains(message.id))
        .toList(growable: false);

    state = state.copyWith(messages: _mergeMessages(older, latest));

    if (latest.any((message) => !message.isMine && message.readAt == null)) {
      _markReadSilently();
    }
  }

  List<ChatMessage> _mergeMessages(
    List<ChatMessage> base,
    List<ChatMessage> incoming,
  ) {
    final byId = <String, ChatMessage>{
      for (final message in base) message.id: message,
      for (final message in incoming) message.id: message,
    };
    final merged = byId.values.toList(growable: false)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return merged;
  }

  void _markReadSilently() {
    unawaited(() async {
      try {
        await _repository.markMessagesRead(matchId);
      } catch (_) {
        // Sans importance : le prochain chargement remettra l'etat a jour.
      }
    }());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    unawaited(_socket.dispose());
    super.dispose();
  }
}

final chatProvider = StateNotifierProvider.autoDispose
    .family<ChatNotifier, ChatState, String>(
      (ref, matchId) => ChatNotifier(ref.watch(repositoryProvider), matchId),
    );


