/// Moteur local d'accord textuel en francais.
///
/// Meme logique que `TextAgreementService` cote Laravel : recouvrement de mots
/// significatifs (Dice), couverture du texte le plus court et similarite de
/// bigrammes. Il permet a l'application de produire une analyse instantanee,
/// explicable et hors ligne, sans modele embarque ni appel reseau.
class TextAgreementEngine {
  const TextAgreementEngine();

  static const Set<String> _stopWords = {
    'a', 'au', 'aux', 'avec', 'ce', 'cet', 'cette', 'ces', 'dans', 'de', 'des',
    'du', 'elle', 'en', 'est', 'et', 'eux', 'il', 'ils', 'je', 'la', 'le', 'les',
    'leur', 'leurs', 'lui', 'ma', 'mais', 'me', 'mes', 'moi', 'mon', 'ne', 'nos',
    'notre', 'nous', 'on', 'ou', 'par', 'pas', 'pour', 'qu', 'que', 'qui', 'sa',
    'se', 'ses', 'son', 'sur', 'sous', 'ta', 'te', 'tes', 'toi', 'ton', 'tu',
    'un', 'une', 'vos', 'votre', 'vous', 'y', 'd', 'l', 's', 't', 'n', 'j', 'm',
    'c', 'ete', 'etre', 'trouve', 'trouvee', 'trouves', 'trouvees', 'perdu',
    'perdue', 'perdus', 'perdues', 'annonce', 'annonces', 'objet', 'objets',
    'pres', 'vers', 'environ', 'semble', 'semblent', 'ressemble', 'ressemblent',
    'contient', 'contenait', 'sans', 'plus', 'moins', 'tres', 'bien', 'peu',
    'tout', 'tous', 'toute', 'toutes', 'aussi', 'comme', 'autre', 'autres',
    'celui', 'celle', 'ceux', 'celles', 'dont', 'alors', 'donc', 'apres',
    'depuis', 'pendant', 'entre', 'chez', 'ici', 'voici', 'voila', 'etait',
    'etaient', 'avoir', 'ai', 'as', 'ont', 'suis', 'es', 'sommes', 'etes', 'sont',
    'peut', 'peuvent', 'pouvoir', 'fait', 'faire',
  };

  static const Map<String, List<String>> _opposites = {
    'noir': ['blanc', 'blanche', 'claire'],
    'blanc': ['noir', 'noire', 'fonce'],
    'rouge': ['bleu', 'bleue', 'vert', 'verte'],
    'bleu': ['rouge', 'vert', 'verte'],
    'vert': ['rouge', 'bleu', 'bleue'],
    'dore': ['argente'],
    'argente': ['dore'],
    'grand': ['petit', 'petite'],
    'petit': ['grand', 'grande'],
    'gauche': ['droite'],
    'droite': ['gauche'],
    'devant': ['derriere'],
    'derriere': ['devant'],
    'interieur': ['exterieur'],
    'exterieur': ['interieur'],
    'ouvert': ['ferme', 'fermee'],
    'ferme': ['ouvert', 'ouverte'],
    'neuf': ['casse', 'raye', 'abime'],
    'casse': ['neuf'],
    'cuir': ['tissu', 'plastique'],
    'tissu': ['cuir', 'plastique'],
    'plastique': ['cuir', 'tissu', 'metal'],
    'metal': ['plastique'],
    'matin': ['soir', 'soiree'],
    'soir': ['matin'],
    'avant': ['apres'],
    'apres': ['avant'],
  };

  static const List<String> _distinctive = [
    'noir', 'blanc', 'rouge', 'bleu', 'vert', 'jaune', 'gris', 'marron',
    'beige', 'rose', 'violet', 'orange', 'dore', 'argente', 'transparent',
    'cuir', 'tissu', 'plastique', 'metal', 'bois', 'verre', 'nylon', 'coton',
    'sac', 'telephone', 'cle', 'portefeuille', 'lunette', 'vetement', 'papier',
    'montre', 'chargeur', 'ecouteur', 'gourde', 'bouteille', 'parapluie',
    'casque', 'carte', 'trousseau',
    'bande', 'rayure', 'raye', 'logo', 'poche', 'zip', 'fermeture', 'cadenas',
    'dragonne', 'autocollant', 'etui', 'coque', 'fissure', 'badge', 'brode',
    'inscription', 'initiales', 'etiquette', 'porte-cle', 'serviette',
    'grand', 'petit', 'moyen', 'large', 'fin', 'epais', 'gauche', 'droite',
  ];

  static const Map<String, String> _accents = {
    'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', 'ã': 'a', 'å': 'a',
    'ç': 'c',
    'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
    'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
    'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
    'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u',
    'ÿ': 'y', 'ñ': 'n',
    'œ': 'oe', 'æ': 'ae',
  };

  static const Set<String> _invariables = {
    'gris', 'bois', 'mois', 'pays', 'tapis', 'cours', 'temps', 'corps', 'bras',
    'pas', 'repas', 'cas', 'bas', 'os', 'dos', 'trois', 'voix', 'noix', 'prix',
    'deux', 'cheveux', 'yeux', 'cieux', 'voeux', 'fils', 'sens', 'divers',
  };

  /// Compare deux descriptions libres.
  TextAgreement analyze(String left, String right) {
    final leftNormalized = _normalize(left);
    final rightNormalized = _normalize(right);
    final leftTokens = _tokens(leftNormalized);
    final rightTokens = _tokens(rightNormalized);

    if (leftTokens.isEmpty || rightTokens.isEmpty) {
      return TextAgreement.empty;
    }

    final shared = leftTokens.intersection(rightTokens).toList()
      ..sort(_byDistinctive);
    final contradictions = _contradictions(leftTokens, rightTokens);

    final dice = _dice(leftTokens, rightTokens);
    final coverage = _coverage(leftTokens, rightTokens);
    final bigram = _bigramSimilarity(leftNormalized, rightNormalized);

    var score = (0.45 * dice + 0.35 * coverage + 0.20 * bigram) * 100;
    score += shared.length * 2 > 12 ? 12 : shared.length * 2;

    if (leftNormalized.isNotEmpty &&
        rightNormalized.isNotEmpty &&
        (leftNormalized.contains(rightNormalized) ||
            rightNormalized.contains(leftNormalized))) {
      score = score < 88 ? 88 : score;
    }

    score -= contradictions.length * 12 > 30 ? 30 : contradictions.length * 12;

    return TextAgreement(
      score: _clamp(score),
      shared: shared.take(6).toList(growable: false),
      contradictions: contradictions.take(4).toList(growable: false),
    );
  }

  /// Compare la reponse libre du proprietaire au detail secret.
  AnswerAgreement scoreAnswer(String answer, String? secretDetail) {
    final secret = (secretDetail ?? '').trim();
    final candidate = answer.trim();

    if (secret.isEmpty) {
      return const AnswerAgreement(
        score: 50,
        decision: 'UNSURE',
        matched: [],
        contradictions: [],
        neutral: true,
      );
    }

    if (candidate.isEmpty) {
      return const AnswerAgreement(
        score: 0,
        decision: 'NO',
        matched: [],
        contradictions: [],
      );
    }

    final agreement = analyze(secret, candidate);
    final decision = agreement.score >= 65
        ? 'YES'
        : agreement.score >= 32
        ? 'UNSURE'
        : 'NO';

    return AnswerAgreement(
      score: agreement.score,
      decision: decision,
      matched: agreement.shared,
      contradictions: agreement.contradictions,
    );
  }

  String _normalize(String text) {
    var value = text.trim().toLowerCase();
    _accents.forEach((from, to) {
      value = value.replaceAll(from, to);
    });
    value = value.replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  Set<String> _tokens(String normalized) {
    final tokens = <String>{};

    for (final word in normalized.split(RegExp(r'[^a-z0-9]+'))) {
      if (word.isEmpty) continue;

      if (RegExp(r'^[0-9]+$').hasMatch(word)) {
        if (word.length >= 2) tokens.add(word);
        continue;
      }

      if (word.length < 3 || _stopWords.contains(word)) continue;
      tokens.add(_singularize(word));
    }

    return tokens;
  }

  String _singularize(String word) {
    if (_invariables.contains(word)) return word;
    if (word.length > 4 && (word.endsWith('s') || word.endsWith('x'))) {
      return word.substring(0, word.length - 1);
    }
    return word;
  }

  int _byDistinctive(String left, String right) {
    final leftIndex = _distinctive.indexOf(left);
    final rightIndex = _distinctive.indexOf(right);
    final leftPriority = leftIndex < 0 ? 1000 : leftIndex;
    final rightPriority = rightIndex < 0 ? 1000 : rightIndex;

    final byPriority = leftPriority.compareTo(rightPriority);
    return byPriority != 0 ? byPriority : left.compareTo(right);
  }

  double _dice(Set<String> left, Set<String> right) {
    final total = left.length + right.length;
    if (total == 0) return 0;
    return (2 * left.intersection(right).length) / total;
  }

  double _coverage(Set<String> left, Set<String> right) {
    final shortest = left.length < right.length ? left.length : right.length;
    if (shortest == 0) return 0;
    return left.intersection(right).length / shortest;
  }

  List<String> _contradictions(Set<String> left, Set<String> right) {
    final result = <String>{};

    _opposites.forEach((word, opposites) {
      if (!left.contains(word)) return;

      for (final opposite in opposites) {
        if (!right.contains(opposite)) continue;
        final pair = [word, opposite]..sort();
        result.add(pair.join(' ↔ '));
      }
    });

    return result.toList(growable: false);
  }

  double _bigramSimilarity(String left, String right) {
    final a = left.replaceAll(RegExp(r'[^a-z0-9]'), '');
    final b = right.replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (a.isEmpty || b.isEmpty) return 0;

    final leftGrams = _bigrams(a);
    final rightGrams = _bigrams(b);
    final total = leftGrams.length + rightGrams.length;
    if (total == 0) return 0;

    final rightSet = rightGrams.toSet();
    final intersection = leftGrams.where(rightSet.contains).length;
    return (2 * intersection) / total;
  }

  List<String> _bigrams(String value) {
    if (value.length < 2) return [value];
    return [
      for (var index = 0; index < value.length - 1; index++)
        value.substring(index, index + 2),
    ];
  }

  int _clamp(num value) => value.round().clamp(0, 100).toInt();
}

/// Resultat d'une comparaison entre deux descriptions.
class TextAgreement {
  const TextAgreement({
    required this.score,
    required this.shared,
    required this.contradictions,
  });

  final int score;
  final List<String> shared;
  final List<String> contradictions;

  static const TextAgreement empty = TextAgreement(
    score: 0,
    shared: [],
    contradictions: [],
  );
}

/// Resultat de la comparaison reponse / detail secret.
class AnswerAgreement {
  const AnswerAgreement({
    required this.score,
    required this.decision,
    required this.matched,
    required this.contradictions,
    this.neutral = false,
  });

  final int score;
  final String decision;
  final List<String> matched;
  final List<String> contradictions;
  final bool neutral;

  bool get accepted => decision == 'YES';
  bool get partial => decision == 'UNSURE';
}
