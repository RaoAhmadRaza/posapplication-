import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../domain/entities/employee.dart';
import '../controllers/employees_controller.dart';
import '../widgets/hr_status_ui.dart';

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
    final async = ref.watch(employeesProvider);
    final controller = ref.read(employeesProvider.notifier);
    final activeStatus = controller.statusFilter;
    final activeDept = controller.departmentFilter;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios,
              color: AppColors.accent, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Employees', style: AppTypography.headline),
        actions: [
          IconButton(
            icon: const Icon(Icons.schedule, color: AppColors.accent),
            tooltip: 'Shifts',
            onPressed: () => context.push('/hr/shifts'),
          ),
        ],
      ),
      floatingActionButton: PermissionGate(
        module: 'hr',
        action: 'create',
        child: FloatingActionButton(
          backgroundColor: AppColors.accent,
          onPressed: () => context.push('/hr/employees/new'),
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding,
                  AppSpacing.sm, AppSpacing.screenPadding, AppSpacing.sm),
              child: AppTextField(
                controller: _searchCtrl,
                label: 'Search',
                prefixIcon: Icons.search,
                hint: 'Name or employee code',
                onSubmitted: _search,
              ),
            ),
            _StatusFilter(
              active: activeStatus,
              onChanged: (s) => controller.setFilters(
                status: s,
                clearStatus: s == null,
                query: controller.query,
              ),
            ),
            Expanded(
              child: async.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.screenPadding),
                    child: AppInlineBanner(
                        message: 'Could not load employees.',
                        type: BannerType.error),
                  ),
                ),
                data: (employees) {
                  if (employees.isEmpty) {
                    return Center(
                      child: Text('No employees found.',
                          style: AppTypography.footnote
                              .copyWith(color: AppColors.textMuted)),
                    );
                  }
                  final depts = _departments(employees);
                  return ListView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.screenPadding),
                    children: [
                      if (depts.isNotEmpty)
                        _DepartmentFilter(
                          departments: depts,
                          active: activeDept,
                          onChanged: (d) => controller.setFilters(
                            status: activeStatus,
                            department: d,
                            clearStatus: activeStatus == null,
                            clearDepartment: d == null,
                            query: controller.query,
                          ),
                        ),
                      for (final e in employees)
                        Padding(
                          padding:
                              const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: _EmployeeRow(employee: e),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
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

class _StatusFilter extends StatelessWidget {
  const _StatusFilter({required this.active, required this.onChanged});
  final EmployeeStatus? active;
  final ValueChanged<EmployeeStatus?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPadding),
        children: [
          _Chip(
            label: 'All',
            selected: active == null,
            onTap: () => onChanged(null),
          ),
          for (final s in EmployeeStatus.values)
            _Chip(
              label: employeeStatusLabels[s]!,
              selected: active == s,
              onTap: () => onChanged(s),
            ),
        ],
      ),
    );
  }
}

class _DepartmentFilter extends StatelessWidget {
  const _DepartmentFilter({
    required this.departments,
    required this.active,
    required this.onChanged,
  });
  final List<String> departments;
  final String? active;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        children: [
          _Chip(
              label: 'All depts',
              selected: active == null,
              onTap: () => onChanged(null)),
          for (final d in departments)
            _Chip(
                label: d,
                selected: active == d,
                onTap: () => onChanged(d)),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.base, vertical: AppSpacing.xs),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.accent
                : AppColors.accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: AppTypography.footnote.copyWith(
              color: selected ? Colors.white : AppColors.accent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmployeeRow extends StatelessWidget {
  const _EmployeeRow({required this.employee});
  final Employee employee;

  @override
  Widget build(BuildContext context) {
    final subtitle = [employee.designation, employee.department]
        .where((e) => e != null && e.isNotEmpty)
        .join(' · ');
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.separator, width: 0.5),
      ),
      child: InkWell(
        onTap: () => context.push('/hr/employees/${employee.id}'),
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(employee.name,
                        style: AppTypography.subhead
                            .copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(employee.employeeCode,
                        style: AppTypography.caption
                            .copyWith(color: AppColors.textMuted)),
                    if (subtitle.isNotEmpty)
                      Text(subtitle,
                          style: AppTypography.caption
                              .copyWith(color: AppColors.textMuted)),
                  ],
                ),
              ),
              EmployeeStatusBadge(status: employee.status),
            ],
          ),
        ),
      ),
    );
  }
}
