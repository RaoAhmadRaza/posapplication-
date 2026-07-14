import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../../auth/presentation/controllers/branch_controller.dart';
import '../../domain/entities/leave.dart';
import '../../data/models/leave_model.dart';
import '../controllers/attendance_controller.dart';
import '../controllers/leaves_controller.dart';
import '../widgets/hr_status_ui.dart';

class LeavesPage extends ConsumerStatefulWidget {
  const LeavesPage({super.key});

  @override
  ConsumerState<LeavesPage> createState() => _LeavesPageState();
}

class _LeavesPageState extends ConsumerState<LeavesPage> {
  LeaveStatus? _status;

  @override
  Widget build(BuildContext context) {
    final query = (employeeId: null as String?, status: _status);
    final async = ref.watch(leavesProvider(query));

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
        title: Text('Leaves', style: AppTypography.headline),
      ),
      floatingActionButton: PermissionGate(
        module: 'hr',
        action: 'create',
        child: FloatingActionButton.extended(
          backgroundColor: AppColors.accent,
          icon: const Icon(Icons.add, color: Colors.white),
          label: Text('Apply', style: AppTypography.callout
              .copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
          onPressed: () => _apply(query),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenPadding),
                children: [
                  _chip('All', _status == null,
                      () => setState(() => _status = null)),
                  for (final s in LeaveStatus.values)
                    _chip(leaveStatusLabels[s]!, _status == s,
                        () => setState(() => _status = s)),
                ],
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
                        message: 'Could not load leaves.',
                        type: BannerType.error),
                  ),
                ),
                data: (leaves) {
                  if (leaves.isEmpty) {
                    return Center(
                      child: Text('No leaves.',
                          style: AppTypography.footnote
                              .copyWith(color: AppColors.textMuted)),
                    );
                  }
                  return ListView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.screenPadding),
                    children: [
                      for (final l in leaves)
                        Padding(
                          padding:
                              const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: LeaveRow(leave: l, invalidateQuery: query),
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

  Future<void> _apply(LeavesQuery query) async {
    final branch = ref.read(currentBranchProvider);
    if (branch == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select a branch first.')));
      return;
    }
    await showApplyLeaveSheet(
        context: context, employeeId: null, invalidateQuery: query);
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
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
          child: Text(label,
              style: AppTypography.footnote.copyWith(
                  color: selected ? Colors.white : AppColors.accent,
                  fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}

/// One leave row; shows Approve/Reject to hr:approve holders when pending.
class LeaveRow extends ConsumerWidget {
  const LeaveRow({super.key, required this.leave, required this.invalidateQuery});
  final Leave leave;
  final LeavesQuery invalidateQuery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = '${leave.fromDate.toIso8601String().substring(0, 10)} → '
        '${leave.toDate.toIso8601String().substring(0, 10)}';
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.separator, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        leave.employeeName ?? leaveTypeLabels[leave.type]!,
                        style: AppTypography.subhead
                            .copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                        '${leaveTypeLabels[leave.type]} · $range · ${leave.days.toStringAsFixed(leave.days.truncateToDouble() == leave.days ? 0 : 1)}d',
                        style: AppTypography.caption
                            .copyWith(color: AppColors.textMuted)),
                    if (leave.reason != null && leave.reason!.isNotEmpty)
                      Text(leave.reason!,
                          style: AppTypography.caption
                              .copyWith(color: AppColors.textMuted)),
                    if (leave.rejectionReason != null)
                      Text('Rejected: ${leave.rejectionReason}',
                          style: AppTypography.caption
                              .copyWith(color: AppColors.destructive)),
                  ],
                ),
              ),
              _LeaveStatusBadge(status: leave.status),
            ],
          ),
          if (leave.isPending)
            PermissionGate(
              module: 'hr',
              action: 'approve',
              child: Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: 'Approve',
                        variant: AppButtonVariant.tinted,
                        onPressed: () => _decide(context, ref, true),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: AppButton(
                        label: 'Reject',
                        variant: AppButtonVariant.plain,
                        onPressed: () => _decide(context, ref, false),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _decide(
      BuildContext context, WidgetRef ref, bool approve) async {
    String? reason;
    if (!approve) {
      reason = await _rejectReason(context);
      if (reason == null) return; // cancelled
    }
    final failure = await ref.read(leaveActionsProvider).decide(
          leaveId: leave.id,
          approve: approve,
          rejectionReason: reason,
          invalidate: invalidateQuery,
        );
    if (!context.mounted) return;
    if (failure != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }

  Future<String?> _rejectReason(BuildContext context) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.background,
        title: Text('Reject leave', style: AppTypography.headline),
        content: AppTextField(
            controller: ctrl,
            label: 'Reason',
            prefixIcon: Icons.notes),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final r = ctrl.text.trim();
              if (r.isNotEmpty) Navigator.pop(context, r);
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }
}

class _LeaveStatusBadge extends StatelessWidget {
  const _LeaveStatusBadge({required this.status});
  final LeaveStatus status;

  @override
  Widget build(BuildContext context) {
    final color = leaveStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(leaveStatusLabels[status]!,
          style: AppTypography.caption
              .copyWith(color: color, fontWeight: FontWeight.w600)),
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
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
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
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.screenPadding,
        right: AppSpacing.screenPadding,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Apply Leave', style: AppTypography.headline),
            const SizedBox(height: AppSpacing.md),
            if (widget.employeeId == null) ...[
              _EmployeePicker(
                value: _employeeId,
                onChanged: (v) => setState(() => _employeeId = v),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                for (final t in LeaveType.values)
                  ChoiceChip(
                    label: Text(leaveTypeLabels[t]!),
                    selected: _type == t,
                    onSelected: (_) => setState(() => _type = t),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                    child: _DateBox(
                        label: 'From',
                        date: _from,
                        onTap: () => _pickDate(true))),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                    child: _DateBox(
                        label: 'To',
                        date: _to,
                        onTap: () => _pickDate(false))),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
                controller: _reasonCtrl,
                label: 'Reason (optional)',
                prefixIcon: Icons.notes),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              AppInlineBanner(message: _error!, type: BannerType.error),
            ],
            const SizedBox(height: AppSpacing.lg),
            AppButton(
                label: 'Submit',
                fullWidth: true,
                loading: _saving,
                onPressed: _saving ? null : _save),
          ],
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
      data: (employees) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.fieldFill,
          borderRadius: BorderRadius.circular(12),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String?>(
            isExpanded: true,
            value: value,
            hint: Text('Select employee', style: AppTypography.fieldHint),
            items: [
              for (final e in employees.where((e) => e.isActive))
                DropdownMenuItem(value: e.id, child: Text(e.name)),
            ],
            onChanged: onChanged,
          ),
        ),
      ),
      orElse: () => const LinearProgressIndicator(),
    );
  }
}

class _DateBox extends StatelessWidget {
  const _DateBox(
      {required this.label, required this.date, required this.onTap});
  final String label;
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(label, style: AppTypography.fieldLabel),
        ),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.fieldFill,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              const Icon(Icons.calendar_today_outlined,
                  color: AppColors.textMuted, size: 20),
              const SizedBox(width: 10),
              Text(date.toIso8601String().substring(0, 10),
                  style: AppTypography.fieldText),
            ]),
          ),
        ),
      ],
    );
  }
}
