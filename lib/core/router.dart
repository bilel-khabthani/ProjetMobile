import 'package:go_router/go_router.dart';

import '../features/auth/sign_in_screen.dart';
import '../features/auth/sign_up_screen.dart';
import '../features/auth/welcome_screen.dart';
import '../features/home/home_screen.dart';
import '../features/match/match_detail_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/publish/publish_screen.dart';

abstract final class AppRoutes {
  static const String onboarding = '/onboarding';
  static const String welcome = '/welcome';
  static const String signUp = '/sign-up';
  static const String signIn = '/sign-in';
  static const String home = '/home';
  static const String publish = '/publish';
  static const String match = '/match/:id';

  static String matchDetail(String id) => '/match/$id';
}

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.onboarding,
  routes: [
    GoRoute(
      path: AppRoutes.onboarding,
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: AppRoutes.welcome,
      builder: (context, state) => const WelcomeScreen(),
    ),
    GoRoute(
      path: AppRoutes.signUp,
      builder: (context, state) => const SignUpScreen(),
    ),
    GoRoute(
      path: AppRoutes.signIn,
      builder: (context, state) => const SignInScreen(),
    ),
    GoRoute(
      path: AppRoutes.home,
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: AppRoutes.publish,
      builder: (context, state) => const PublishScreen(),
    ),
    GoRoute(
      path: AppRoutes.match,
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? 'match-sac';
        return MatchDetailScreen(matchId: id);
      },
    ),
  ],
);
