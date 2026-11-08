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
    this.status = 'PENDING',
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

  /// Statut serveur : PENDING, VERIFIED, CONTACTED, RECOVERED, REJECTED.
  final String status;

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
  });

  /// Identifiant serveur : sert notamment a distinguer ses propres messages.
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
}
