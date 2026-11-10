/// Resume du score de confiance de l'utilisateur (Module 4).
class TrustSummary {
  const TrustSummary({
    required this.score,
    required this.recoveredCount,
    required this.canChat,
    required this.inProbation,
    required this.history,
    this.canCoordinate = false,
    this.minScoreToChat = 40,
    this.minScoreToCoordinate = 30,
  });

  /// Valeur de 0 a 100, plafonnee par le backend.
  final double score;

  final int recoveredCount;

  /// Le chat complet s'ouvre au-dessus du seuil de confiance.
  final bool canChat;

  /// Le mode coordination (5 messages par correspondance) est disponible.
  final bool canCoordinate;

  final int minScoreToChat;
  final int minScoreToCoordinate;

  /// true si le compte est encore en periode de probation.
  final bool inProbation;

  final List<TrustEvent> history;

  bool get isLocked => !canChat && !canCoordinate;
}

/// Un evenement de score tel qu'affiche dans l'historique.
class TrustEvent {
  const TrustEvent({
    required this.label,
    required this.points,
    required this.at,
    required this.automatic,
    this.id = '',
    this.appealStatus,
    this.canAppeal = false,
  });

  final String id;

  final String label;

  /// Variation : positive pour un gain, negative pour une sanction.
  final int points;

  final DateTime at;

  /// true si l'evenement a ete genere par une regle systeme et non par un
  /// arbitrage humain. Le CDC interdit l'auto-declaration du score.
  final bool automatic;

  /// Statut de l'appel eventuel : OUVERTE, RESOLUE, CLOTUREE.
  final String? appealStatus;

  /// Vrai si l'utilisateur peut encore contester cette sanction.
  final bool canAppeal;

  bool get isSanction => points < 0;

  bool get hasAppeal => appealStatus != null;
}
