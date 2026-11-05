import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router.dart';
import 'core/theme/app_theme.dart';
import 'data/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFFFBF7F0),
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Restaure une session deja ouverte (jeton persiste + GET /me) avant le
  // premier rendu : l'utilisateur connecte arrive directement sur l'accueil.
  final container = ProviderContainer();
  await container.read(sessionProvider.notifier).restore();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const LostAndFoundApp(),
    ),
  );
}

class LostAndFoundApp extends ConsumerWidget {
  const LostAndFoundApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Lost&Found AI',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
