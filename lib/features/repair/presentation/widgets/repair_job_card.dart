import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/clay.dart';
import '../../domain/entities/repair_job.dart';
import 'repair_status_ui.dart';

/// Initials of a person's name, up to two letters; '?' when unknown.
String repairInitials(String? name) {
  final parts = (name ?? '').trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  if (parts.isEmpty) return '?';
  return parts.take(2).map((p) => p[0].toUpperCase()).join();
}

/// Small round technician avatar — accent-soft fill, initials in accent press.
class RepairTechAvatar extends StatelessWidget {
  const RepairTechAvatar({super.key, required this.name, this.size = 22});

  final String? name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: lum.accentSoft, shape: BoxShape.circle),
      child: Text(
        repairInitials(name),
        style: AppTypography.label.copyWith(
          fontSize: size * 0.45,
          fontWeight: FontWeight.w700,
          color: lum.accentPress,
        ),
      ),
    );
  }
}

/// The design's board card: select box, job number, priority pill, device,
/// two-line issue, technician and a Move affordance.
class RepairJobCard extends StatelessWidget {
  const RepairJobCard({
    super.key,
    required this.job,
    required this.technicianName,
    required this.selected,
    required this.onTap,
    required this.onToggleSelect,
    this.onMove,
  });

  final RepairJob job;

  /// Resolved technician name, null when the job is unassigned.
  final String? technicianName;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onToggleSelect;

  /// Null when the signed-in user cannot change status.
  final VoidCallback? onMove;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;

    return Semantics(
      button: true,
      selected: selected,
      label: '${job.jobNumber}, ${job.deviceType}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onToggleSelect,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: ClayContainer(
            variant: ClayVariant.soft,
            color: lum.surface,
            borderRadius: AppRadius.lg,
            isDark: lum.isDark,
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    _SelectBox(selected: selected, onTap: onToggleSelect),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        job.jobNumber,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.monoValue.copyWith(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: lum.g500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    RepairPriorityChip(priority: job.priority),
                  ],
                ),
                const SizedBox(height: 9),
                Text(
                  job.deviceType,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.headline.copyWith(
                    fontSize: 14.5,
                    height: 1.25,
                    color: lum.textPrimary,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  job.reportedIssue,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.subhead.copyWith(
                    fontSize: 12.5,
                    height: 1.4,
                    color: lum.g600,
                  ),
                ),
                const SizedBox(height: 11),
                Row(
                  children: [
                    Expanded(
                      child: technicianName != null
                          ? Row(
                              children: [
                                RepairTechAvatar(name: technicianName),
                                const SizedBox(width: 7),
                                Expanded(
                                  child: Text(
                                    technicianName!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.caption.copyWith(
                                      fontSize: 12,
                                      color: lum.g600,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                Icon(LucideIcons.userPlus,
                                    size: 14, color: lum.g400),
                                const SizedBox(width: 5),
                                Text(
                                  'Unassigned',
                                  style: AppTypography.caption.copyWith(
                                    fontSize: 12,
                                    color: lum.g400,
                                  ),
                                ),
                              ],
                            ),
                    ),
                    if (onMove != null) _MoveButton(onTap: onMove!),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectBox extends StatelessWidget {
  const _SelectBox({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Semantics(
      checked: selected,
      label: 'Select job',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        // The box itself is 18px per the design; the tap target stays 44.
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: selected ? lum.accent : lum.surface2,
                borderRadius: BorderRadius.circular(5),
              ),
              child: selected
                  ? const Icon(LucideIcons.check, size: 11, color: Colors.white)
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _MoveButton extends StatelessWidget {
  const _MoveButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Semantics(
      button: true,
      label: 'Change status',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 44,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: lum.surface2,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Move',
                    style: AppTypography.label.copyWith(
                      fontSize: 11.5,
                      color: lum.g600,
                    ),
                  ),
                  Icon(LucideIcons.chevronDown, size: 14, color: lum.g600),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
