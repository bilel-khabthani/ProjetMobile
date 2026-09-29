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
}

class AppUser {
  const AppUser({
    required this.name,
    required this.email,
    required this.initials,
    required this.reputation,
    required this.recoveredCount,
  });

  final String name;
  final String email;
  final String initials;
  final double reputation;
  final int recoveredCount;
}
