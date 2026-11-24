import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_found_ai/core/theme/app_motion.dart';
import 'package:lost_found_ai/widgets/app_reveal.dart';

void main() {
  group('AppMotion', () {
    test('stagger starts at zero and clamps to the last visible item', () {
      expect(AppMotion.stagger(0), Duration.zero);
      expect(AppMotion.stagger(3), const Duration(milliseconds: 165));
      expect(AppMotion.stagger(99), const Duration(milliseconds: 275));
    });

    testWidgets('motion() honors reduced motion from MediaQuery', (tester) async {
      late bool reduced;
      late Duration duration;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Builder(
            builder: (context) {
              reduced = context.reduceMotion;
              duration = context.motion(AppMotion.medium);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(reduced, isTrue);
      expect(duration, Duration.zero);
    });
  });

  group('AppReveal', () {
    testWidgets('skips the animation when reduced motion is enabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: AppReveal(index: 4, child: Text('Révélé')),
          ),
        ),
      );

      expect(find.text('Révélé'), findsOneWidget);
      expect(
        find.byWidgetPredicate((widget) => widget is TweenAnimationBuilder),
        findsNothing,
      );
    });

    testWidgets('uses a staggered transition otherwise', (tester) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: false),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: AppReveal(index: 2, child: Text('Animé')),
          ),
        ),
      );

      expect(find.text('Animé'), findsOneWidget);
      expect(
        find.byWidgetPredicate((widget) => widget is TweenAnimationBuilder),
        findsOneWidget,
      );
    });
  });
}
