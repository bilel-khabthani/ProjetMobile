/// Resume du score de confiance de l'utilisateur (Module 4).
class TrustSummary {
  const TrustSummary({
    required this.score,
    required this.recoveredCount,
    required this.canChat,
    required this.inProbation,
    required this.history,
  });

  /// Valeur de 0 a 100, plafonnee par le backend.
  final double score;

  final int recoveredCount;

  /// Le chat ne s'ouvre qu'au-dessus d'un seuil de confiance.
  final bool canChat;

  /// true si le compte est encore en periode de probation.
  final bool inProbation;

  final List<TrustEvent> history;
}

/// Un evenement de score tel qu'affiche dans l'historique.
class TrustEvent {
  const TrustEvent({
    required this.label,
    required this.points,
    required this.at,
    required this.automatic,
  });

  final String label;

  /// Variation : positive pour un gain, negative pour une sanction.
  final int points;

  final DateTime at;

  /// true si l'evenement a ete genere par une regle systeme et non par un
  /// arbitrage humain. Le CDC interdit l'auto-declaration du score.
  final bool automatic;
}