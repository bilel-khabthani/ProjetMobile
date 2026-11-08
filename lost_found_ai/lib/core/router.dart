import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/models/item.dart';
import '../data/providers.dart';
import '../features/auth/forgot_password_screen.dart';
import '../features/auth/sign_in_screen.dart';
import '../features/auth/sign_up_screen.dart';
import '../features/auth/verify_phone_screen.dart';
import '../features/auth/welcome_screen.dart';
import '../features/claim/claim_screen.dart';
import '../features/home/home_screen.dart';
import '../features/match/match_detail_screen.dart';
import '../features/objects/item_detail_screen.dart';
import '../features/objects/objects_screen.dart';
import '../features/objects/presentation/screens/map_selection_screen.dart';
import '../features/objects/presentation/screens/my_objects_screen.dart';
import '../features/objects/presentation/screens/object_detail_screen.dart';
import '../features/objects/presentation/screens/object_form_screen.dart';
import '../features/objects/presentation/screens/objects_dashboard_screen.dart';
import '../features/objects/presentation/screens/objects_list_screen.dart';
import '../features/objects/presentation/screens/objects_map_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/publish/publish_screen.dart';
import '../features/rewards/reward_screen.dart';
import '../features/swipe/swipe_screen.dart';
import '../features/trust/trust_screen.dart';

abstract final class AppRoutes {
  // ── Auth ────────────────────────────────────────────────────────────────
  static const String onboarding = '/onboarding';
  static const String welcome = '/welcome';
  static const String signUp = '/sign-up';
  static const String signIn = '/sign-in';
  static const String verifyPhone = '/verify-phone';
  static const String forgotPassword = '/forgot-password';

  // ── Main ─────────────────────────────────────────────────────────────────
  static const String home = '/home';
  static const String publish = '/publish';
  static const String trust = '/trust';
  static const String rewards = '/rewards';
  static const String swipe = '/swipe';
  static const String profile = '/profile';

  // ── Matching & Chat ───────────────────────────────────────────────────────
  static const String match = '/match/:id';
  static const String claim = '/claim';
  static const String claimWithId = '/claim/:id';

  // ── Objects module ────────────────────────────────────────────────────────
  static const String objects = '/objects';
  static const String objectsDashboard = '/objects/dashboard';
  static const String objectsList = '/objects/list';
  static const String objectsAdd = '/objects/add';
  static const String myObjects = '/my-objects';
  static const String objectMyList = '/my-objects';
  static const String map = '/map';
  static const String objectsMap = '/map';
  static const String objectsMapSelection = '/objects-map/select';

  /// Item detail (uses existing /items/:id backend route).
  static const String item = '/items/:id';

  // ── Helpers ───────────────────────────────────────────────────────────────
  static String matchDetail(String id) => '/match/$id';
  static String claimDetail([String? id]) =>
      id == null ? '/claim' : '/claim/$id';
  static String objectDetail(String id) => '/objects/$id';
  static String objectEdit(String id) => '/objects/$id/edit';
  static String itemDetail(String id) => '/items/$id';
  static String editItem(String id) => '/publish?edit=$id';
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
      // ── Auth ──────────────────────────────────────────────────────────────
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

      // ── Main ──────────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.publish,
        builder: (context, state) {
          final type = state.uri.queryParameters['type'];
          final edit = state.uri.queryParameters['edit'];
          return PublishScreen(
            initialType: type == 'found' ? ItemType.found : ItemType.lost,
            itemId: edit,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.trust,
        builder: (context, state) => const TrustScreen(),
      ),
      GoRoute(
        path: AppRoutes.rewards,
        builder: (context, state) => const RewardScreen(),
      ),
      GoRoute(
        path: AppRoutes.swipe,
        builder: (context, state) => const SwipeScreen(),
      ),
      GoRoute(
        path: AppRoutes.profile,
        builder: (context, state) => const ProfileScreen(),
      ),

      // ── Matching & Claims ─────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.match,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? 'match-sac';
          return MatchDetailScreen(matchId: id);
        },
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

      // ── Objects module ────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.objects,
        builder: (context, state) {
          final type = state.uri.queryParameters['type'];
          return ObjectsScreen(
            initialType: type == 'found' ? ItemType.found : ItemType.lost,
          );
        },
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
        path: AppRoutes.objectsAdd,
        builder: (context, state) {
          final type = state.uri.queryParameters['type'];
          return ObjectFormScreen(
            initialType: type == 'found' ? ItemType.found : ItemType.lost,
          );
        },
      ),
      GoRoute(
        path: '/objects/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return ObjectDetailScreen(objectId: id);
        },
      ),
      GoRoute(
        path: '/objects/:id/edit',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return ObjectFormScreen(objectId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.myObjects,
        builder: (context, state) => const MyObjectsScreen(),
      ),
      GoRoute(
        path: AppRoutes.map,
        builder: (context, state) => const ObjectsMapScreen(),
      ),
      GoRoute(
        path: AppRoutes.objectsMapSelection,
        builder: (context, state) => const MapSelectionScreen(),
      ),

      // ── Item detail (legacy route used by home_screen matches) ────────────
      GoRoute(
        path: AppRoutes.item,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return ItemDetailScreen(itemId: id);
        },
      ),
    ],
  );
});
