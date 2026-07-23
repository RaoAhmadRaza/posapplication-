import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/clay.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../../../core/design/widgets/app_sheet.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../../core/design/widgets/app_toast.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../domain/entities/leave.dart';
import '../controllers/leaves_controller.dart';
import 'hr_ui.dart';

/// One leave request row: a clay card with an initials tile, the employee name,
/// a type · date-range · days sub-line, a status [AppPill], the reason, and —
/// for pending rows — an Approve/Reject action row gated to `hr:approve`.
class LeaveRequestCard extends ConsumerWidget {
  const LeaveRequestCard({
    super.key,
    required this.leave,
    required this.invalidateQuery,
  });

  final Leave leave;
  final LeavesQuery invalidateQuery;

  static const _indent = 52.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lum = context.lum;
    final name = leave.employeeName ?? leaveTypeLabels[leave.type]!;
    final from = leave.fromDate.toIso8601String().substring(0, 10);
    final to = leave.toDate.toIso8601String().substring(0, 10);
    final days = leave.days.toStringAsFixed(
        leave.days.truncateToDouble() == leave.days ? 0 : 1);
    final meta = '${leaveTypeLabels[leave.type]} · $from – $to · $days day(s)';

    return ClayContainer(
      variant: ClayVariant.soft,
      color: lum.surface,
      borderRadius: AppRadius.lg,
      isDark: lum.isDark,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Soft clay tile with an explicit accentSoft fill — the initials
              // read in the accent colour.
              ClayContainer(
                variant: ClayVariant.soft,
                color: lum.accentSoft,
                borderRadius: AppRadius.md,
                isDark: lum.isDark,
                width: 40,
                height: 40,
                child: Center(
                  child: Text(
                    hrInitials(name),
                    style: AppTypography.label.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: lum.accent,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.headline
                          .copyWith(fontSize: 15, color: lum.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      meta,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.footnote
                          .copyWith(color: lum.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              AppPill(
                label: leaveStatusLabels[leave.status]!,
                tone: leaveStatusTone(leave.status),
              ),
            ],
          ),
          if (leave.reason != null && leave.reason!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 9, left: _indent),
              child: Text(
                leave.reason!,
                style:
                    AppTypography.footnote.copyWith(color: lum.textPrimary),
              ),
            ),
          if (leave.rejectionReason != null &&
              leave.rejectionReason!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: _indent),
              child: Text(
                'Rejected: ${leave.rejectionReason}',
                style:
                    AppTypography.footnote.copyWith(color: lum.dangerText),
              ),
            ),
          if (leave.isPending)
            PermissionGate(
              module: 'hr',
              action: 'approve',
              child: Padding(
                padding: const EdgeInsets.only(top: 12, left: _indent),
                child: Row(
                  children: [
                    AppButton(
                      label: 'Approve',
                      variant: AppButtonVariant.tinted,
                      size: AppButtonSize.sm,
                      icon: LucideIcons.check,
                      onPressed: () => _decide(context, ref, true),
                    ),
                    const SizedBox(width: 9),
                    AppButton(
                      label: 'Reject',
                      variant: AppButtonVariant.destructive,
                      size: AppButtonSize.sm,
                      icon: LucideIcons.x,
                      onPressed: () => _decide(context, ref, false),
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
      showAppToast(context, failure.message, type: BannerType.error);
    }
  }

  Future<String?> _rejectReason(BuildContext context) {
    return showAppSheet<String>(
      context: context,
      builder: (_) => _RejectLeaveSheet(
        subtitle: leave.employeeName ?? leaveTypeLabels[leave.type]!,
      ),
    );
  }
}

/// Reject-reason sheet — a required reason well plus a destructive confirm. Pops
/// with the trimmed reason, or null on cancel/dismiss.
class _RejectLeaveSheet extends StatefulWidget {
  const _RejectLeaveSheet({required this.subtitle});
  final String subtitle;

  @override
  State<_RejectLeaveSheet> createState() => _RejectLeaveSheetState();
}

class _RejectLeaveSheetState extends State<_RejectLeaveSheet> {
  final _ctrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _confirm() {
    final reason = _ctrl.text.trim();
    if (reason.isEmpty) {
      setState(() => _error = 'A reason is required.');
      return;
    }
    Navigator.of(context).pop(reason);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSheetHeader(
          title: 'Reject leave request',
          subtitle: '${widget.subtitle} · a reason is required.',
        ),
        AppTextField(
          controller: _ctrl,
          label: 'Reason for rejection',
          prefixIcon: LucideIcons.pencil,
          maxLines: 3,
          errorText: _error,
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Cancel',
                variant: AppButtonVariant.plain,
                fullWidth: true,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AppButton(
                label: 'Reject',
                variant: AppButtonVariant.destructive,
                fullWidth: true,
                onPressed: _confirm,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
