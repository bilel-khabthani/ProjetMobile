import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mock_repository.dart';
import 'models/item_match.dart';

final repositoryProvider = Provider<MockRepository>((ref) => MockRepository());

class SessionNotifier extends StateNotifier<AppUser?> {
  SessionNotifier(this._repository) : super(null);

  final MockRepository _repository;

  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    state = await _repository.signUp(
      name: name,
      email: email,
      password: password,
    );
  }

  Future<void> signIn({required String email, required String password}) async {
    state = await _repository.signIn(email: email, password: password);
  }

  void signOut() => state = null;
}

final sessionProvider = StateNotifierProvider<SessionNotifier, AppUser?>((ref) {
  return SessionNotifier(ref.watch(repositoryProvider));
});

final matchesProvider = FutureProvider<List<ItemMatch>>((ref) async {
  return ref.watch(repositoryProvider).fetchMatches();
});

final matchProvider = FutureProvider.family<ItemMatch, String>((ref, id) async {
  return ref.watch(repositoryProvider).fetchMatch(id);
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

  final MockRepository _repository;

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
