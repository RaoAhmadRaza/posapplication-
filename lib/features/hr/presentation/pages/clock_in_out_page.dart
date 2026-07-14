import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../domain/entities/attendance.dart';
import '../../domain/entities/employee.dart';
import '../../data/models/attendance_model.dart';
import '../controllers/attendance_controller.dart';
import '../controllers/leaves_controller.dart';

/// Simple self-service clock in/out for the signed-in user's linked employee.
/// GPS / biometric deferred; source stamped MANUAL.
class ClockInOutPage extends ConsumerWidget {
  const ClockInOutPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meAsync = ref.watch(myEmployeeProvider);
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
        title: Text('Clock In / Out', style: AppTypography.headline),
      ),
      body: SafeArea(
        child: meAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              child: AppInlineBanner(
                  message: 'Could not load your record.',
                  type: BannerType.error),
            ),
          ),
          data: (me) {
            if (me == null) {
              return Center(
                child: Text('No employee is linked to your account.',
                    style: AppTypography.footnote
                        .copyWith(color: AppColors.textMuted)),
              );
            }
            return _ClockBody(employee: me);
          },
        ),
      ),
    );
  }
}

class _ClockBody extends ConsumerStatefulWidget {
  const _ClockBody({required this.employee});
  final Employee employee;

  @override
  ConsumerState<_ClockBody> createState() => _ClockBodyState();
}

class _ClockBodyState extends ConsumerState<_ClockBody> {
  bool _saving = false;
  String? _error;

  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  AttendanceQuery get _query =>
      (year: _today.year, month: _today.month, employeeId: widget.employee.id);

  Attendance? _todayRow(List<Attendance> rows) {
    for (final a in rows) {
      if (a.date.year == _today.year &&
          a.date.month == _today.month &&
          a.date.day == _today.day) {
        return a;
      }
    }
    return null;
  }

  Future<void> _punch({required bool clockOut, Attendance? existing}) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final now = DateTime.now();
    final failure = await ref.read(attendanceActionsProvider).mark({
      'p_employee_id': widget.employee.id,
      'p_date': _today.toIso8601String().substring(0, 10),
      'p_shift_id': existing?.shiftId,
      'p_check_in': (existing?.checkIn ?? now).toIso8601String(),
      'p_check_out': clockOut ? now.toIso8601String() : null,
      'p_status': AttendanceModel.statusToDb(
          existing?.status ?? AttendanceStatus.present),
      'p_overtime_hours': existing?.overtimeHours ?? 0,
      'p_source': 'MANUAL',
      // clock-out edits today's row → audit rule needs a reason
      'p_notes': clockOut ? 'Clock out' : null,
    }, _query);
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (failure != null) _error = failure.message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(attendanceMonthProvider(_query));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: AppInlineBanner(
              message: 'Could not load today.', type: BannerType.error),
        ),
      ),
      data: (rows) {
        final today = _todayRow(rows);
        final checkedIn = today?.checkIn != null;
        final checkedOut = today?.checkOut != null;
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          children: [
            Text(widget.employee.name, style: AppTypography.title2),
            Text(_today.toIso8601String().substring(0, 10),
                style: AppTypography.footnote
                    .copyWith(color: AppColors.textMuted)),
            const SizedBox(height: AppSpacing.xl),
            _row('Check-in', _fmt(today?.checkIn)),
            _row('Check-out', _fmt(today?.checkOut)),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              AppInlineBanner(message: _error!, type: BannerType.error),
            ],
            const SizedBox(height: AppSpacing.xl),
            if (!checkedIn)
              AppButton(
                label: 'Clock In',
                icon: Icons.login,
                fullWidth: true,
                loading: _saving,
                onPressed: _saving ? null : () => _punch(clockOut: false),
              )
            else if (!checkedOut)
              AppButton(
                label: 'Clock Out',
                icon: Icons.logout,
                variant: AppButtonVariant.destructive,
                fullWidth: true,
                loading: _saving,
                onPressed: _saving
                    ? null
                    : () => _punch(clockOut: true, existing: today),
              )
            else
              Center(
                child: Text('Done for today.',
                    style: AppTypography.footnote
                        .copyWith(color: AppColors.textMuted)),
              ),
          ],
        );
      },
    );
  }

  static String _fmt(DateTime? t) {
    if (t == null) return '—';
    final l = t.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:'
        '${l.minute.toString().padLeft(2, '0')}';
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Row(
          children: [
            SizedBox(
                width: 120,
                child: Text(k,
                    style: AppTypography.footnote
                        .copyWith(color: AppColors.textMuted))),
            Text(v, style: AppTypography.body),
          ],
        ),
      );
}
