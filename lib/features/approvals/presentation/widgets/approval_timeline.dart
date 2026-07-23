import 'package:flutter/material.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_typography.dart';
import '../../domain/entities/approval.dart';
import 'approvals_ui.dart';

class _Event {
  const _Event({
    required this.text,
    required this.who,
    required this.when,
    required this.color,
  });
  final String text;
  final String who;
  final DateTime when;
  final Color color;
}

/// Activity timeline for a request, built from the real submitted time, the
/// recorded actions and any escalation stamp. No invented events.
class ApprovalTimeline extends StatelessWidget {
  const ApprovalTimeline({
    super.key,
    required this.request,
    required this.actions,
  });

  final ApprovalRequest request;
  final List<ApprovalAction> actions;

  List<_Event> _events(LumColors lum) {
    final events = <_Event>[
      _Event(
        text: 'Request submitted',
        who: request.requestorName ?? '—',
        when: request.createdAt,
        color: lum.g400,
      ),
      for (final a in actions)
        _Event(
          text: '${_verb(a.action)} at Level ${a.level}',
          who: a.actorName ?? 'System',
          when: a.actedAt,
          color: approvalActionColor(lum, a.action),
        ),
    ];
    // Surface an escalation only when it was not already recorded as an action.
    final hasEscalation =
        actions.any((a) => a.action.toUpperCase() == 'ESCALATED');
    if (request.escalatedAt != null && !hasEscalation) {
      events.add(_Event(
        text: 'Escalated — no decision within the TTL window',
        who: 'System',
        when: request.escalatedAt!,
        color: lum.warning,
      ));
    }
    events.sort((a, b) => a.when.compareTo(b.when));
    return events;
  }

  String _verb(String action) => switch (action.toUpperCase()) {
        'APPROVED' => 'Approved',
        'REJECTED' => 'Rejected',
        'CANCELLED' => 'Cancelled',
        'ESCALATED' => 'Escalated',
        _ => action,
      };

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final events = _events(lum);
    return Column(
      children: [
        for (var i = 0; i < events.length; i++)
          _TimelineRow(
            event: events[i],
            showConnector: i < events.length - 1,
          ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.event, required this.showConnector});

  final _Event event;
  final bool showConnector;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: 4),
                decoration:
                    BoxDecoration(color: event.color, shape: BoxShape.circle),
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
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.text,
                    style: AppTypography.subhead.copyWith(color: lum.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${event.who} · ${approvalDateShort(event.when, withTime: true)}',
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
}
