import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../design/app_colors.dart';
import '../../features/auth/presentation/controllers/permission_controller.dart';

class BottomNavShell extends ConsumerWidget {
  const BottomNavShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matrix = ref.watch(permissionMatrixProvider).value ?? <String>{};
    final hasSales = matrix.contains('sales:read');

    const allDestinations = [
      NavigationDestination(icon: Icon(Icons.grid_view_rounded), selectedIcon: Icon(Icons.grid_view_rounded), label: 'Dashboard'),
      NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'Inventory'),
      NavigationDestination(icon: Icon(Icons.shopping_cart_outlined), selectedIcon: Icon(Icons.shopping_cart), label: 'Sales'),
      NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
    ];

    final branchMap = hasSales ? [0, 1, 2, 3] : [0, 1, 3];
    final destinations = hasSales ? allDestinations : [allDestinations[0], allDestinations[1], allDestinations[3]];

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.separator, width: 0.5)),
        ),
        child: NavigationBar(
          selectedIndex: branchMap.indexOf(navigationShell.currentIndex),
          onDestinationSelected: (i) => navigationShell.goBranch(branchMap[i], initialLocation: i == branchMap.indexOf(navigationShell.currentIndex)),
          backgroundColor: AppColors.background,
          indicatorColor: AppColors.accent.withValues(alpha: 0.12),
          destinations: destinations,
        ),
      ),
    );
  }
}
