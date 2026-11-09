import '../core/app_config.dart';
import 'api_client.dart';
import 'models/chat_message.dart';
import 'models/item.dart';
import 'models/item_match.dart';
import 'models/reward.dart';
import 'models/swipe_candidate.dart';
import 'models/trust.dart';

/// Resultat d'une demande de reinitialisation : indique si un e-mail a
/// vraiment ete envoye et, en local, ou il a ete livre.
class ForgotPasswordResult {
  const ForgotPasswordResult({
    required this.mailSent,
    this.demoOtp,
    this.deliveredTo,
  });

  final bool mailSent;
  final String? demoOtp;
  final String? deliveredTo;
}

/// Repository branche sur l'API Laravel.
class ApiRepository {
  ApiRepository({ApiClient? client})
      : _client = client ?? ApiClient(baseUrl: AppConfig.apiBaseUrl);

  final ApiClient _client;

  /// Identifiant de l'utilisateur connecte, renseigne par [_toUser].
  int? currentUserId;

  String? get token => _client.token;

  String get baseUrl => _client.baseUrl;

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

  /// Mot de passe oublie : indique si l'e-mail a ete envoye et, en local,
  /// l'adresse de livraison ainsi que le code de demonstration.
  Future<ForgotPasswordResult> forgotPassword({required String email}) async {
    final json = await _client.post('/auth/forgot-password', {
      'email': email,
    }) as Map<String, dynamic>;
    final otp = json['demo_otp'] as String?;
    lastDemoOtp = otp;
    return ForgotPasswordResult(
      mailSent: json['mail_sent'] as bool? ?? true,
      demoOtp: otp,
      deliveredTo: json['delivered_to'] as String?,
    );
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
      currentUserId = null;
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

  /// Messages de la correspondance, tries du plus ancien au plus recent.
  Future<List<ChatMessage>> fetchMessages(
    String matchId, {
    DateTime? after,
    DateTime? before,
    int limit = 50,
  }) async {
    final query = <String, String>{'limit': '$limit'};
    if (after != null) {
      query['after'] = after.toUtc().toIso8601String();
    }
    if (before != null) {
      query['before'] = before.toUtc().toIso8601String();
    }
    final suffix = Uri(queryParameters: query).query;
    final json = await _client.get(
      '/matches/$matchId/messages?$suffix',
    ) as List<dynamic>;
    return json
        .map(
          (raw) => ChatMessage.fromJson(
            raw as Map<String, dynamic>,
            currentUserId: currentUserId,
          ),
        )
        .toList();
  }

  Future<ChatMessage> sendMessage({
    required String matchId,
    required String body,
  }) async {
    final json = await _client.post('/matches/$matchId/messages', {
      'body': body,
    }) as Map<String, dynamic>;
    return ChatMessage.fromJson(json, currentUserId: currentUserId);
  }

  Future<void> markMessagesRead(String matchId) async {
    await _client.post('/matches/$matchId/messages/read', {});
  }

  Future<void> reportMessage({
    required String matchId,
    required String messageId,
    String? reason,
  }) async {
    await _client.post('/matches/$matchId/messages/$messageId/report', {
      'reason': reason ?? '',
    });
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

  Future<Item> fetchItem(String id) async {
    final json = await _client.get('/items/$id') as Map<String, dynamic>;
    return Item.fromJson(json);
  }

  Future<void> deleteItem(String id) async {
    await _client.delete('/items/$id');
  }

  Future<List<Item>> fetchCatalog(ItemCatalogQuery query) async {
    final items = <Item>[];
    final seen = <String>{};
    var page = 1;
    var lastPage = 1;
    while (page <= lastPage && page <= 5) {
      final json = await _client.get('/items?${query.toQuery(page: page)}');
      if (json is! Map<String, dynamic>) break;
      final data = json['data'];
      if (data is List) {
        for (final raw in data) {
          if (raw is! Map<String, dynamic>) continue;
          final item = Item.fromJson(raw);
          if (seen.add(item.id)) items.add(item);
        }
      }
      final meta = json['meta'];
      if (meta is Map) {
        lastPage = (meta['last_page'] as num?)?.toInt() ?? page;
      }
      page++;
    }
    return items;
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

  /// Module 4 : Catalogue des récompenses partenaires (Glovo, Yassir, Restos)
  Future<List<Reward>> fetchRewards() async {
    final list = await _client.get('/rewards') as List<dynamic>;
    return list.map((raw) => Reward.fromJson(raw as Map<String, dynamic>)).toList();
  }

  /// Module 4 : Liste des coupons de l'utilisateur
  Future<List<UserCoupon>> fetchMyCoupons() async {
    final list = await _client.get('/rewards/my-coupons') as List<dynamic>;
    return list.map((raw) => UserCoupon.fromJson(raw as Map<String, dynamic>)).toList();
  }

  /// Module 4 : Solde de points, statut du tour gratuit et historique
  Future<RewardWallet> fetchRewardWallet() async {
    final json = await _client.get('/rewards/wallet') as Map<String, dynamic>;
    return RewardWallet.fromJson(json);
  }

  /// Module 4 : Échange de points contre un coupon
  Future<Map<String, dynamic>> redeemReward(int rewardId) async {
    final json = await _client.post('/rewards/$rewardId/redeem', {}) as Map<String, dynamic>;
    return json;
  }

  /// Module 4 : Mini-jeu — Roue de la Chance
  Future<SpinResult> spinWheel() async {
    final json = await _client.post('/rewards/wheel/spin', {}) as Map<String, dynamic>;
    return SpinResult.fromJson(json);
  }

  /// Module 4 : Envoi du coupon par e-mail avec PDF joint
  Future<String> sendCouponEmail(String couponId, {String? targetEmail}) async {
    final payload = (targetEmail != null && targetEmail.trim().isNotEmpty)
        ? {'email': targetEmail.trim()}
        : <String, dynamic>{};
    final json = await _client.post('/rewards/coupons/$couponId/send-email', payload) as Map<String, dynamic>;
    return json['message'] as String? ?? 'E-mail envoyé avec succès.';
  }

  /// Module 4 : Marquer un coupon comme utilisé
  Future<UserCoupon> markCouponUsed(String couponId) async {
    final json = await _client.post('/rewards/coupons/$couponId/use', {}) as Map<String, dynamic>;
    return UserCoupon.fromJson(json['coupon'] as Map<String, dynamic>);
  }

  /// Module Tinder Cards : deck de correspondances classées par le moteur,
  /// chaque carte étant enrichie d'une pré-analyse IA.
  Future<List<SwipeCandidate>> fetchSwipeDeck() async {
    final json = await _client.get('/swipe/deck') as Map<String, dynamic>;
    final candidates = json['candidates'] as List<dynamic>? ?? const [];
    return candidates
        .map((raw) => SwipeCandidate.fromJson(raw as Map<String, dynamic>))
        .toList();
  }

  /// Analyse IA détaillée d'une correspondance (raisons, confiance, message).
  Future<AiInsight> fetchSwipeInsight(String matchId) async {
    final json =
        await _client.get('/swipe/$matchId/insight') as Map<String, dynamic>;
    return AiInsight.fromJson(
      (json['insight'] as Map?)?.cast<String, dynamic>() ?? json,
    );
  }

  /// Enregistre le choix de l'utilisateur. Le backend met aussi à jour la
  /// décision du match (LIKE = YES, PASS = NO) pour rester cohérent avec le
  /// parcours de vérification existant.
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
    final lostUser = lost?['user'] as Map<String, dynamic>?;
    final foundUser = found?['user'] as Map<String, dynamic>?;

    // Le serveur indique le role de l'utilisateur connecte : le proprietaire
    // voit son annonce perdue en premier, celui qui a trouve voit l'inverse.
    final iAmFinder = json['viewer_role'] == 'finder';
    final myItem = iAmFinder ? found : lost;
    final otherItem = iAmFinder ? lost : found;
    final otherUser = iAmFinder ? lostUser : foundUser;

    return ItemMatch(
      id: json['id'] as String? ?? '',
      myItemTitle: myItem?['title'] as String? ?? '',
      myItemPlace: myItem?['place_label'] as String? ?? '',
      myItemTimeLabel: _timeLabel(myItem?['occurred_at'] as String?),
      myItemCategory: _categoryFromCode(myItem?['category'] as String?),
      foundItemTitle: otherItem?['title'] as String? ?? '',
      foundItemPlace: otherItem?['place_label'] as String? ?? '',
      foundItemTimeLabel: _timeLabel(otherItem?['occurred_at'] as String?),
      foundItemCategory: _categoryFromCode(
        otherItem?['category'] as String?,
      ),
      finderName: otherUser?['name'] as String? ?? 'Utilisateur',
      finderInitials: _initials(otherUser?['name'] as String? ?? 'U'),
      finderReputation: (otherUser?['trust_score'] as num?)?.toDouble() ?? 50,
      finderRecoveredCount:
          (otherUser?['recovered_count'] as num?)?.toInt() ?? 0,
      viewerRole: iAmFinder ? 'finder' : 'owner',
      myItemType: iAmFinder ? ItemType.found : ItemType.lost,
      otherItemType: iAmFinder ? ItemType.lost : ItemType.found,
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
      status: json['status'] as String? ?? 'PENDING',
      canChat: json['can_chat'] as bool? ?? _statusAllowsChat(json['status']),
      chatLockedReason: json['chat_locked_reason'] as String?,
      lastMessage: json['last_message'] as String?,
      lastMessageAt: DateTime.tryParse(
        json['last_message_at'] as String? ?? '',
      ),
      lastMessageIsMine: json['last_message_is_mine'] as bool? ?? false,
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
    );
  }

  bool _statusAllowsChat(Object? status) {
    return status == 'VERIFIED' ||
        status == 'CONTACTED' ||
        status == 'RECOVERED';
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
    final id = json['id']?.toString() ?? '';
    currentUserId = int.tryParse(id);
    final name = json['name'] as String? ?? 'Utilisateur';
    final trust = (json['trust_score'] as num?)?.toDouble() ?? 50;
    return AppUser(
      id: id,
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






