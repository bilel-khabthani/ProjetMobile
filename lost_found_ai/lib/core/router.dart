import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/models/item.dart';
import '../data/providers.dart';
import '../features/activity/activity_screen.dart';
import '../features/auth/forgot_password_screen.dart';
import '../features/auth/sign_in_screen.dart';
import '../features/auth/sign_up_screen.dart';
import '../features/auth/verify_phone_screen.dart';
import '../features/auth/welcome_screen.dart';
import '../features/claim/claim_screen.dart';
import '../features/chat/chat_screen.dart';
import '../features/explore/explore_screen.dart';
import '../features/home/home_screen.dart';
import '../features/match/match_detail_screen.dart';
import '../features/messages/messages_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/publish/publish_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/trust/trust_screen.dart';
import '../features/objects/presentation/screens/objects_dashboard_screen.dart';
import '../features/objects/presentation/screens/objects_list_screen.dart';
import '../features/objects/presentation/screens/objects_map_screen.dart';
import '../features/objects/presentation/screens/map_selection_screen.dart';
import '../features/objects/presentation/screens/my_objects_screen.dart';
import '../features/objects/presentation/screens/object_detail_screen.dart';
import '../features/objects/presentation/screens/object_form_screen.dart';

abstract final class AppRoutes {
  static const String onboarding = '/onboarding';
  static const String welcome = '/welcome';
  static const String signUp = '/sign-up';
  static const String signIn = '/sign-in';
  static const String verifyPhone = '/verify-phone';
  static const String forgotPassword = '/forgot-password';
  static const String home = '/home';
  static const String explore = '/explore';
  static const String messages = '/messages';
  static const String activity = '/activity';
  static const String publish = '/publish';
  static const String match = '/match/:id';
  static const String chat = '/chat/:id';
  static const String trust = '/trust';
  static const String claim = '/claim';
  static const String claimWithId = '/claim/:id';
  static const String profile = '/profile';

  // Gestion des objets perdus / trouves.
  static const String objectsDashboard = '/objects';
  static const String objectsList = '/objects/list';
  static const String objectsMap = '/objects/map';
  static const String objectsMapSelection = '/objects/map-selection';
  static const String objectAdd = '/objects/add';
  static const String objectMyList = '/objects/my-list';

  static String objectDetail(String id) => '/objects/$id';
  static String objectEdit(String id) => '/objects/edit/$id';

  static String matchDetail(String id) => '/match/$id';
  static String chatDetail(String id) => '/chat/$id';
  static String claimDetail([String? id]) =>
      id == null ? '/claim' : '/claim/$id';
}

/// Ecrans atteignables sans session (parcours d'authentification).
const Set<String> _publicPaths = {
  AppRoutes.onboarding,
  AppRoutes.welcome,
  AppRoutes.signUp,
  AppRoutes.signIn,
  AppRoutes.forgotPassword,
};

/// Routeur garde par la session : toute route protegee redirige vers
/// l'accueil si l'utilisateur n'est pas connecte (et inversement), et un
/// changement de session (connexion / deconnexion / restauration) redeclenche
/// l'evaluation des redirections sans reconstruire le routeur.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(sessionProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: AppRoutes.onboarding,
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      final loggedIn = session != null;
      final needsVerify = loggedIn && !session.phoneVerified;
      final location = state.matchedLocation;

      if (!loggedIn) {
        return _publicPaths.contains(location) ? null : AppRoutes.welcome;
      }
      // CDC 6.1 : le numero non verifie impose l'ecran OTP ; ce n'est qu'une
      // fois le code valide que le reste de l'application devient accessible.
      if (location == AppRoutes.verifyPhone) {
        return needsVerify ? null : AppRoutes.home;
      }
      if (needsVerify) return AppRoutes.verifyPhone;
      if (_publicPaths.contains(location)) return AppRoutes.home;
      return null;
    },
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
        path: AppRoutes.verifyPhone,
        builder: (context, state) => const VerifyPhoneScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.explore,
        builder: (context, state) => const ExploreScreen(),
      ),
      GoRoute(
        path: AppRoutes.messages,
        builder: (context, state) => const MessagesScreen(),
      ),
      GoRoute(
        path: AppRoutes.activity,
        builder: (context, state) => const ActivityScreen(),
      ),
      GoRoute(
        path: AppRoutes.publish,
        builder: (context, state) {
          final type = state.uri.queryParameters['type'];
          return PublishScreen(
            initialType: type == 'found' ? ItemType.found : ItemType.lost,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.match,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? 'match-sac';
          return MatchDetailScreen(matchId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.chat,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return ChatScreen(matchId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.trust,
        builder: (context, state) => const TrustScreen(),
      ),
      GoRoute(
        path: AppRoutes.claim,
        builder: (context, state) => const ClaimScreen(),
      ),
      GoRoute(
        path: AppRoutes.claimWithId,
        builder: (context, state) {
          final id = state.pathParameters['id'];
          return ClaimScreen(matchId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.profile,
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.objectsDashboard,
        builder: (context, state) => const ObjectsDashboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.objectsList,
        builder: (context, state) => const ObjectsListScreen(),
      ),
      GoRoute(
        path: AppRoutes.objectsMap,
        builder: (context, state) => const ObjectsMapScreen(),
      ),
      GoRoute(
        path: AppRoutes.objectsMapSelection,
        builder: (context, state) => const MapSelectionScreen(),
      ),
      GoRoute(
        path: AppRoutes.objectMyList,
        builder: (context, state) => const MyObjectsScreen(),
      ),
      GoRoute(
        path: AppRoutes.objectAdd,
        builder: (context, state) {
          final typeParam = state.uri.queryParameters['type'];
          final initialType =
              typeParam == 'found' ? ItemType.found : ItemType.lost;
          return ObjectFormScreen(initialType: initialType);
        },
      ),
      GoRoute(
        path: '/objects/edit/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return ObjectFormScreen(objectId: id);
        },
      ),
      GoRoute(
        path: '/objects/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return ObjectDetailScreen(objectId: id);
        },
      ),
    ],
  );
});
