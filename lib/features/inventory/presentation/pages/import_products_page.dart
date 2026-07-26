import 'dart:convert';
import 'dart:io' show File;

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/clay.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_detail_scaffold.dart';
import '../../../../core/design/widgets/app_dropdown.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_section_card.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../controllers/products_controller.dart';

class ImportProductsPage extends ConsumerStatefulWidget {
  const ImportProductsPage({super.key});

  @override
  ConsumerState<ImportProductsPage> createState() => _ImportProductsPageState();
}

class _RowMapping {
  final int sourceIndex;
  final String sourceName;
  String? targetField;

  _RowMapping({required this.sourceIndex, required this.sourceName, this.targetField});
}

class _ImportProductsPageState extends ConsumerState<ImportProductsPage> {
  final List<String> _targetFields = const [
    'name',
    'barcode',
    'category_name',
    'brand_name',
    'cost_price',
    'selling_price',
    'unit_of_measure',
  ];

  bool _picked = false;
  String _fileName = '';
  List<List<dynamic>> _rows = [];
  List<_RowMapping> _mappings = [];
  bool _importing = false;
  String? _error;
  int _okCount = 0;
  int _failCount = 0;
  List<Map<String, dynamic>> _importErrors = [];
  bool _done = false;

  // --- Pick ---

  Future<void> _pickFile() async {
    final FilePickerResult? result;
    try {
      result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );
    } on PlatformException catch (e) {
      // The picker can refuse before it ever opens — on macOS it rejects the
      // call outright when the sandbox entitlement is missing. Surface that
      // instead of looking like nothing happened.
      if (!mounted) return;
      setState(
        () => _error = "Unable to open the file picker. ${e.message ?? e.code}",
      );
      return;
    }
    if (result == null || result.files.isEmpty) return;

    final f = result.files.first;

    setState(() {
      _picked = true;
      _done = false;
      _error = null;
      _fileName = f.name;
    });

    String content;
    if (f.bytes != null) {
      content = utf8.decode(f.bytes!, allowMalformed: true);
    } else if (f.path != null) {
      content = await File(f.path!).readAsString();
    } else {
      content = '';
    }

    if (content.trim().isEmpty) {
      setState(() => _error = 'Unable to read file contents.');
      return;
    }

    final parsed = Csv().decode(content);
    if (parsed.isEmpty) {
      setState(() => _error = 'The CSV file is empty.');
      return;
    }

    final headerEntries = parsed.first
        .asMap()
        .entries
        .map((e) => MapEntry(e.key, e.value.toString().trim()))
        .toList();
    final rows = parsed.skip(1).take(200).toList();

    final mappings = headerEntries.map((e) {
      final lower = e.value.toLowerCase().trim();
      String? auto;
      for (final tf in _targetFields) {
        if (lower.contains(tf) || lower == tf) {
          auto = tf;
          break;
        }
      }
      return _RowMapping(sourceIndex: e.key, sourceName: e.value, targetField: auto);
    }).toList();

    setState(() {
      _rows = rows;
      _mappings = mappings;
    });
  }

  // --- Mapping ---

  List<Map<String, dynamic>> _buildPayload() {
    final result = <Map<String, dynamic>>[];
    final colMap = <String, int>{};
    for (final m in _mappings) {
      if (m.targetField != null) colMap[m.targetField!] = m.sourceIndex;
    }

    for (final row in _rows) {
      final entry = <String, dynamic>{};
      for (final tf in _targetFields) {
        final idx = colMap[tf];
        if (idx != null && idx < row.length) {
          final raw = row[idx].toString().trim();
          if (raw.isNotEmpty) entry[tf] = raw;
        }
      }
      if (entry['name'] != null) result.add(entry);
    }

    return result;
  }

  int get _validRowCount => _buildPayload().length;
  int get _totalRowCount => _rows.length;
  bool get _hasNameMapped => _mappings.any((m) => m.targetField == 'name');

  List<List<dynamic>> get _previewRows => _rows.take(20).toList();

  // --- Import ---

  Future<void> _import() async {
    if (!_hasNameMapped) {
      setState(() => _error = 'Map at least one column to "name".');
      return;
    }

    final payload = _buildPayload();
    if (payload.isEmpty) {
      setState(() => _error = 'No valid rows (name required).');
      return;
    }

    setState(() {
      _importing = true;
      _error = null;
    });

    final result = await ref
        .read(productsProvider.notifier)
        .bulkImport(payload);

    if (!mounted) return;
    setState(() {
      _importing = false;
      _done = true;
      if (result != null) {
        _okCount = result['ok'] as int? ?? 0;
        _failCount = result['failed'] as int? ?? 0;
        _importErrors = (result['errors'] as List<dynamic>?)
                ?.map((e) => Map<String, dynamic>.from(e))
                .toList() ??
            [];
      }
    });
  }

  // --- Render ---

  @override
  Widget build(BuildContext context) {
    return AppDetailScaffold(
      eyebrow: 'Inventory',
      title: _done ? 'Import result' : 'Import products',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            AppInlineBanner(message: _error!, type: BannerType.error),
            const SizedBox(height: 16),
          ],
          if (_done)
            _buildResult()
          else if (_picked)
            _buildMapping()
          else
            _buildPickStep(),
        ],
      ),
    );
  }

  Widget _buildPickStep() {
    final lum = context.lum;
    return Column(
      children: [
        AppCard(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              ClayContainer(
                variant: ClayVariant.soft,
                color: lum.accentSoft,
                borderRadius: AppRadius.lg,
                isDark: lum.isDark,
                width: 64,
                height: 64,
                child: Center(
                  child: Icon(LucideIcons.fileText, size: 28, color: lum.accent),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Select a CSV file',
                style: AppTypography.headline.copyWith(color: lum.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                'Columns will be mapped to product fields.',
                textAlign: TextAlign.center,
                style: AppTypography.footnote.copyWith(color: lum.textSecondary),
              ),
              const SizedBox(height: 20),
              AppButton(
                label: 'Choose file',
                onPressed: _pickFile,
                icon: LucideIcons.upload,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Expected columns: name (required), barcode, category_name, brand_name, cost_price, selling_price, unit_of_measure',
          textAlign: TextAlign.center,
          style: AppTypography.caption.copyWith(color: lum.textTertiary),
        ),
      ],
    );
  }

  Widget _buildMapping() {
    final lum = context.lum;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '$_fileName · $_totalRowCount rows',
                style: AppTypography.headline.copyWith(color: lum.textPrimary),
              ),
            ),
            AppButton(
              label: 'Re-pick',
              variant: AppButtonVariant.plain,
              size: AppButtonSize.sm,
              onPressed: _pickFile,
            ),
          ],
        ),
        const SizedBox(height: 16),
        AppSectionCard(
          eyebrow: 'Column mapping',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final m in _mappings)
                _MappingRow(
                  sourceName: m.sourceName,
                  value: m.targetField,
                  fields: _targetFields,
                  onChanged: (v) => setState(() => m.targetField = v),
                ),
              if (!_hasNameMapped)
                Text(
                  'Map at least one column to "name".',
                  style: AppTypography.caption.copyWith(color: lum.danger),
                )
              else
                Text(
                  '$_validRowCount valid rows · ${_totalRowCount - _validRowCount} missing name',
                  style: AppTypography.footnote.copyWith(color: lum.textSecondary),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppSectionCard(
          eyebrow: 'Preview (first ${_previewRows.length} rows)',
          child: _buildPreviewTable(),
        ),
        const SizedBox(height: 20),
        PermissionGate(
          module: 'inventory',
          action: 'create',
          child: AppButton(
            label: 'Import $_validRowCount products',
            loading: _importing,
            fullWidth: true,
            onPressed: _hasNameMapped && _validRowCount > 0 ? _import : null,
            icon: LucideIcons.upload,
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewTable() {
    final lum = context.lum;
    final colMap = <String, int>{};
    for (final m in _mappings) {
      if (m.targetField != null) colMap[m.targetField!] = m.sourceIndex;
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: lum.hairline),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingTextStyle: AppTypography.caption.copyWith(
            color: lum.textSecondary,
            fontWeight: FontWeight.w700,
          ),
          dataTextStyle: AppTypography.caption.copyWith(color: lum.textPrimary),
          columnSpacing: 16,
          columns: _targetFields.map((f) => DataColumn(label: Text(f))).toList(),
          rows: _previewRows.map((row) {
            return DataRow(
              selected: row.isNotEmpty &&
                  (colMap['name'] != null &&
                      row.length > colMap['name']! &&
                      row[colMap['name']!].toString().trim().isEmpty),
              cells: _targetFields.map((f) {
                final idx = colMap[f];
                final v = idx != null && idx < row.length
                    ? row[idx].toString().trim()
                    : '';
                return DataCell(
                  Text(
                    v,
                    style: v.isEmpty
                        ? AppTypography.caption.copyWith(color: lum.textTertiary)
                        : null,
                  ),
                );
              }).toList(),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildResult() {
    final lum = context.lum;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Row(
            children: [
              ClayContainer(
                variant: ClayVariant.soft,
                color: lum.successSoft,
                borderRadius: AppRadius.md,
                isDark: lum.isDark,
                width: 48,
                height: 48,
                child: Center(
                  child: Icon(
                    LucideIcons.circleCheckBig,
                    color: lum.successText,
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Import complete',
                      style: AppTypography.headline
                          .copyWith(color: lum.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$_okCount ok · $_failCount failed',
                      style: AppTypography.footnote
                          .copyWith(color: lum.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_importErrors.isNotEmpty) ...[
          const SizedBox(height: 12),
          AppSectionCard(
            eyebrow: 'Errors',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final e in _importErrors.take(10))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      'Row ${e['row']}: ${e['error']}',
                      style: AppTypography.caption.copyWith(color: lum.danger),
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        AppButton(
          label: 'Import another',
          variant: AppButtonVariant.tinted,
          fullWidth: true,
          onPressed: () {
            setState(() {
              _picked = false;
              _done = false;
              _error = null;
              _rows = [];
              _mappings = [];
              _okCount = 0;
              _failCount = 0;
              _importErrors = [];
            });
          },
        ),
      ],
    );
  }
}

class _MappingRow extends StatelessWidget {
  const _MappingRow({
    required this.sourceName,
    required this.value,
    required this.fields,
    required this.onChanged,
  });

  final String sourceName;
  final String? value;
  final List<String> fields;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              sourceName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.subhead.copyWith(
                color: lum.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 156,
            child: AppDropdown<String?>(
              value: value,
              placeholder: 'Ignore',
              options: [
                const AppDropdownOption<String?>(value: null, label: 'Ignore'),
                for (final f in fields)
                  AppDropdownOption<String?>(value: f, label: f),
              ],
              onSelected: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
