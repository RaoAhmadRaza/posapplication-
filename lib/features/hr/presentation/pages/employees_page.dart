import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/widgets/app_filter_chips.dart';
import '../../../../core/design/widgets/app_list_skeleton.dart';
import '../../../../core/design/widgets/app_search_field.dart';
import '../../../../core/design/widgets/app_states.dart';
import '../../../../core/widgets/module_scaffold.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../domain/entities/employee.dart';
import '../controllers/employees_controller.dart';
import '../widgets/employee_card.dart';
import '../widgets/hr_ui.dart';

class EmployeesPage extends ConsumerStatefulWidget {
  const EmployeesPage({super.key});

  @override
  ConsumerState<EmployeesPage> createState() => _EmployeesPageState();
}

class _EmployeesPageState extends ConsumerState<EmployeesPage> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _search(String v) => ref
      .read(employeesProvider.notifier)
      .setFilters(query: v.trim().isEmpty ? null : v.trim());

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final async = ref.watch(employeesProvider);
    final controller = ref.read(employeesProvider.notifier);
    final activeStatus = controller.statusFilter;
    final activeDept = controller.departmentFilter;

    // Status filter chips are index-based; index 0 == "All".
    final statusLabels = [
      'All',
      for (final s in EmployeeStatus.values) employeeStatusLabels[s]!,
    ];
    final statusSelected =
        activeStatus == null ? 0 : EmployeeStatus.values.indexOf(activeStatus) + 1;

    return ModuleScaffold(
      title: 'Employees',
      maxContentWidth: 720,
      actions: [
        _HeaderAction(
          icon: LucideIcons.clock,
          tooltip: 'Clock in / out',
          onTap: () => context.go('/hr/clock'),
        ),
        PermissionGate(
          module: 'hr',
          action: 'update',
          child: _HeaderAction(
            icon: LucideIcons.calendarClock,
            tooltip: 'Shifts',
            onTap: () => context.go('/hr/shifts'),
          ),
        ),
      ],
      floatingActionButton: PermissionGate(
        module: 'hr',
        action: 'create',
        child: FloatingActionButton(
          backgroundColor: lum.accent,
          onPressed: () => context.push('/hr/employees/new'),
          child: const Icon(LucideIcons.userPlus, color: Colors.white),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: AppSearchField(
              controller: _searchCtrl,
              hint: 'Search name, code or role',
              onSubmitted: _search,
              onClear: () => _search(''),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: AppFilterChips(
              labels: statusLabels,
              selected: statusSelected,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              onSelected: (i) {
                final s = i == 0 ? null : EmployeeStatus.values[i - 1];
                controller.setFilters(
                  status: s,
                  clearStatus: s == null,
                  query: controller.query,
                );
              },
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 28),
                child: AppListSkeleton(rows: 5, rowHeight: 74),
              ),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: AppErrorState(
                    title: "Unable to load employees",
                    body:
                        "Unable to reach the server. Check your connection and try again.",
                  ),
                ),
              ),
              data: (employees) {
                if (employees.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: AppEmptyState(
                        icon: LucideIcons.userRoundSearch,
                        title: 'No employees match',
                        body:
                            'No employees match these filters — try clearing them.',
                      ),
                    ),
                  );
                }
                final depts = _departments(employees);
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                  children: [
                    if (depts.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: AppFilterChips(
                          labels: ['All depts', ...depts],
                          selected: activeDept == null
                              ? 0
                              : depts.indexOf(activeDept) + 1,
                          onSelected: (i) {
                            final d = i == 0 ? null : depts[i - 1];
                            controller.setFilters(
                              status: activeStatus,
                              department: d,
                              clearStatus: activeStatus == null,
                              clearDepartment: d == null,
                              query: controller.query,
                            );
                          },
                        ),
                      ),
                    for (final e in employees)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: EmployeeCard(employee: e),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<String> _departments(List<Employee> employees) {
    final set = <String>{};
    for (final e in employees) {
      final d = e.department?.trim();
      if (d != null && d.isNotEmpty) set.add(d);
    }
    final list = set.toList()..sort();
    return list;
  }
}

/// A 40x40 icon button for the module header (reach Shifts / Clock, which are
/// not nav-rail destinations).
class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return IconButton(
      icon: Icon(icon, size: 20, color: lum.g600),
      tooltip: tooltip,
      onPressed: onTap,
    );
  }
}
