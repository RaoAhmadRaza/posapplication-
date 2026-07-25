import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
import 'tab_reload.dart';
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

// Indexed by shell branch: 0 Dashboard, 1 Inventory, 2 Purchase, 3 Sales,
// 4 Settings, 5 Repair, 6 Customers, 7 Reports, 8 Accounting, 9 Approvals,
// 10 HR, 11 Assistant. Repair onward are appended so the earlier indices never
// shift.
const _allItems = [
  _NavItem('Dashboard', LucideIcons.layoutGrid),
  _NavItem('Inventory', LucideIcons.box),
  _NavItem('Purchase', LucideIcons.truck),
  _NavItem('Sales', LucideIcons.shoppingCart),
  _NavItem('Settings', LucideIcons.settings),
  _NavItem('Repair', LucideIcons.wrench),
  _NavItem('Customers', LucideIcons.users),
  _NavItem('Reports', LucideIcons.barChart3),
  _NavItem('Accounting', LucideIcons.calculator),
  _NavItem('Approvals', LucideIcons.checkSquare2),
  _NavItem('HR', LucideIcons.contactRound),
  _NavItem('Assistant', LucideIcons.sparkles),
];

/// Shell branch indices, per the router's branch order.
const _kPurchaseBranch = 2;
const _kSalesBranch = 3;
const _kRepairBranch = 5;
const _kCustomersBranch = 6;
const _kReportsBranch = 7;
const _kAccountingBranch = 8;
const _kApprovalsBranch = 9;
const _kHrBranch = 10;
const _kAssistantBranch = 11;

/// A destination inside a module's own branch. These navigate with `go` —
/// `goBranch` is only for switching module.
class _ModuleDest {
  const _ModuleDest(this.label, this.shortLabel, this.icon, this.path);
  final String label;

  /// Two words do not fit a fifth-width bottom tab; the rail keeps [label].
  final String shortLabel;
  final IconData icon;
  final String path;
}

const _salesDests = [
  _ModuleDest('Point of sale', 'Sell', LucideIcons.shoppingCart, '/sales/pos'),
  _ModuleDest(
      'Sales history', 'History', LucideIcons.receiptText, '/sales/history'),
  _ModuleDest('Returns', 'Returns', LucideIcons.rotateCcw, '/sales/return'),
  // /sales/open renders the already-open session state itself, so one entry
  // covers both opening and closing a register.
  _ModuleDest('Session', 'Session', LucideIcons.lock, '/sales/open'),
];

// Only routes that actually live inside the purchasing branch belong here — a
// destination outside it would leave the shell and the rail would vanish
// mid-module. Orders / invoices / returns / reorder are still root routes and
// stay reachable from the hub.
const _purchasingDests = [
  _ModuleDest('Purchasing', 'Hub', LucideIcons.truck, '/purchasing'),
  _ModuleDest('Suppliers', 'Suppliers', LucideIcons.building2, '/suppliers'),
];

const _repairDests = [
  _ModuleDest('Repair jobs', 'Jobs', LucideIcons.wrench, '/repair'),
  _ModuleDest('Workload', 'Workload', LucideIcons.users, '/repair/workload'),
  _ModuleDest('History', 'History', LucideIcons.history, '/repair/history'),
];

// The customer detail / form / collect screens all start with /customers, so
// they keep Customers lit; receivables is the only sibling destination.
const _customersDests = [
  _ModuleDest('Customers', 'Customers', LucideIcons.users, '/customers'),
  _ModuleDest(
      'Receivables', 'Aging', LucideIcons.receiptText, '/receivables'),
];

// The four primary HR destinations. Shifts (admin config) and Clock
// (self-service) are push drill-downs from the Employees hub, not rail dests —
// this keeps the mobile bottom bar at 4 + Modules = 5 tabs. Employee and
// payroll detail screens keep their owning destination lit.
const _hrDests = [
  _ModuleDest('Employees', 'Team', LucideIcons.contactRound, '/hr'),
  _ModuleDest(
      'Attendance', 'Days', LucideIcons.calendarCheck, '/hr/attendance'),
  _ModuleDest('Leaves', 'Leaves', LucideIcons.plane, '/hr/leaves'),
  _ModuleDest('Payroll', 'Payroll', LucideIcons.wallet, '/hr/payroll'),
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

/// Which purchasing destination owns [path]. Every /suppliers screen keeps
/// Suppliers lit; everything else in the branch is the hub.
int _purchasingIndexFor(String path) =>
    path.startsWith('/suppliers') ? 1 : 0;

/// Which repair destination owns [path]. Intake and job detail are both part of
/// working the board, so they keep Repair jobs lit.
int _repairIndexFor(String path) {
  if (path.startsWith('/repair/workload')) return 1;
  if (path.startsWith('/repair/history')) return 2;
  return 0;
}

/// Which customers destination owns [path]. Every /customers screen keeps
/// Customers lit; /receivables is the only other destination.
int _customersIndexFor(String path) =>
    path.startsWith('/receivables') ? 1 : 0;

/// Which HR destination owns [path]. Employee screens keep Employees lit;
/// Shifts and Clock are drill-downs off the Employees hub, so they too keep
/// Employees lit.
int _hrIndexFor(String path) {
  if (path.startsWith('/hr/attendance')) return 1;
  if (path.startsWith('/hr/leaves')) return 2;
  if (path.startsWith('/hr/payroll')) return 3;
  return 0;
}

/// Permission-filtered module branches in display order (Settings last).
/// Reports has no in-branch destinations of its own, so it gets the normal
/// module rail (like Dashboard/Inventory), not a sub-rail.
List<int> _branchMapFor(Set<String> matrix) => [
      0,
      1,
      if (matrix.contains('purchase:read')) _kPurchaseBranch,
      if (matrix.contains('sales:read')) _kSalesBranch,
      if (matrix.contains('repair:read')) _kRepairBranch,
      if (matrix.contains('customers:read')) _kCustomersBranch,
      if (matrix.contains('reports:read')) _kReportsBranch,
      if (matrix.contains('accounting:read')) _kAccountingBranch,
      if (matrix.contains('approvals:read')) _kApprovalsBranch,
      if (matrix.contains('hr:read')) _kHrBranch,
      // Assistant has no permission gate — available to every signed-in user.
      _kAssistantBranch,
      4,
    ];

/// Root path each shell branch opens to. Used by [RailDetailScaffold], whose
/// rail must navigate with `go` (it lives above the shell and cannot goBranch).
const _branchRoot = <int, String>{
  0: '/dashboard',
  1: '/inventory',
  _kPurchaseBranch: '/purchasing',
  _kSalesBranch: '/sales/pos',
  4: '/settings',
  _kRepairBranch: '/repair',
  _kCustomersBranch: '/customers',
  _kReportsBranch: '/reports',
  _kAccountingBranch: '/accounting',
  _kApprovalsBranch: '/approvals',
  _kHrBranch: '/hr',
  _kAssistantBranch: '/assistant',
};

/// Wraps a top-level (outside-the-shell) detail page in the persistent desktop
/// rail so it reads as part of the app instead of a bare full screen. These
/// pages are kept above the shell on purpose (they are pushed from above it,
/// where a shell descendant would crash on a duplicate page key), so the rail
/// here navigates with `go`, not `goBranch`. Below the rail breakpoint the child
/// renders alone and keeps its own back navigation.
class RailDetailScaffold extends ConsumerWidget {
  const RailDetailScaffold({
    super.key,
    required this.child,
    this.selectedBranch = 1,
  });

  final Widget child;

  /// Shell branch to light in the rail (1 = Inventory).
  final int selectedBranch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matrix = ref.watch(permissionMatrixProvider).value ?? <String>{};
    final branchMap = _branchMapFor(matrix);
    final items = [for (final b in branchMap) _allItems[b]];
    final selected = branchMap.indexOf(selectedBranch);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < _kRailBreakpoint) return child;
        return Scaffold(
          body: Row(
            children: [
              _NavRail(
                items: items,
                selected: selected,
                onSelect: (i) => context.go(_branchRoot[branchMap[i]]!),
                dests: const [],
                destIndex: -1,
                moduleLabel: '',
              ),
              Expanded(child: child),
            ],
          ),
        );
      },
    );
  }
}

class BottomNavShell extends ConsumerWidget {
  const BottomNavShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matrix = ref.watch(permissionMatrixProvider).value ?? <String>{};
    final branchMap = _branchMapFor(matrix);
    final items = [for (final b in branchMap) _allItems[b]];
    final selected = branchMap.indexOf(navigationShell.currentIndex);

    void onSelect(int i) {
      final branch = branchMap[i];
      // Re-fetch the destination tab's data on (re)entry — tab roots are kept
      // alive in the IndexedStack, so this replaces manual pull-to-refresh.
      reloadBranchOnEnter(ref, branch);
      navigationShell.goBranch(branch, initialLocation: i == selected);
    }

    // Inside sales or repair the nav becomes that module's own destinations
    // (the design's module rail), with the other modules kept reachable below
    // the hairline on desktop and behind a Modules tab on mobile.
    final branch = navigationShell.currentIndex;
    final path = GoRouterState.of(context).uri.path;
    final (List<_ModuleDest> dests, int destIndex, String moduleLabel) =
        switch (branch) {
      _kPurchaseBranch => (
          _purchasingDests,
          _purchasingIndexFor(path),
          'Purchase',
        ),
      _kSalesBranch => (_salesDests, _salesIndexFor(path), 'Sales'),
      _kRepairBranch => (_repairDests, _repairIndexFor(path), 'Repair'),
      _kCustomersBranch => (
          _customersDests,
          _customersIndexFor(path),
          'Customers',
        ),
      _kHrBranch => (_hrDests, _hrIndexFor(path), 'HR'),
      _ => (const <_ModuleDest>[], -1, ''),
    };

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
                      dests: dests,
                      destIndex: destIndex,
                      moduleLabel: moduleLabel,
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
                dests: dests,
                destIndex: destIndex,
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
    required this.dests,
    required this.destIndex,
    required this.moduleLabel,
  });

  final List<_NavItem> items;
  final int selected;
  final ValueChanged<int> onSelect;

  /// Destinations of the module the shell is currently inside, empty when it is
  /// on a module that has none.
  final List<_ModuleDest> dests;

  /// Active module destination, or -1 when [dests] is empty.
  final int destIndex;
  final String moduleLabel;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    // Settings is always the last destination; it sits below the divider.
    final lastIndex = items.length - 1;

    if (destIndex >= 0) {
      return _ModuleRail(
        items: items,
        selected: selected,
        onSelect: onSelect,
        dests: dests,
        destIndex: destIndex,
        moduleLabel: moduleLabel,
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
          const _RailBrand(bottom: 20),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
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

/// Rail shown while a module branch with its own destinations is active: the
/// module's destinations on top, the other modules below a hairline so the user
/// is never stranded.
class _ModuleRail extends StatelessWidget {
  const _ModuleRail({
    required this.items,
    required this.selected,
    required this.onSelect,
    required this.dests,
    required this.destIndex,
    required this.moduleLabel,
  });

  final List<_NavItem> items;
  final int selected;
  final ValueChanged<int> onSelect;
  final List<_ModuleDest> dests;
  final int destIndex;
  final String moduleLabel;

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
          const _RailBrand(bottom: 18),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _RailEyebrow(moduleLabel),
                for (var i = 0; i < dests.length; i++) ...[
                  _RailItem(
                    item: _NavItem(dests[i].label, dests[i].icon),
                    active: i == destIndex,
                    onTap: () => context.go(dests[i].path),
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

/// Rail header: the wordmark with the LUMINA glyph faded in behind it.
class _RailBrand extends StatelessWidget {
  const _RailBrand({required this.bottom});
  final double bottom;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(8, 2, 8, bottom),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.centerLeft,
        children: [
          Positioned(
            left: -6,
            child: Opacity(
              opacity: 0.06,
              child: SvgPicture.asset(
                'assets/images/lumina-glyph-ink.svg',
                width: 40,
                height: 40,
              ),
            ),
          ),
          const LuminaWordmark(size: 20),
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
    required this.dests,
    required this.destIndex,
  });

  final List<_NavItem> items;
  final int selected;
  final ValueChanged<int> onSelect;

  /// Destinations of the module the shell is inside; empty elsewhere.
  final List<_ModuleDest> dests;

  /// Active module destination, or -1 when [dests] is empty.
  final int destIndex;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final inModule = destIndex >= 0;

    final tabs = <Widget>[
      if (inModule) ...[
        _BottomTab(
          item: const _NavItem('Modules', LucideIcons.layoutGrid),
          active: false,
          onTap: () => _showModulesSheet(context),
        ),
        for (var i = 0; i < dests.length; i++)
          _BottomTab(
            item: _NavItem(dests[i].shortLabel, dests[i].icon),
            active: i == destIndex,
            onTap: () => context.go(dests[i].path),
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
