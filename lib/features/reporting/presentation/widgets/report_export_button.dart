import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/clay.dart';
import '../../data/services/report_export.dart';

/// Header action: exports the current report table to PDF or CSV. Presented as
/// the design's clay "Export" button dropping a PDF/CSV menu.
///
/// `rowsBuilder` is called on selection so the latest loaded rows are captured.
class ReportExportButton extends StatelessWidget {
  const ReportExportButton({
    super.key,
    required this.title,
    required this.headers,
    required this.rowsBuilder,
  });

  final String title;
  final List<String> headers;
  final List<List<String>> Function() rowsBuilder;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return PopupMenuButton<String>(
      tooltip: 'Export',
      offset: const Offset(0, 48),
      color: lum.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: lum.hairline),
      ),
      onSelected: (v) {
        final rows = rowsBuilder();
        if (rows.isEmpty) return;
        if (v == 'pdf') {
          ReportExport.pdf(title: title, headers: headers, rows: rows);
        } else {
          ReportExport.csv(title: title, headers: headers, rows: rows);
        }
      },
      itemBuilder: (context) => [
        _item(context, 'pdf', LucideIcons.fileText, 'Export PDF', lum.dangerText),
        _item(context, 'csv', LucideIcons.table, 'Export CSV', lum.successText),
      ],
      child: ClayContainer(
        variant: ClayVariant.soft,
        color: lum.surface,
        borderRadius: AppRadius.sm,
        isDark: lum.isDark,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.share, size: 17, color: lum.g600),
            const SizedBox(width: 9),
            Text(
              'Export',
              style: AppTypography.label.copyWith(color: lum.textPrimary),
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _item(
    BuildContext context,
    String value,
    IconData icon,
    String label,
    Color iconColor,
  ) {
    final lum = context.lum;
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 17, color: iconColor),
          const SizedBox(width: 11),
          Text(
            label,
            style: AppTypography.body.copyWith(color: lum.textPrimary),
          ),
        ],
      ),
    );
  }
}
