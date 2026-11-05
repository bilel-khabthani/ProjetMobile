import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_config.dart';
import 'api_client.dart';
import 'api_repository.dart';
import 'chat_socket.dart';
import 'mock_repository.dart';
import 'models/chat_message.dart';
import 'models/item_match.dart';
import 'models/trust.dart';
import 'models/item.dart';

/// Client API centralise et partage pour Sanctum.
final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(baseUrl: AppConfig.apiBaseUrl),
);

/// Source de donnees active. Les deux classes exposent la meme surface, donc
/// les ecrans ne changent pas selon le mode choisi.
final apiRepositoryProvider = Provider<ApiRepository>(
  (ref) => ApiRepository(client: ref.watch(apiClientProvider)),
);

final mockRepositoryProvider = Provider<MockRepository>(
  (ref) => MockRepository(),
);

/// Bascule entre API reelle et demonstration hors ligne.
final repositoryProvider = Provider<ApiRepository>(
  (ref) => ref.watch(apiRepositoryProvider),
);

/// Indique a l'interface si l'on est en mode demonstration.
final useMockDataProvider = Provider<bool>((ref) => AppConfig.useMockData);

class SessionNotifier extends StateNotifier<AppUser?> {
  SessionNotifier(this._api, this._ref) : super(null);

  final ApiRepository _api;
  final Ref _ref;

  /// Les listes et details sont mis en cache pour la duree de vie de
  /// l'application. Au changement de compte, il faut les oublier : sinon on
  /// garde le point de vue (owner/finder) et les donnees du compte precedent.
  void _resetAccountScopedState() {
    _ref.invalidate(matchesProvider);
    _ref.invalidate(matchProvider);
    _ref.invalidate(trustProvider);
    _ref.invalidate(myItemsProvider);
    _ref.invalidate(nearbyFoundProvider);
    _ref.invalidate(verificationProvider);
  }

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
    _resetAccountScopedState();
  }

  Future<void> signIn({required String email, required String password}) async {
    if (AppConfig.useMockData) {
      final mock = MockRepository();
      state = await mock.signIn(email: email, password: password);
      return;
    }

    state = await _api.signIn(email: email, password: password);
    _resetAccountScopedState();
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
    _resetAccountScopedState();
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
    _resetAccountScopedState();
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
  (ref) => SessionNotifier(ref.watch(apiRepositoryProvider), ref),
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

class ChatState {
  const ChatState({
    this.messages = const [],
    this.loading = true,
    this.sending = false,
    this.connected = false,
    this.error,
  });

  final List<ChatMessage> messages;
  final bool loading;
  final bool sending;
  final bool connected;
  final String? error;

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? loading,
    bool? sending,
    bool? connected,
    String? error,
    bool clearError = false,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      loading: loading ?? this.loading,
      sending: sending ?? this.sending,
      connected: connected ?? this.connected,
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
      onStateChanged: (connected) {
        if (mounted) {
          state = state.copyWith(connected: connected);
        }
      },
    );
    unawaited(load());
  }

  final ApiRepository _repository;
  final String matchId;
  late final ChatSocket _socket;

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);

    try {
      final messages = await _repository.fetchMessages(matchId);
      if (!mounted) return;

      state = state.copyWith(messages: messages, loading: false);

      // Un echec de lecture ne doit pas empecher l'ouverture du WebSocket.
      try {
        await _repository.markMessagesRead(matchId);
      } catch (_) {
        // Le message reste non lu cote serveur ; la messagerie reste utilisable.
      }
      await _socket.connect();
      await _socket.connect();
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

      final messages = [...state.messages];
      if (!messages.any((item) => item.id == message.id)) {
        messages.add(message);
      }
      state = state.copyWith(messages: messages, sending: false);
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

    final existing = state.messages.indexWhere((item) => item.id == message.id);
    if (existing >= 0) return;

    final messages = [...state.messages, message]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    state = state.copyWith(messages: messages);

    if (!message.isMine) {
      _markReadSilently();
    }
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
    unawaited(_socket.dispose());
    super.dispose();
  }
}

final chatProvider = StateNotifierProvider.autoDispose
    .family<ChatNotifier, ChatState, String>(
      (ref, matchId) => ChatNotifier(ref.watch(repositoryProvider), matchId),
    );

final myItemsProvider = FutureProvider<List<Item>>((ref) async {
  if (AppConfig.useMockData) {
    return const [];
  }
  return ref.watch(repositoryProvider).fetchMyItems();
});

final nearbyFoundProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  if (AppConfig.useMockData) {
    return const [];
  }
  return ref.watch(repositoryProvider).fetchNearbyFound();
});
