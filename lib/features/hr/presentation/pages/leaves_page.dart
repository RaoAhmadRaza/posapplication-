import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/clay.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_dropdown.dart';
import '../../../../core/design/widgets/app_filter_chips.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_list_skeleton.dart';
import '../../../../core/design/widgets/app_sheet.dart';
import '../../../../core/design/widgets/app_states.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../../core/design/widgets/app_toast.dart';
import '../../../../core/widgets/module_scaffold.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../../auth/presentation/controllers/branch_controller.dart';
import '../../domain/entities/leave.dart';
import '../../data/models/leave_model.dart';
import '../controllers/attendance_controller.dart';
import '../controllers/leaves_controller.dart';
import '../widgets/hr_ui.dart';
import '../widgets/leave_request_card.dart';

class LeavesPage extends ConsumerStatefulWidget {
  const LeavesPage({super.key});

  @override
  ConsumerState<LeavesPage> createState() => _LeavesPageState();
}

class _LeavesPageState extends ConsumerState<LeavesPage> {
  LeaveStatus? _status;

  /// Chip labels — index 0 is "All", the rest follow [LeaveStatus.values].
  static final _chipLabels = [
    'All',
    for (final s in LeaveStatus.values) leaveStatusLabels[s]!,
  ];

  @override
  Widget build(BuildContext context) {
    final query = (employeeId: null as String?, status: _status);
    final async = ref.watch(leavesProvider(query));
    final isWide = ModuleScaffold.isWideOf(context);

    final selectedChip =
        _status == null ? 0 : LeaveStatus.values.indexOf(_status!) + 1;

    final applyButton = PermissionGate(
      module: 'hr',
      action: 'create',
      child: AppButton(
        label: 'Apply for leave',
        icon: LucideIcons.calendarPlus,
        size: AppButtonSize.sm,
        onPressed: () => _apply(query),
      ),
    );

    return ModuleScaffold(
      title: 'Leave requests',
      maxContentWidth: 900,
      actions: [if (isWide) applyButton],
      floatingActionButton:
          isWide ? null : _ApplyLeaveFab(onTap: () => _apply(query)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding:
                EdgeInsets.fromLTRB(isWide ? 32 : 16, 14, isWide ? 32 : 16, 0),
            child: AppFilterChips(
              labels: _chipLabels,
              selected: selectedChip,
              onSelected: (i) => setState(
                  () => _status = i == 0 ? null : LeaveStatus.values[i - 1]),
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => Padding(
                padding: EdgeInsets.fromLTRB(
                    isWide ? 32 : 16, 14, isWide ? 32 : 16, 20),
                child: const AppListSkeleton(rows: 5, rowHeight: 88),
              ),
              error: (e, _) => AppErrorState(
                icon: LucideIcons.cloudOff,
                title: "Unable to load leave requests",
                body: 'Unable to reach the server. Try again in a moment.',
                retryLabel: 'Retry',
                onRetry: () => ref.invalidate(leavesProvider(query)),
              ),
              data: (leaves) {
                if (leaves.isEmpty) {
                  return const AppEmptyState(
                    icon: LucideIcons.plane,
                    title: 'No requests here',
                    body: 'No requests in this state right now.',
                  );
                }
                return ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                      isWide ? 32 : 16, 14, isWide ? 32 : 16, isWide ? 32 : 20),
                  itemCount: leaves.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => LeaveRequestCard(
                    leave: leaves[i],
                    invalidateQuery: query,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _apply(LeavesQuery query) async {
    final branch = ref.read(currentBranchProvider);
    if (branch == null) {
      showAppToast(context, 'Select a branch first.',
          type: BannerType.warning);
      return;
    }
    await showApplyLeaveSheet(
        context: context, employeeId: null, invalidateQuery: query);
  }
}

/// The design's floating pill CTA for narrow layouts.
class _ApplyLeaveFab extends StatelessWidget {
  const _ApplyLeaveFab({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return PermissionGate(
      module: 'hr',
      action: 'create',
      child: Semantics(
        button: true,
        label: 'Apply for leave',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: ClayContainer(
            variant: ClayVariant.soft,
            color: lum.accent,
            borderRadius: AppRadius.pill,
            isDark: lum.isDark,
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.calendarPlus, size: 19, color: Colors.white),
                SizedBox(width: 9),
                Text(
                  'Apply for leave',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shared apply-leave sheet. employeeId null → shows a branch-employee picker
/// (standalone Leaves page); otherwise fixed to that employee (profile tab).
/// Performs the mutation and returns true on success.
Future<bool> showApplyLeaveSheet({
  required BuildContext context,
  required String? employeeId,
  required LeavesQuery invalidateQuery,
}) async {
  final result = await showAppSheet<bool>(
    context: context,
    builder: (_) => _ApplyLeaveSheet(
        employeeId: employeeId, invalidateQuery: invalidateQuery),
  );
  return result ?? false;
}

class _ApplyLeaveSheet extends ConsumerStatefulWidget {
  const _ApplyLeaveSheet(
      {required this.employeeId, required this.invalidateQuery});
  final String? employeeId;
  final LeavesQuery invalidateQuery;

  @override
  ConsumerState<_ApplyLeaveSheet> createState() => _ApplyLeaveSheetState();
}

class _ApplyLeaveSheetState extends ConsumerState<_ApplyLeaveSheet> {
  late String? _employeeId = widget.employeeId;
  LeaveType _type = LeaveType.annual;
  DateTime _from = DateTime.now();
  DateTime _to = DateTime.now();
  final _reasonCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool from) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: from ? _from : _to,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked != null) {
      setState(() {
        if (from) {
          _from = picked;
          if (_to.isBefore(_from)) _to = _from;
        } else {
          _to = picked.isBefore(_from) ? _from : picked;
        }
      });
    }
  }

  Future<void> _save() async {
    if (_employeeId == null) {
      setState(() => _error = 'Select an employee.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final failure = await ref.read(leaveActionsProvider).apply({
      'p_employee_id': _employeeId,
      'p_type': LeaveModel.typeToDb(_type),
      'p_from': _from.toIso8601String().substring(0, 10),
      'p_to': _to.toIso8601String().substring(0, 10),
      'p_days': null, // server computes
      'p_reason': _reasonCtrl.text.trim().isEmpty
          ? null
          : _reasonCtrl.text.trim(),
    }, widget.invalidateQuery);
    if (!mounted) return;
    if (failure != null) {
      setState(() {
        _saving = false;
        _error = failure.message;
      });
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppSheetHeader(title: 'Apply for leave'),
        if (widget.employeeId == null) ...[
          const _SheetLabel('Employee'),
          _EmployeePicker(
            value: _employeeId,
            onChanged: (v) => setState(() => _employeeId = v),
          ),
          const SizedBox(height: 16),
        ],
        const _SheetLabel('Leave type'),
        AppFilterChips(
          labels: [for (final t in LeaveType.values) leaveTypeLabels[t]!],
          selected: LeaveType.values.indexOf(_type),
          onSelected: (i) => setState(() => _type = LeaveType.values[i]),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
                child: _DateBox(
                    label: 'From',
                    date: _from,
                    onTap: () => _pickDate(true))),
            const SizedBox(width: 12),
            Expanded(
                child: _DateBox(
                    label: 'To', date: _to, onTap: () => _pickDate(false))),
          ],
        ),
        const SizedBox(height: 16),
        AppTextField(
          controller: _reasonCtrl,
          label: 'Reason (optional)',
          prefixIcon: LucideIcons.pencil,
          maxLines: 3,
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          AppInlineBanner(message: _error!, type: BannerType.error),
        ],
        const SizedBox(height: 20),
        AppButton(
          label: 'Submit request',
          fullWidth: true,
          loading: _saving,
          onPressed: _saving ? null : _save,
        ),
      ],
    );
  }
}

/// Section label above a sheet control.
class _SheetLabel extends StatelessWidget {
  const _SheetLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Text(
        text,
        style: AppTypography.footnote.copyWith(
          fontWeight: FontWeight.w600,
          color: lum.textSecondary,
        ),
      ),
    );
  }
}

class _EmployeePicker extends ConsumerWidget {
  const _EmployeePicker({required this.value, required this.onChanged});
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branch = ref.watch(currentBranchProvider);
    if (branch == null) return const SizedBox();
    final async = ref.watch(branchEmployeesProvider(branch.id));
    return async.maybeWhen(
      data: (employees) => AppDropdown<String>(
        value: value,
        placeholder: 'Select employee',
        options: [
          for (final e in employees.where((e) => e.isActive))
            AppDropdownOption(value: e.id, label: e.name),
        ],
        onSelected: onChanged,
      ),
      orElse: () => const LinearProgressIndicator(),
    );
  }
}

/// Inset date well with the design's clay surface-2 fill.
class _DateBox extends StatelessWidget {
  const _DateBox(
      {required this.label, required this.date, required this.onTap});
  final String label;
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final value = date.toIso8601String().substring(0, 10);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SheetLabel(label),
        Semantics(
          button: true,
          label: '$label $value',
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: lum.surface2,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(children: [
                Icon(LucideIcons.calendar, size: 17, color: lum.g400),
                const SizedBox(width: 8),
                Text(value,
                    style: AppTypography.fieldText
                        .copyWith(color: lum.textPrimary)),
              ]),
            ),
          ),
        ),
      ],
    );
  }
}
