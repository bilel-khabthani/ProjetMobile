import 'package:flutter_test/flutter_test.dart';
import 'package:lost_found_ai/core/ai/text_agreement_engine.dart';

void main() {
  const engine = TextAgreementEngine();

  group('TextAgreementEngine.analyze', () {
    test('scores matching descriptions higher than unrelated ones', () {
      final close = engine.analyze(
        'Sac de sport noir avec une bande rouge et un cadenas doré.',
        'Sac noir trouvé avec une bande rouge et un cadenas doré.',
      );
      final far = engine.analyze(
        'Sac de sport noir avec une bande rouge et un cadenas doré.',
        'Trousseau de clés avec un porte-clés vert.',
      );

      expect(close.score, greaterThan(70));
      expect(far.score, lessThan(close.score));
      expect(close.shared, contains('bande'));
      expect(close.shared, contains('rouge'));
    });

    test('flags contradicting colors', () {
      final result = engine.analyze(
        'Sac noir avec une bande rouge.',
        'Sac blanc avec une bande bleue.',
      );

      expect(result.contradictions, isNotEmpty);
      final text = result.contradictions.join(' | ');
      expect(text, contains('blanc'));
      expect(text, contains('rouge'));
    });

    test('returns an empty agreement when a side has no significant word', () {
      final result = engine.analyze('le la les', 'sac noir');

      expect(result.score, 0);
      expect(result.shared, isEmpty);
    });

    test('normalizes accents and plurals', () {
      final accents = engine.analyze(
        'Téléphone noir avec un cadenas',
        'telephone noir avec un cadenas',
      );
      final plurals = engine.analyze('bandes rouges', 'bande rouge');

      expect(accents.shared, contains('telephone'));
      expect(accents.shared, contains('cadena'));
      expect(plurals.shared, contains('bande'));
    });
  });

  group('TextAgreementEngine.scoreAnswer', () {
    test('accepts an answer matching the secret detail', () {
      final result = engine.scoreAnswer(
        'Il a une bande rouge et un cadenas doré.',
        'bande rouge et cadenas doré',
      );

      expect(result.decision, 'YES');
      expect(result.matched, contains('bande'));
      expect(result.neutral, isFalse);
    });

    test('rejects a contradicting answer', () {
      final result = engine.scoreAnswer(
        'Il est blanc avec une bande verte.',
        'bande rouge et cadenas doré',
      );

      expect(result.decision, isNot('YES'));
      expect(result.contradictions, isNotEmpty);
    });

    test('stays neutral without a secret detail', () {
      final result = engine.scoreAnswer('n importe quoi', null);

      expect(result.neutral, isTrue);
      expect(result.decision, 'UNSURE');
    });

    test('rejects an empty answer when a secret exists', () {
      final result = engine.scoreAnswer('   ', 'bande rouge');

      expect(result.decision, 'NO');
      expect(result.score, 0);
    });
  });
}
