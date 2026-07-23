import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_typography.dart';
import '../../domain/entities/approval.dart';
import 'approvals_ui.dart';

enum _StepState { done, active, pending, rejected, closed }

/// The approval ladder: one node per workflow level, its state derived from the
/// request's current level, status and the recorded actions. Pure rendering of
/// real data — the workflow, request and actions all come from the detail load.
class ApprovalLadder extends StatelessWidget {
  const ApprovalLadder({
    super.key,
    required this.workflow,
    required this.request,
    required this.actions,
  });

  final ApprovalWorkflow workflow;
  final ApprovalRequest request;
  final List<ApprovalAction> actions;

  @override
  Widget build(BuildContext context) {
    final levels = [...workflow.levels]..sort((a, b) => a.level.compareTo(b.level));
    if (levels.isEmpty) {
      return _empty(context);
    }
    return Column(
      children: [
        for (var i = 0; i < levels.length; i++)
          _LadderRow(
            level: levels[i],
            state: _stateFor(levels[i].level),
            action: _actionAt(levels[i].level),
            showConnector: i < levels.length - 1,
          ),
      ],
    );
  }

  _StepState _stateFor(int level) {
    if (request.isOpen) {
      if (level < request.currentLevel) return _StepState.done;
      if (level == request.currentLevel) return _StepState.active;
      return _StepState.pending;
    }
    switch (request.status) {
      case ApprovalStatus.approved:
        return _StepState.done;
      case ApprovalStatus.rejected:
        if (level < request.currentLevel) return _StepState.done;
        if (level == request.currentLevel) return _StepState.rejected;
        return _StepState.closed;
      default:
        return _StepState.closed;
    }
  }

  ApprovalAction? _actionAt(int level) {
    for (final a in actions) {
      if (a.level == level &&
          (a.action.toUpperCase() == 'APPROVED' ||
              a.action.toUpperCase() == 'REJECTED')) {
        return a;
      }
    }
    return null;
  }

  Widget _empty(BuildContext context) {
    final lum = context.lum;
    return Text(
      'This request has no configured levels.',
      style: AppTypography.footnote.copyWith(color: lum.g500),
    );
  }
}

class _LadderRow extends StatelessWidget {
  const _LadderRow({
    required this.level,
    required this.state,
    required this.action,
    required this.showConnector,
  });

  final ApprovalLevel level;
  final _StepState state;
  final ApprovalAction? action;
  final bool showConnector;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final (bg, fg) = switch (state) {
      _StepState.done => (lum.successSoft, lum.successText),
      _StepState.active => (lum.accentSoft, lum.accentPress),
      _StepState.rejected => (lum.dangerSoft, lum.dangerText),
      _StepState.pending => (lum.g100, lum.g500),
      _StepState.closed => (lum.g100, lum.g400),
    };
    final statusLabel = switch (state) {
      _StepState.done => 'Approved',
      _StepState.active => 'In review',
      _StepState.rejected => 'Rejected',
      _StepState.pending => 'Pending',
      _StepState.closed => 'Not reached',
    };

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                child: Center(child: _node(fg)),
              ),
              if (showConnector)
                Expanded(
                  child: Container(
                    width: 2,
                    constraints: const BoxConstraints(minHeight: 22),
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    color: lum.hairline,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          level.requiredRole,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.subhead.copyWith(
                            fontWeight: FontWeight.w600,
                            color: lum.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        statusLabel,
                        style: AppTypography.caption.copyWith(
                          fontWeight: FontWeight.w600,
                          color: fg,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _who(lum),
                    style: AppTypography.caption.copyWith(color: lum.g500),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _node(Color fg) {
    switch (state) {
      case _StepState.done:
        return Icon(LucideIcons.check, size: 15, color: fg);
      case _StepState.rejected:
        return Icon(LucideIcons.x, size: 15, color: fg);
      case _StepState.active:
        return Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
        );
      case _StepState.pending:
      case _StepState.closed:
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: fg, width: 2),
          ),
        );
    }
  }

  String _who(LumColors lum) {
    final a = action;
    if (a != null) {
      final actor = a.actorName ?? (a.action.toUpperCase() == 'REJECTED'
          ? 'Rejected'
          : 'Approved');
      return '$actor · ${approvalDateShort(a.actedAt)}';
    }
    return switch (state) {
      _StepState.active => 'Waiting for a decision',
      _StepState.pending => 'Not started',
      _StepState.closed => '—',
      _ => '',
    };
  }
}
