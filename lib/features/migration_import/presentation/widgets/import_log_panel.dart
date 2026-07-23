import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_toast.dart';
import 'migration_ui.dart';

/// Dark terminal-style import log: collapsible, copyable, uniform mono lines
/// with a greyed timestamp. Tone is NOT inferred from line text (see plan).
class ImportLogPanel extends StatefulWidget {
  const ImportLogPanel({super.key, required this.logs});

  final List<String> logs;

  @override
  State<ImportLogPanel> createState() => _ImportLogPanelState();
}

class _ImportLogPanelState extends State<ImportLogPanel> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;

    // The panel is intentionally dark in light mode; in Counter mode `lum.ink`
    // flips light, so use an elevated surface instead of a fixed dark.
    final panelBg = lum.isDark ? lum.surface2 : const Color(0xFF10131C);
    final headText = lum.isDark ? lum.textPrimary : Colors.white;
    final metaText = lum.isDark ? lum.textTertiary : const Color(0xFF8A90A2);
    final msgText = lum.isDark ? lum.textPrimary : const Color(0xFFDDE1EC);
    final divider = lum.isDark
        ? lum.hairline
        : Colors.white.withValues(alpha: 0.08);

    return Container(
      decoration: BoxDecoration(
        color: panelBg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.base,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _expanded = !_expanded),
                    child: Row(
                      children: [
                        Icon(
                          _expanded
                              ? LucideIcons.chevronDown
                              : LucideIcons.chevronRight,
                          size: 16,
                          color: metaText,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Icon(LucideIcons.terminal, size: 15, color: headText),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          'Import log',
                          style: AppTypography.subhead.copyWith(
                            fontWeight: FontWeight.w600,
                            color: headText,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          '${widget.logs.length} entries',
                          style: AppTypography.caption.copyWith(
                            fontFamily: AppTypography.mono,
                            color: metaText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _CopyButton(
                  logs: widget.logs,
                  color: headText,
                  border: divider,
                ),
              ],
            ),
          ),
          if (_expanded)
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: divider)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.base,
                  AppSpacing.sm,
                  AppSpacing.base,
                  AppSpacing.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final line in widget.logs)
                      _LogRow(line: line, time: metaText, message: msgText),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LogRow extends StatelessWidget {
  const _LogRow({required this.line, required this.time, required this.message});

  final String line;
  final Color time;
  final Color message;

  @override
  Widget build(BuildContext context) {
    final (t, m) = splitLogLine(line);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: SelectionArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t,
              style: AppTypography.caption.copyWith(
                fontFamily: AppTypography.mono,
                color: time,
                height: 1.4,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                m,
                style: AppTypography.caption.copyWith(
                  fontFamily: AppTypography.mono,
                  color: message,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CopyButton extends StatelessWidget {
  const _CopyButton({
    required this.logs,
    required this.color,
    required this.border,
  });

  final List<String> logs;
  final Color color;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Copy import log',
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        onTap: () {
          Clipboard.setData(ClipboardData(text: logs.join('\n')));
          showAppToast(context, 'Import log copied', type: BannerType.success);
        },
        child: Container(
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.copy, size: 14, color: color),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Copy',
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
