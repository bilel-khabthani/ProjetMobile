import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router.dart';
import '../theme/app_theme.dart';
import '../../widgets/app_icon.dart';

class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onDestinationSelected(BuildContext context, int index) {
    if (index == 2) {
      context.push(AppRoutes.publish);
      return;
    }

    final branchIndex = index > 2 ? index - 1 : index;
    navigationShell.goBranch(
      branchIndex,
      initialLocation: branchIndex == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final selectedIndex = navigationShell.currentIndex > 1
        ? navigationShell.currentIndex + 1
        : navigationShell.currentIndex;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) =>
            _onDestinationSelected(context, index),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          NavigationDestination(
            icon: AppIcon('home-2-linear', color: scheme.onSurfaceVariant),
            selectedIcon: AppIcon(
              'home-2-bold',
              color: scheme.onSecondaryContainer,
            ),
            label: 'Accueil',
          ),
          NavigationDestination(
            icon: AppIcon('box-linear', color: scheme.onSurfaceVariant),
            selectedIcon: AppIcon(
              'box-linear',
              color: scheme.onSecondaryContainer,
            ),
            label: 'Objets',
          ),
          NavigationDestination(
            icon: AppIcon('add-circle-bold', color: scheme.onSurfaceVariant),
            selectedIcon: AppIcon(
              'add-circle-bold',
              color: scheme.onSecondaryContainer,
            ),
            label: 'Ajouter',
          ),
          NavigationDestination(
            icon: AppIcon('chat-round-linear', color: scheme.onSurfaceVariant),
            selectedIcon: AppIcon(
              'chat-round-bold',
              color: scheme.onSecondaryContainer,
            ),
            label: 'Matchs',
            tooltip: 'Correspondances',
          ),
          NavigationDestination(
            icon: AppIcon('user-linear', color: scheme.onSurfaceVariant),
            selectedIcon: AppIcon(
              'user-bold',
              color: scheme.onSecondaryContainer,
            ),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
