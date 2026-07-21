import 'package:flutter/material.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_typography.dart';
import '../../domain/entities/repair_status_history.dart';
import 'repair_status_ui.dart';

/// The design's status-history rail: newest first, the top node tinted with its
/// status tone and a hairline connector down to the entries beneath it.
class RepairTimeline extends StatelessWidget {
  const RepairTimeline({
    super.key,
    required this.history,
    required this.nameFor,
    required this.formatAt,
  });

  final List<RepairStatusHistory> history;

  /// Resolves `changed_by` (a user id) to a display name. Returns null when the
  /// id is not one of the technicians we loaded — the row then shows the time
  /// alone rather than inventing an author.
  final String? Function(String changedBy) nameFor;

  final String Function(DateTime at) formatAt;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final rows = history.reversed.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < rows.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 11,
                  child: Column(
                    children: [
                      Container(
                        width: 11,
                        height: 11,
                        margin: const EdgeInsets.only(top: 3),
                        decoration: BoxDecoration(
                          color: i == 0
                              ? repairStatusColor(context, rows[i].newStatus)
                              : lum.surface2,
                          shape: BoxShape.circle,
                          border: i == 0
                              ? null
                              : Border.all(color: lum.hairline, width: 2),
                          boxShadow: i == 0
                              ? [
                                  BoxShadow(
                                    color: lum.accentSoft,
                                    spreadRadius: 3,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                      if (i < rows.length - 1)
                        Expanded(
                          child: Container(
                            width: 2,
                            margin: const EdgeInsets.only(top: 3),
                            color: lum.hairline,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: i < rows.length - 1 ? 14 : 0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          repairStatusLabels[rows[i].newStatus]!,
                          style: AppTypography.label.copyWith(
                            fontSize: 13.5,
                            color: lum.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          _meta(rows[i]),
                          style: AppTypography.caption.copyWith(
                            fontSize: 12,
                            color: lum.g500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _meta(RepairStatusHistory h) {
    final at = formatAt(h.changedAt);
    final by = nameFor(h.changedBy);
    return by == null ? at : '$at · $by';
  }
}
