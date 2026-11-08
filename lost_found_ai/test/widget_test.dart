import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lost_found_ai/core/app_strings.dart';
import 'package:lost_found_ai/main.dart';

void main() {
  testWidgets('onboarding renders the first slide', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: LostAndFoundApp()));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text(AppStrings.onboardingNext), findsOneWidget);
    expect(find.text('Vous avez perdu quelque chose ?'), findsOneWidget);
  });

  testWidgets('onboarding navigates to welcome after the last slide', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: LostAndFoundApp()));
    await tester.pump(const Duration(milliseconds: 600));

    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text(AppStrings.onboardingNext));
      await tester.pumpAndSettle();
    }

    expect(find.text(AppStrings.onboardingStart), findsOneWidget);

    await tester.tap(find.text(AppStrings.onboardingStart));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.createAccount), findsOneWidget);
    expect(find.text(AppStrings.signIn), findsOneWidget);
  });
}
