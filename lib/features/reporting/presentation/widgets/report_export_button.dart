import 'package:flutter/material.dart';
import '../../../../core/design/app_colors.dart';
import '../../data/services/report_export.dart';

/// AppBar action: exports the current report table to PDF or CSV.
/// `build` is called on tap so the latest loaded rows are captured.
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
    return PopupMenuButton<String>(
      icon: const Icon(Icons.ios_share, color: AppColors.accent, size: 22),
      tooltip: 'Export',
      onSelected: (v) {
        final rows = rowsBuilder();
        if (rows.isEmpty) return;
        if (v == 'pdf') {
          ReportExport.pdf(title: title, headers: headers, rows: rows);
        } else {
          ReportExport.csv(title: title, headers: headers, rows: rows);
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'pdf', child: Text('Export PDF')),
        PopupMenuItem(value: 'csv', child: Text('Export CSV')),
      ],
    );
  }
}
