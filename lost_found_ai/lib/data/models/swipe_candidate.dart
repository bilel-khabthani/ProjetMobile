import 'item.dart';
import 'item_match.dart';

/// Verdict synthetique produit par l'IA pour une correspondance.
enum AiVerdict {
  strong,
  possible,
  weak;

  static AiVerdict fromCode(String? code) => switch (code?.toUpperCase()) {
    'STRONG' => AiVerdict.strong,
    'POSSIBLE' => AiVerdict.possible,
    _ => AiVerdict.weak,
  };

  String get code => switch (this) {
    AiVerdict.strong => 'STRONG',
    AiVerdict.possible => 'POSSIBLE',
    AiVerdict.weak => 'WEAK',
  };

  String get label => switch (this) {
    AiVerdict.strong => 'Correspondance forte',
    AiVerdict.possible => 'Correspondance plausible',
    AiVerdict.weak => 'Correspondance à vérifier',
  };
}

/// Direction choisie par l'utilisateur sur une carte.
enum SwipeDirection {
  pass,
  like;

  String get code => switch (this) {
    SwipeDirection.pass => 'PASS',
    SwipeDirection.like => 'LIKE',
  };

  String get label => switch (this) {
    SwipeDirection.pass => 'Passer',
    SwipeDirection.like => "C'est à moi",
  };
}

/// Explication generee par l'IA (ou par le moteur heuristique de secours).
///
/// Le contrat est volontairement stable : le backend peut basculer d'un
/// raisonnement local a un appel OpenAI sans que l'application change.
class AiInsight {
  const AiInsight({
    required this.verdict,
    required this.confidence,
    required this.summary,
    required this.reasons,
    required this.tags,
    required this.icebreaker,
    required this.source,
    this.agreementScore = 0,
    this.sharedDetails = const [],
    this.contradictions = const [],
  });

  final AiVerdict verdict;
  final int confidence;
  final String summary;
  final List<String> reasons;
  final List<String> tags;
  final String icebreaker;

  /// "openai" quand un vrai modele a repondu, "heuristic" / "demo" / "local" sinon.
  final String source;

  /// Score d'accord textuel (0-100) calcule par le moteur francais local.
  final int agreementScore;

  /// Details distinctifs partages par les deux annonces.
  final List<String> sharedDetails;

  /// Caracteristiques incompatibles detectees (couleur, taille, position...).
  final List<String> contradictions;

  bool get isLiveAi => source == 'openai';

  /// Recopie l'analyse avec des signaux locaux, sans perdre le verdict serveur.
  AiInsight copyWith({
    int? agreementScore,
    List<String>? sharedDetails,
    List<String>? contradictions,
    String? source,
  }) {
    return AiInsight(
      verdict: verdict,
      confidence: confidence,
      summary: summary,
      reasons: reasons,
      tags: tags,
      icebreaker: icebreaker,
      source: source ?? this.source,
      agreementScore: agreementScore ?? this.agreementScore,
      sharedDetails: sharedDetails ?? this.sharedDetails,
      contradictions: contradictions ?? this.contradictions,
    );
  }

  factory AiInsight.fromJson(Map<String, dynamic>? json) {
    final data = json ?? const <String, dynamic>{};
    final rawReasons = data['reasons'] as List<dynamic>? ?? const [];
    final rawTags = data['tags'] as List<dynamic>? ?? const [];
    final agreement =
        (data['agreement'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final rawShared = agreement['shared'] as List<dynamic>? ?? const [];
    final rawContradictions =
        agreement['contradictions'] as List<dynamic>? ?? const [];

    return AiInsight(
      verdict: AiVerdict.fromCode(data['verdict'] as String?),
      confidence: ((data['confidence'] as num?)?.toInt() ?? 0)
          .clamp(0, 100)
          .toInt(),
      summary:
          data['summary'] as String? ??
          'Rapprochement calculé à partir du texte, du lieu et de l’heure.',
      reasons: rawReasons
          .map((reason) => reason.toString())
          .where((reason) => reason.trim().isNotEmpty)
          .toList(),
      tags: rawTags
          .map((tag) => tag.toString())
          .where((tag) => tag.trim().isNotEmpty)
          .toList(),
      icebreaker: data['icebreaker'] as String? ?? '',
      source: data['source'] as String? ?? 'heuristic',
      agreementScore: ((agreement['score'] as num?)?.toInt() ?? 0)
          .clamp(0, 100)
          .toInt(),
      sharedDetails: rawShared
          .map((detail) => detail.toString())
          .where((detail) => detail.trim().isNotEmpty)
          .toList(),
      contradictions: rawContradictions
          .map((detail) => detail.toString())
          .where((detail) => detail.trim().isNotEmpty)
          .toList(),
    );
  }

  static const AiInsight empty = AiInsight(
    verdict: AiVerdict.weak,
    confidence: 0,
    summary: 'Pas encore d’analyse.',
    reasons: [],
    tags: [],
    icebreaker: '',
    source: 'heuristic',
  );
}

/// Une carte du deck : une correspondance perdue/trouvee enrichie par l'IA.
class SwipeCandidate {
  const SwipeCandidate({
    required this.matchId,
    required this.status,
    required this.lostTitle,
    required this.lostDescription,
    required this.lostCategory,
    required this.lostPlace,
    required this.foundTitle,
    required this.foundDescription,
    required this.foundCategory,
    required this.foundPlace,
    required this.foundTimeLabel,
    required this.distanceKm,
    required this.finderName,
    required this.finderInitials,
    required this.finderReputation,
    required this.finderRecoveredCount,
    required this.scores,
    required this.ai,
    this.lostImageUrl,
    this.foundImageUrl,
  });

  final String matchId;
  final String status;

  final String lostTitle;
  final String lostDescription;
  final ItemCategory lostCategory;
  final String lostPlace;

  final String foundTitle;
  final String foundDescription;
  final ItemCategory foundCategory;
  final String foundPlace;
  final String foundTimeLabel;
  final double? distanceKm;

  final String finderName;
  final String finderInitials;
  final double finderReputation;
  final int finderRecoveredCount;

  final MatchScores scores;
  final AiInsight ai;

  /// Photo de l'annonce perdue (null si absente).
  final String? lostImageUrl;

  /// Photo de l'annonce trouvee (null si absente).
  final String? foundImageUrl;

  /// Distance lisible, ou le lieu de decouverte si la geolocalisation manque.
  String get distanceLabel {
    final distance = distanceKm;
    if (distance == null) return foundPlace;
    if (distance < 1) return 'à ${(distance * 1000).round()} m';
    final rounded = distance < 10
        ? distance.toStringAsFixed(1).replaceAll('.', ',')
        : distance.round().toString();
    return 'à $rounded km';
  }

  factory SwipeCandidate.fromJson(Map<String, dynamic> json) {
    final lost =
        (json['lost_item'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final found =
        (json['found_item'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final finder =
        (found['user'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final scores =
        (json['scores'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};

    final finderName = finder['name'] as String? ?? 'Trouveur';

    return SwipeCandidate(
      matchId: json['id'] as String? ?? '',
      status: json['status'] as String? ?? 'PENDING',
      lostTitle: lost['title'] as String? ?? 'Votre objet',
      lostDescription: lost['description'] as String? ?? '',
      lostCategory: itemCategoryFromCode(lost['category'] as String?),
      lostPlace: lost['place_label'] as String? ?? '',
      foundTitle: found['title'] as String? ?? 'Objet trouvé',
      foundDescription: found['description'] as String? ?? '',
      foundCategory: itemCategoryFromCode(found['category'] as String?),
      foundPlace: found['place_label'] as String? ?? '',
      foundTimeLabel: swipeTimeLabel(found['occurred_at'] as String?),
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      finderName: finderName,
      finderInitials: initialsOf(finderName),
      finderReputation: (finder['trust_score'] as num?)?.toDouble() ?? 50,
      finderRecoveredCount: (finder['recovered_count'] as num?)?.toInt() ?? 0,
      scores: MatchScores(
        image: (scores['image'] as num?)?.toDouble() ?? 0,
        location: (scores['location'] as num?)?.toDouble() ?? 0,
        time: (scores['time'] as num?)?.toDouble() ?? 0,
        text: (scores['text'] as num?)?.toDouble() ?? 0,
        global: (scores['global'] as num?)?.toDouble() ?? 0,
      ),
      ai: AiInsight.fromJson((json['ai'] as Map?)?.cast<String, dynamic>()),
      lostImageUrl: resolveItemImageUrl(lost['image_url'] as String?),
      foundImageUrl: resolveItemImageUrl(found['image_url'] as String?),
    );
  }
}

/// Convertit les codes categories de l'API vers l'enum partage par l'app.
ItemCategory itemCategoryFromCode(String? code) => switch (code) {
  'sac' => ItemCategory.bag,
  'telephone' => ItemCategory.phone,
  'cles' => ItemCategory.keys,
  'papiers' => ItemCategory.documents,
  'vetement' => ItemCategory.clothing,
  'lunettes' => ItemCategory.glasses,
  'portefeuille' => ItemCategory.wallet,
  _ => ItemCategory.other,
};

String initialsOf(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .take(2);
  final letters = parts.map((part) => part[0].toUpperCase()).join();
  return letters.isEmpty ? 'LF' : letters;
}

/// Format francais compact utilise sur les cartes : "05 novembre · 14:20".
String swipeTimeLabel(String? iso) {
  final date = DateTime.tryParse(iso ?? '');
  if (date == null) return 'Date inconnue';
  const months = [
    'janvier',
    'février',
    'mars',
    'avril',
    'mai',
    'juin',
    'juillet',
    'août',
    'septembre',
    'octobre',
    'novembre',
    'décembre',
  ];
  final local = date.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day ${months[local.month - 1]} · $hour:$minute';
}
