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
    final hasPurchase = matrix.contains('purchase:read');
    final hasSales = matrix.contains('sales:read');

    // Indexed by shell branch: 0 Dashboard, 1 Inventory, 2 Purchase, 3 Sales, 4 Settings.
    const allDestinations = [
      NavigationDestination(icon: Icon(Icons.grid_view_rounded), selectedIcon: Icon(Icons.grid_view_rounded), label: 'Dashboard'),
      NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'Inventory'),
      NavigationDestination(icon: Icon(Icons.local_shipping_outlined), selectedIcon: Icon(Icons.local_shipping), label: 'Purchase'),
      NavigationDestination(icon: Icon(Icons.shopping_cart_outlined), selectedIcon: Icon(Icons.shopping_cart), label: 'Sales'),
      NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
    ];

    final branchMap = [
      0,
      1,
      if (hasPurchase) 2,
      if (hasSales) 3,
      4,
    ];
    final destinations = [for (final b in branchMap) allDestinations[b]];

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
