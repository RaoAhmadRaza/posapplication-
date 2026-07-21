import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../features/dashboard/presentation/widgets/dashboard_app_bar.dart'
    show searchFieldKey;
import '../design/app_colors.dart';
import '../design/app_motion.dart';
import '../design/app_radius.dart';
import '../design/app_typography.dart';
import '../design/clay.dart';
import '../design/widgets/lumina_brand.dart';
import '../../features/auth/presentation/controllers/permission_controller.dart';
import '../../features/auth/presentation/controllers/profile_controller.dart';

/// Width at or above which the nav becomes a persistent left rail. Below it the
/// nav is a bottom bar. Width-driven, never Platform.isX — desktop windows resize.
const _kRailBreakpoint = 900.0;

/// One nav destination. Indexes match the router's shell branch order.
class _NavItem {
  const _NavItem(this.label, this.icon);
  final String label;
  final IconData icon;
}

// Indexed by shell branch: 0 Dashboard, 1 Inventory, 2 Purchase, 3 Sales, 4 Settings.
const _allItems = [
  _NavItem('Dashboard', LucideIcons.layoutGrid),
  _NavItem('Inventory', LucideIcons.box),
  _NavItem('Purchase', LucideIcons.truck),
  _NavItem('Sales', LucideIcons.shoppingCart),
  _NavItem('Settings', LucideIcons.settings),
];

class BottomNavShell extends ConsumerWidget {
  const BottomNavShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matrix = ref.watch(permissionMatrixProvider).value ?? <String>{};
    final hasPurchase = matrix.contains('purchase:read');
    final hasSales = matrix.contains('sales:read');

    final branchMap = [
      0,
      1,
      if (hasPurchase) 2,
      if (hasSales) 3,
      4,
    ];
    final items = [for (final b in branchMap) _allItems[b]];
    final selected = branchMap.indexOf(navigationShell.currentIndex);

    void onSelect(int i) => navigationShell.goBranch(
          branchMap[i],
          initialLocation: i == selected,
        );

    return CallbackShortcuts(
      bindings: {
        // Both, so the same binding works on macOS and Windows/Linux.
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
            _focusSearch,
        const SingleActivator(LogicalKeyboardKey.keyK, control: true):
            _focusSearch,
      },
      child: Focus(
        autofocus: true,
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= _kRailBreakpoint) {
              return Scaffold(
                body: Row(
                  children: [
                    _NavRail(
                        items: items, selected: selected, onSelect: onSelect),
                    Expanded(child: navigationShell),
                  ],
                ),
              );
            }
            return Scaffold(
              body: navigationShell,
              bottomNavigationBar: _LuminaBottomBar(
                items: items,
                selected: selected,
                onSelect: onSelect,
              ),
            );
          },
        ),
      ),
    );
  }

  /// No-ops unless the dashboard (the only screen with the field) is mounted.
  static void _focusSearch() =>
      searchFieldKey.currentState?.focusSearch();
}

/// Persistent 244px left rail for wide layouts. Settings is separated to the
/// bottom, followed by the signed-in user block.
class _NavRail extends StatelessWidget {
  const _NavRail({
    required this.items,
    required this.selected,
    required this.onSelect,
  });

  final List<_NavItem> items;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    // Settings is always the last destination; it sits below the divider.
    final lastIndex = items.length - 1;

    return Container(
      width: 244,
      decoration: BoxDecoration(
        color: lum.surface,
        border: Border(right: BorderSide(color: lum.hairline)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(8, 2, 8, 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: LuminaWordmark(size: 20),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < lastIndex; i++) ...[
                  _RailItem(
                    item: items[i],
                    active: i == selected,
                    onTap: () => onSelect(i),
                  ),
                  const SizedBox(height: 4),
                ],
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: lum.hairline)),
            ),
            child: _RailItem(
              item: items[lastIndex],
              active: lastIndex == selected,
              onTap: () => onSelect(lastIndex),
            ),
          ),
          const SizedBox(height: 8),
          const _RailUserBlock(),
        ],
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.item,
    required this.active,
    required this.onTap,
  });

  final _NavItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final row = Row(
      children: [
        Icon(item.icon, size: 20, color: active ? lum.accent : lum.g600),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            item.label,
            style: AppTypography.label.copyWith(
              fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              color: active ? lum.accentPress : lum.g600,
            ),
          ),
        ),
      ],
    );

    return Semantics(
      button: true,
      selected: active,
      label: item.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          hoverColor: lum.g100,
          child: active
              ? ClayContainer(
                  variant: ClayVariant.soft,
                  color: lum.accentSoft,
                  borderRadius: AppRadius.sm,
                  isDark: lum.isDark,
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: row,
                )
              : SizedBox(
                  height: 44,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: row,
                  ),
                ),
        ),
      ),
    );
  }
}

/// Signed-in user summary pinned to the bottom of the rail.
class _RailUserBlock extends ConsumerWidget {
  const _RailUserBlock();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lum = context.lum;
    final profile = ref.watch(profileControllerProvider).value;
    final name = profile?.fullName ?? '';
    final initials = _initialsOf(name);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 2),
      child: Row(
        children: [
          ClayContainer(
            variant: ClayVariant.lumen,
            // The lumen variant paints no fill of its own — without an explicit
            // colour the avatar renders as shadow only.
            color: lum.accent,
            borderRadius: 17,
            isDark: lum.isDark,
            width: 34,
            height: 34,
            child: Center(
              child: Text(
                initials,
                style: AppTypography.label.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name.isEmpty ? '—' : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.label.copyWith(
                    fontWeight: FontWeight.w500,
                    color: lum.textPrimary,
                  ),
                ),
                if (profile?.roleName != null)
                  Text(
                    profile!.roleName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(color: lum.g500),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Up to two initials from a full name; '?' when unknown.
  static String _initialsOf(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    final letters = parts.take(2).map((p) => p[0].toUpperCase());
    return letters.join();
  }
}

/// Bottom bar for narrow layouts. The active destination gets a pill behind its
/// icon rather than Material's default indicator.
class _LuminaBottomBar extends StatelessWidget {
  const _LuminaBottomBar({
    required this.items,
    required this.selected,
    required this.onSelect,
  });

  final List<_NavItem> items;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Container(
      decoration: BoxDecoration(
        color: lum.surface,
        border: Border(top: BorderSide(color: lum.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: _BottomTab(
                    item: items[i],
                    active: i == selected,
                    onTap: () => onSelect(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomTab extends StatelessWidget {
  const _BottomTab({
    required this.item,
    required this.active,
    required this.onTap,
  });

  final _NavItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final color = active ? lum.accent : lum.g500;

    return Semantics(
      button: true,
      selected: active,
      label: item.label,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: AppMotion.fast,
                curve: AppMotion.curve,
                width: 46,
                height: 30,
                decoration: BoxDecoration(
                  color: active ? lum.accentSoft : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Icon(item.icon, size: 21, color: color),
              ),
              const SizedBox(height: 3),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(
                  fontSize: 10.5,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
