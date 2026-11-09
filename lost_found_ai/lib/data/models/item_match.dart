import '../../core/ai/text_agreement_engine.dart';
import 'item.dart';

class MatchScores {
  const MatchScores({
    required this.image,
    required this.location,
    required this.time,
    required this.text,
    required this.global,
  });

  final double image;
  final double location;
  final double time;
  final double text;
  final double global;
}

enum MatchVerification { pending, verified }

/// Decision rendue par le moteur d'accord textuel apres une reponse libre.
enum VerificationDecision {
  yes,
  unsure,
  no;

  static VerificationDecision fromCode(String? code) => switch (code?.toUpperCase()) {
    'YES' || 'OUI' => VerificationDecision.yes,
    'UNSURE' => VerificationDecision.unsure,
    _ => VerificationDecision.no,
  };

  String get label => switch (this) {
    VerificationDecision.yes => 'Réponse acceptée',
    VerificationDecision.unsure => 'Réponse incertaine',
    VerificationDecision.no => 'Réponse refusée',
  };
}

/// Resultat de la verification : score, decision et signaux exploitables.
///
/// Le serveur renvoie cette forme a la fois dans `verification` (reponse a
/// POST /matches/{id}/answer) et dans `decision.verification` (fiche match).
class VerificationOutcome {
  const VerificationOutcome({
    required this.score,
    required this.decision,
    required this.matched,
    required this.contradictions,
    this.neutral = false,
  });

  final int score;
  final VerificationDecision decision;
  final List<String> matched;
  final List<String> contradictions;

  /// Vrai quand aucun detail secret n'est enregistre : le moteur ne peut pas
  /// conclure et la reponse reste en sursis.
  final bool neutral;

  bool get accepted => decision == VerificationDecision.yes;
  bool get partial => decision == VerificationDecision.unsure;

  factory VerificationOutcome.fromJson(Map<String, dynamic>? json) {
    final data = json ?? const <String, dynamic>{};
    return VerificationOutcome(
      score: ((data['score'] as num?)?.toInt() ?? 0).clamp(0, 100),
      decision: VerificationDecision.fromCode(data['decision'] as String?),
      matched: _stringList(data['matched']),
      contradictions: _stringList(data['contradictions']),
      neutral: data['neutral'] == true,
    );
  }

  static List<String> _stringList(dynamic raw) {
    return (raw as List<dynamic>? ?? const [])
        .map((value) => value.toString())
        .where((value) => value.trim().isNotEmpty)
        .toList();
  }
}

class ItemMatch {
  const ItemMatch({
    required this.id,
    required this.myItemTitle,
    required this.myItemPlace,
    required this.myItemTimeLabel,
    required this.myItemCategory,
    required this.foundItemTitle,
    required this.foundItemPlace,
    required this.foundItemTimeLabel,
    required this.foundItemCategory,
    required this.finderName,
    required this.finderInitials,
    required this.finderReputation,
    required this.finderRecoveredCount,
    required this.scores,
    required this.verificationQuestion,
    required this.minutesAgo,
    this.verification = MatchVerification.pending,
    this.myItemImageUrl,
    this.foundItemImageUrl,
    this.status = 'PENDING',
    this.verificationAttempts = 0,
    this.agreement,
    this.verificationOutcome,
    this.viewerRole = 'owner',
    this.myItemType = ItemType.lost,
    this.otherItemType = ItemType.found,
    this.canChat = true,
    this.chatLockedReason,
    this.lastMessage,
    this.lastMessageAt,
    this.lastMessageIsMine = false,
    this.unreadCount = 0,
  });

  final String id;
  final String myItemTitle;
  final String myItemPlace;
  final String myItemTimeLabel;
  final ItemCategory myItemCategory;

  final String foundItemTitle;
  final String foundItemPlace;
  final String foundItemTimeLabel;
  final ItemCategory foundItemCategory;

  final String finderName;
  final String finderInitials;
  final double finderReputation;
  final int finderRecoveredCount;

  final MatchScores scores;
  final String verificationQuestion;
  final int minutesAgo;
  final MatchVerification verification;

  /// Photo de l'annonce perdue, resolue sur le serveur (null si absente).
  final String? myItemImageUrl;

  /// Photo de l'annonce trouvee, resolue sur le serveur (null si absente).
  final String? foundItemImageUrl;

  /// Statut serveur : PENDING, VERIFIED, CONTACTED, RECOVERED, REJECTED.
  final String status;

  final int verificationAttempts;

  /// Accord textuel calcule par le moteur lors du matching.
  final TextAgreement? agreement;

  /// Derniere evaluation de la reponse du proprietaire, si elle existe.
  final VerificationOutcome? verificationOutcome;

  /// Role de l'utilisateur connecte dans cette correspondance : owner | finder.
  final String viewerRole;

  /// Type de l'annonce de l'utilisateur connecte (perdue ou trouvee).
  final ItemType myItemType;

  /// Type de l'annonce de l'autre partie.
  final ItemType otherItemType;

  /// Le serveur autorise-t-il l'ouverture du chat pour cet utilisateur ?
  final bool canChat;

  /// Raison affichable quand [canChat] est faux.
  final String? chatLockedReason;

  /// Apercu de la derniere conversation.
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final bool lastMessageIsMine;
  final int unreadCount;

  bool get hasConversation => lastMessage != null;

  bool get isVerified =>
      status == 'VERIFIED' || status == 'CONTACTED' || status == 'RECOVERED';

  bool get iAmFinder => viewerRole == 'finder';

  /// Nom de la personne avec qui l'utilisateur connecte discute.
  String get counterpartName => finderName;

  bool get hasVerificationOutcome => verificationOutcome != null;
}

class AppUser {
  const AppUser({
    required this.name,
    required this.email,
    required this.initials,
    required this.reputation,
    required this.recoveredCount,
    this.id = '',
    this.phone = '',
    // La demonstration hors ligne simule un compte deja verifie.
    this.phoneVerified = true,
    this.avatar,
    this.googleId,
  });

  final String id;
  final String name;
  final String email;
  final String initials;
  final double reputation;
  final int recoveredCount;
  final String phone;

  /// Verification du numero (CDC 6.1) : tant que false, l'application
  /// impose l'ecran de code OTP avant tout acces aux services.
  final bool phoneVerified;
  final String? avatar;
  final String? googleId;
}
