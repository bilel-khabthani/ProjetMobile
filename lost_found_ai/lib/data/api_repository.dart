import '../core/app_config.dart';
import 'api_client.dart';
import 'models/item.dart';
import 'models/item_match.dart';
import 'models/swipe_candidate.dart';
import 'models/trust.dart';

/// Repository branche sur l'API Laravel.
class ApiRepository {
  ApiRepository({ApiClient? client})
      : _client = client ?? ApiClient(baseUrl: AppConfig.apiBaseUrl);

  final ApiClient _client;

  /// Dernier code OTP recu de l'API (demo sans passerelle SMS : le serveur
  /// renvoie le code pour permettre un test immediat). Lu puis efface par
  /// l'ecran concerne via [consumeDemoOtp].
  String? lastDemoOtp;

  String? consumeDemoOtp() {
    final otp = lastDemoOtp;
    lastDemoOtp = null;
    return otp;
  }

  Future<AppUser> signUp({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    final json = await _client.post('/auth/register', {
      'name': name,
      'email': email,
      'phone': phone,
      'password': password,
    }) as Map<String, dynamic>;
    _client.token = json['token'] as String?;
    lastDemoOtp = json['demo_otp'] as String?;
    return _toUser(json['user'] as Map<String, dynamic>);
  }

  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    final json = await _client.post('/auth/login', {
      'email': email,
      'password': password,
    }) as Map<String, dynamic>;
    _client.token = json['token'] as String?;
    lastDemoOtp = null;
    return _toUser(json['user'] as Map<String, dynamic>);
  }

  /// Authentification avec Google (Continue with Google).
  Future<AppUser> signInWithGoogle({
    String? idToken,
    String? email,
    String? name,
    String? googleId,
    String? avatar,
  }) async {
    final body = <String, dynamic>{};
    if (idToken != null) body['id_token'] = idToken;
    if (email != null) body['email'] = email;
    if (name != null) body['name'] = name;
    if (googleId != null) body['google_id'] = googleId;
    if (avatar != null) body['avatar'] = avatar;

    final json = await _client.post('/auth/google', body) as Map<String, dynamic>;
    _client.token = json['token'] as String?;
    lastDemoOtp = null;
    return _toUser(json['user'] as Map<String, dynamic>);
  }

  /// Demande un code de verification au serveur. Retourne le code en demo.
  Future<String?> requestOtp(String phone) async {
    final json = await _client.post('/auth/otp/request', {
      'phone': phone,
    }) as Map<String, dynamic>;
    final otp = json['demo_otp'] as String?;
    lastDemoOtp = otp;
    return otp;
  }

  /// Valide le code et retourne le profil rafraichi (phone_verified=true).
  Future<AppUser> verifyOtp({required String phone, required String code}) async {
    final json = await _client.post('/auth/otp/verify', {
      'phone': phone,
      'code': code,
    }) as Map<String, dynamic>;
    final user = json['user'] as Map<String, dynamic>?;
    if (user != null) return _toUser(user);
    return _toUser(await _client.get('/me') as Map<String, dynamic>);
  }

  /// Mot de passe oublie : retourne le code (demo) ou null si inconnu.
  Future<String?> forgotPassword({required String email}) async {
    final json = await _client.post('/auth/forgot-password', {
      'email': email,
    }) as Map<String, dynamic>;
    final otp = json['demo_otp'] as String?;
    lastDemoOtp = otp;
    return otp;
  }

  Future<void> resetPassword({
    required String email,
    required String code,
    required String password,
    required String passwordConfirmation,
  }) async {
    await _client.post('/auth/reset-password', {
      'email': email,
      'code': code,
      'password': password,
      'password_confirmation': passwordConfirmation,
    });
  }

  /// Deconnexion : revoque le jeton cote serveur puis l'efface du stockage
  /// securise. Les erreurs reseau ne doivent pas empecher la deconnexion locale.
  Future<void> logout() async {
    try {
      await _client.post('/auth/logout', {});
    } on ApiException catch (error) {
      // 401 = jeton deja invalide : rien a faire de plus.
      if (error.statusCode != 401) rethrow;
    } finally {
      _client.token = null;
    }
  }

  /// Restauration de session au demarrage : recharge le jeton persiste et
  /// recharge le profil via GET /me. Retourne l'utilisateur connecte, ou null
  /// si aucune session valide n'est retrouvable.
  Future<AppUser?> restoreSession() async {
    final token = await _client.restoreToken();
    if (token == null) return null;

    try {
      final json = await _client.get('/me') as Map<String, dynamic>;
      return _toUser(json);
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        // Jeton rejete par le serveur : on le purge definitivement.
        _client.token = null;
      }
      return null;
    } catch (_) {
      // Pas de reseau : on garde le jeton pour une prochaine tentative,
      // mais on considere l'utilisateur comme deconnecte pour cette session.
      return null;
    }
  }

  Future<AppUser> updateMe({
    required String name,
    required String email,
    String? password,
    String? passwordConfirmation,
    String? phone,
  }) async {
    final payload = <String, dynamic>{'name': name, 'email': email};
    if (password != null && password.isNotEmpty) {
      payload['password'] = password;
      payload['password_confirmation'] = passwordConfirmation;
    }
    if (phone != null && phone.isNotEmpty) {
      payload['phone'] = phone;
    }
    final json = await _client.patch('/auth/me', payload) as Map<String, dynamic>;
    // Un changement de numero re-definit phone_verified=false : le serveur
    // renvoie alors un nouveau code a saisir sur l'ecran de verification.
    lastDemoOtp = json['demo_otp'] as String?;
    return _toUser(json['user'] as Map<String, dynamic>? ?? json);
  }

  Future<List<ItemMatch>> fetchMatches() async {
    final matches = await _client.get('/matches') as List<dynamic>;
    return matches
        .map((raw) => _toMatch(raw as Map<String, dynamic>))
        .toList();
  }

  Future<ItemMatch> fetchMatch(String id) async {
    final json = await _client.get('/matches/$id') as Map<String, dynamic>;
    return _toMatch(json);
  }

  Future<bool> verifyAnswer({
    required String matchId,
    required String answer,
  }) async {
    final normalized = answer.trim().toUpperCase();
    final decision = switch (normalized) {
      'OUI' || 'YES' || '1' => 'YES',
      'NON' || 'NO' || '0' => 'NO',
      _ => 'UNSURE',
    };
    final json = await _client.post(
      '/matches/$matchId/answer',
      {'answer': decision},
    ) as Map<String, dynamic>;
    return json['status'] != 'PENDING';
  }

  Future<void> publishItem({
    required ItemType type,
    required ItemCategory category,
    required String description,
    required String place,
    required DateTime occurredAt,
    double? latitude,
    double? longitude,
  }) async {
    final payload = <String, dynamic>{
      'type': type == ItemType.lost ? 'LOST' : 'FOUND',
      'category': _categoryCode(category),
      'title': _titleFrom(description),
      'description': description,
      'place_label': place,
      'occurred_at': occurredAt.toUtc().toIso8601String(),
    };
    if (latitude != null) payload['latitude'] = latitude;
    if (longitude != null) payload['longitude'] = longitude;
    await _client.post('/items', payload);

    final mine = await _client.get('/items/mine') as List<dynamic>;
    if (mine.isNotEmpty) {
      final last = mine.first as Map<String, dynamic>;
      try {
      await _client.get('/items/${last['id']}/matches');
    } catch (_) {}
    }
  }

  Future<List<Item>> fetchMyItems() async {
    final items = await _client.get('/items/mine') as List<dynamic>;
    return items.map((raw) => _toItem(raw as Map<String, dynamic>)).toList();
  }

  Future<List<Map<String, dynamic>>> fetchNearbyFound() async {
    final json = await _client.get('/items/nearby-found') as List<dynamic>;
    return json.map((e) => e as Map<String, dynamic>).toList();
  }

  Future<TrustSummary> fetchTrust() async {
    final json = await _client.get('/trust/me') as Map<String, dynamic>;
    final events = (json['events'] as List<dynamic>? ?? const []);
    return TrustSummary(
      score: (json['trust_score'] as num?)?.toDouble() ?? 50,
      recoveredCount: (json['recovered_count'] as num?)?.toInt() ?? 0,
      canChat: json['can_chat'] as bool? ?? false,
      inProbation: json['in_probation'] as bool? ?? false,
      history: events
          .map(
            (raw) => TrustEvent(
              label: _eventLabel(raw['type'] as String? ?? ''),
              points: (raw['points'] as num?)?.toInt() ?? 0,
              at: DateTime.tryParse(raw['created_at'] as String? ?? '') ??
                  DateTime.now(),
              automatic: raw['validated_by'] == 'SYSTEME',
            ),
          )
          .toList(),
    );
  }

  Future<void> fileClaim({
    required String type,
    required String description,
    String? matchId,
  }) async {
    await _client.post('/claims', {
      'type': type,
      'description': description,
      'related_match_id': matchId,
    });
  }

  /// Module Tinder Cards : deck de correspondances classees par le moteur,
  /// chaque carte etant enrichie d'une pre-analyse IA.
  Future<List<SwipeCandidate>> fetchSwipeDeck() async {
    final json = await _client.get('/swipe/deck') as Map<String, dynamic>;
    final candidates = json['candidates'] as List<dynamic>? ?? const [];
    return candidates
        .map((raw) => SwipeCandidate.fromJson(raw as Map<String, dynamic>))
        .toList();
  }

  /// Analyse IA detaillee d'une correspondance (raisons, confiance, message).
  Future<AiInsight> fetchSwipeInsight(String matchId) async {
    final json =
        await _client.get('/swipe/$matchId/insight') as Map<String, dynamic>;
    return AiInsight.fromJson(
      (json['insight'] as Map?)?.cast<String, dynamic>() ?? json,
    );
  }

  /// Enregistre le choix de l'utilisateur. Le backend met aussi a jour la
  /// decision du match (LIKE = YES, PASS = NO) pour rester coherent avec le
  /// parcours de verification existant.
  Future<void> recordSwipeDecision({
    required String matchId,
    required SwipeDirection direction,
    int? aiConfidence,
  }) async {
    final payload = <String, dynamic>{'direction': direction.code};
    if (aiConfidence != null) payload['ai_confidence'] = aiConfidence;
    await _client.post('/swipe/$matchId/decision', payload);
  }

  Item _toItem(Map<String, dynamic> json) {
    return Item(
      id: json['id'] as String? ?? '',
      type: (json['type'] as String?) == 'LOST' ? ItemType.lost : ItemType.found,
      category: _categoryFromCode(json['category'] as String?),
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      place: json['place_label'] as String? ?? '',
      occurredAt:
          DateTime.tryParse(json['occurred_at'] as String? ?? '') ?? DateTime.now(),
      distanceMeters: 0,
      status: ItemStatus.active,
    );
  }

  String _timeLabel(String? iso) {
    final date = DateTime.tryParse(iso ?? '');
    if (date == null) return 'Date inconnue';
    const months = [
      'janvier', 'fevrier', 'mars', 'avril', 'mai', 'juin', 'juillet', 'aout', 'septembre', 'octobre', 'novembre', 'decembre',
    ];
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day ${months[local.month - 1]} ${local.year} a $hour:$minute';
  }

  ItemMatch _toMatch(Map<String, dynamic> json) {
    final lost = json['lost_item'] as Map<String, dynamic>?;
    final found = json['found_item'] as Map<String, dynamic>?;
    final scores = json['scores'] as Map<String, dynamic>? ?? {};
    final dims = scores['dimensions'] as Map<String, dynamic>? ?? {};
    final foundUser = found?['user'] as Map<String, dynamic>?;
    return ItemMatch(
      id: json['id'] as String? ?? '',
      myItemTitle: lost?['title'] as String? ?? '',
      myItemPlace: lost?['place_label'] as String? ?? '',
      myItemTimeLabel: _timeLabel(lost?['occurred_at'] as String?),
      myItemCategory: _categoryFromCode(lost?['category'] as String?),
      foundItemTitle: found?['title'] as String? ?? '',
      foundItemPlace: found?['place_label'] as String? ?? '',
      foundItemTimeLabel: _timeLabel(found?['occurred_at'] as String?),
      foundItemCategory: _categoryFromCode(found?['category'] as String?),
      finderName: foundUser?['name'] as String? ?? 'Trouveur',
      finderInitials: _initials(foundUser?['name'] as String? ?? 'T'),
      finderReputation: (foundUser?['trust_score'] as num?)?.toDouble() ?? 50,
      finderRecoveredCount: (foundUser?['recovered_count'] as num?)?.toInt() ?? 0,
      scores: MatchScores(
        image: (dims['photo'] as num?)?.toDouble() ?? 0,
        location: (dims['location'] as num?)?.toDouble() ?? 0,
        time: (dims['time'] as num?)?.toDouble() ?? 0,
        text: (dims['description'] as num?)?.toDouble() ?? 0,
        global: (scores['global'] as num?)?.toDouble() ?? 0,
      ),
      verificationQuestion:
          'Confirmez-vous que cet objet correspond a votre declaration ?',
      minutesAgo: _minutesAgo(json['created_at'] as String?),
    );
  }


  String _categoryCode(ItemCategory category) => switch (category) {
        ItemCategory.bag => 'sac',
        ItemCategory.phone => 'telephone',
        ItemCategory.keys => 'cles',
        ItemCategory.documents => 'papiers',
        ItemCategory.clothing => 'vetement',
        ItemCategory.glasses => 'lunettes',
        ItemCategory.wallet => 'portefeuille',
        ItemCategory.other => 'autre',
      };

  ItemCategory _categoryFromCode(String? code) => switch (code) {
        'sac' => ItemCategory.bag,
        'telephone' => ItemCategory.phone,
        'cles' => ItemCategory.keys,
        'papiers' => ItemCategory.documents,
        'vetement' => ItemCategory.clothing,
        'lunettes' => ItemCategory.glasses,
        'portefeuille' => ItemCategory.wallet,
        _ => ItemCategory.other,
      };

  String _titleFrom(String description) {
    final trimmed = description.trim();
    if (trimmed.isEmpty) return 'Annonce';
    final sentence = trimmed.split(RegExp(r'[\.\!\?]')).first;
    return sentence.length > 60 ? '${sentence.substring(0, 57)}...' : sentence;
  }

  int _minutesAgo(String? iso) {
    final date = DateTime.tryParse(iso ?? '');
    if (date == null) return 0;
    return DateTime.now().difference(date.toLocal()).inMinutes;
  }

  String _eventLabel(String type) => switch (type) {
        'RESTITUTION_CONFIRMEE' => 'Restitution confirmee',
        'DECLARATION_FAUSSE' => 'Declaration fausse',
        'ABSENCE_RDV' => 'Absence au rendez-vous',
        _ => type,
      };

  AppUser _toUser(Map<String, dynamic> json) {
    final name = json['name'] as String? ?? 'Utilisateur';
    final trust = (json['trust_score'] as num?)?.toDouble() ?? 50;
    return AppUser(
      name: name,
      email: json['email'] as String? ?? '',
      initials: _initials(name),
      reputation: trust,
      recoveredCount: (json['recovered_count'] as num?)?.toInt() ?? 0,
      phone: json['phone'] as String? ?? '',
      phoneVerified: json['phone_verified'] as bool? ?? false,
      avatar: json['avatar'] as String?,
      googleId: json['google_id'] as String?,
    );
  }


  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2);
    final letters = parts.map((part) => part[0].toUpperCase()).join();
    return letters.isEmpty ? 'LF' : letters;
  }
}






