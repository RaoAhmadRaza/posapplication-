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

/// Shell branch index of the sales module, per the router's branch order.
const _kSalesBranch = 3;

/// Sales destinations. Every one of these lives inside the sales shell branch,
/// so they navigate with `go` — `goBranch` is only for switching module.
class _SalesDest {
  const _SalesDest(this.label, this.icon, this.path);
  final String label;
  final IconData icon;
  final String path;
}

const _salesDests = [
  _SalesDest('Point of sale', LucideIcons.shoppingCart, '/sales/pos'),
  _SalesDest('Sales history', LucideIcons.receiptText, '/sales/history'),
  _SalesDest('Returns', LucideIcons.rotateCcw, '/sales/return'),
  // /sales/open renders the already-open session state itself, so one entry
  // covers both opening and closing a register.
  _SalesDest('Session', LucideIcons.lock, '/sales/open'),
];

/// Which sales destination owns [path]. Checkout (payment/success/receipt) is
/// part of selling, so it keeps Point of sale lit.
int _salesIndexFor(String path) {
  if (path.startsWith('/sales/history')) return 1;
  if (path.startsWith('/sales/return')) return 2;
  if (path.startsWith('/sales/open') || path.startsWith('/sales/session')) {
    return 3;
  }
  return 0;
}

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

    // Inside sales the nav becomes the module's own destinations (the design's
    // sales rail), with the other modules kept reachable below the hairline on
    // desktop and behind a Modules tab on mobile.
    final inSales = navigationShell.currentIndex == _kSalesBranch;
    final salesIndex =
        inSales ? _salesIndexFor(GoRouterState.of(context).uri.path) : -1;

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
                      items: items,
                      selected: selected,
                      onSelect: onSelect,
                      salesIndex: salesIndex,
                    ),
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
                salesIndex: salesIndex,
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
    required this.salesIndex,
  });

  final List<_NavItem> items;
  final int selected;
  final ValueChanged<int> onSelect;

  /// Active sales destination, or -1 when the shell is not on the sales branch.
  final int salesIndex;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    // Settings is always the last destination; it sits below the divider.
    final lastIndex = items.length - 1;

    if (salesIndex >= 0) {
      return _SalesRail(
        items: items,
        selected: selected,
        onSelect: onSelect,
        salesIndex: salesIndex,
      );
    }

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

/// Rail shown while the sales branch is active: the module's own destinations
/// on top, the other modules below a hairline so the user is never stranded.
class _SalesRail extends StatelessWidget {
  const _SalesRail({
    required this.items,
    required this.selected,
    required this.onSelect,
    required this.salesIndex,
  });

  final List<_NavItem> items;
  final int selected;
  final ValueChanged<int> onSelect;
  final int salesIndex;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;

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
            padding: EdgeInsets.fromLTRB(8, 2, 8, 18),
            child: Align(
              alignment: Alignment.centerLeft,
              child: LuminaWordmark(size: 20),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const _RailEyebrow('Sales'),
                for (var i = 0; i < _salesDests.length; i++) ...[
                  _RailItem(
                    item: _NavItem(_salesDests[i].label, _salesDests[i].icon),
                    active: i == salesIndex,
                    onTap: () => context.go(_salesDests[i].path),
                  ),
                  const SizedBox(height: 4),
                ],
                Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 4),
                  height: 1,
                  color: lum.hairline,
                ),
                const _RailEyebrow('Modules'),
                for (var i = 0; i < items.length; i++)
                  if (i != selected) ...[
                    _RailItem(
                      item: items[i],
                      active: false,
                      onTap: () => onSelect(i),
                    ),
                    const SizedBox(height: 4),
                  ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          const _RailUserBlock(),
        ],
      ),
    );
  }
}

/// Small uppercase group heading in the rail.
class _RailEyebrow extends StatelessWidget {
  const _RailEyebrow(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      child: Text(
        label.toUpperCase(),
        style: AppTypography.caption.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.66,
          color: context.lum.g400,
        ),
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
    required this.salesIndex,
  });

  final List<_NavItem> items;
  final int selected;
  final ValueChanged<int> onSelect;

  /// Active sales destination, or -1 when the shell is not on the sales branch.
  final int salesIndex;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final inSales = salesIndex >= 0;

    final tabs = <Widget>[
      if (inSales) ...[
        _BottomTab(
          item: const _NavItem('Modules', LucideIcons.layoutGrid),
          active: false,
          onTap: () => _showModulesSheet(context),
        ),
        for (var i = 0; i < _salesDests.length; i++)
          _BottomTab(
            // Two words do not fit a fifth-width tab; the rail keeps the full
            // labels.
            item: _NavItem(_shortLabels[i], _salesDests[i].icon),
            active: i == salesIndex,
            onTap: () => context.go(_salesDests[i].path),
          ),
      ] else
        for (var i = 0; i < items.length; i++)
          _BottomTab(
            item: items[i],
            active: i == selected,
            onTap: () => onSelect(i),
          ),
    ];

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
            children: [for (final tab in tabs) Expanded(child: tab)],
          ),
        ),
      ),
    );
  }

  static const _shortLabels = ['Sell', 'History', 'Returns', 'Session'];

  void _showModulesSheet(BuildContext context) {
    final lum = context.lum;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: lum.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: lum.g300,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(left: 10, top: 6),
              child: _RailEyebrow('Modules'),
            ),
            for (var i = 0; i < items.length; i++)
              if (i != selected)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 2,
                  ),
                  child: _RailItem(
                    item: items[i],
                    active: false,
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      onSelect(i);
                    },
                  ),
                ),
            const SizedBox(height: 12),
          ],
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
