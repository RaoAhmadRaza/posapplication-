import 'dart:convert';
import 'dart:io' show File;

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
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
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
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
      setState(() => _error = 'Could not read file contents.');
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.accent, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _done ? 'Import Result' : 'Import Products',
          style: AppTypography.headline,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.lg),
              if (_error != null) ...[
                AppInlineBanner(message: _error!, type: BannerType.error),
                const SizedBox(height: AppSpacing.lg),
              ],
              if (_done)
                _buildResult()
              else if (_picked)
                _buildMapping()
              else
                _buildPickStep(),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPickStep() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.xxxl),
          decoration: BoxDecoration(
            color: AppColors.fieldFill,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
              color: AppColors.separator,
              width: 1,
              strokeAlign: BorderSide.strokeAlignInside,
            ),
          ),
          child: Column(
            children: [
              const Icon(Icons.file_upload_outlined, size: 48, color: AppColors.textHint),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Select a CSV file',
                style: AppTypography.subhead.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Columns will be mapped to product fields.',
                style: AppTypography.footnote.copyWith(color: AppColors.textHint),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: 'Choose File',
                onPressed: _pickFile,
                icon: Icons.file_open,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Expected columns: name (required), barcode, category_name, brand_name, cost_price, selling_price, unit_of_measure',
          style: AppTypography.caption.copyWith(color: AppColors.textHint),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildMapping() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '$_fileName · $_totalRowCount rows',
                style: AppTypography.headline,
              ),
            ),
            AppButton(
              label: 'Re-pick',
              variant: AppButtonVariant.plain,
              onPressed: _pickFile,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text('Column Mapping', style: AppTypography.fieldLabel),
        const SizedBox(height: AppSpacing.sm),
        ..._mappings.map((m) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _MappingRow(
                sourceName: m.sourceName,
                value: m.targetField,
                fields: _targetFields,
                onChanged: (v) => setState(() => m.targetField = v),
              ),
            )),
        if (!_hasNameMapped)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              'Map at least one column to "name".',
              style: AppTypography.caption.copyWith(color: AppColors.destructive),
            ),
          ),
        if (_hasNameMapped) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            '$_validRowCount valid rows · ${_totalRowCount - _validRowCount} missing name',
            style: AppTypography.footnote.copyWith(color: AppColors.textMuted),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Text('Preview (first ${_previewRows.length} rows)', style: AppTypography.fieldLabel),
        const SizedBox(height: AppSpacing.sm),
        _buildPreviewTable(),
        const SizedBox(height: AppSpacing.xl),
        PermissionGate(
          module: 'inventory',
          action: 'create',
          child: AppButton(
            label: 'Import $_validRowCount products',
            loading: _importing,
            fullWidth: true,
            onPressed: _hasNameMapped && _validRowCount > 0 ? _import : null,
            icon: Icons.upload,
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewTable() {
    final colMap = <String, int>{};
    for (final m in _mappings) {
      if (m.targetField != null) colMap[m.targetField!] = m.sourceIndex;
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.separator, width: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.field),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingTextStyle: AppTypography.caption.copyWith(
            color: AppColors.textMuted,
            fontWeight: FontWeight.w600,
          ),
          dataTextStyle: AppTypography.caption,
          columnSpacing: AppSpacing.base,
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
                        ? AppTypography.caption.copyWith(color: AppColors.textHint)
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.check_circle, color: AppColors.success, size: 28),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Import complete',
                    style: AppTypography.headline,
                  ),
                  Text(
                    '$_okCount ok · $_failCount failed',
                    style: AppTypography.footnote.copyWith(color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (_importErrors.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          Text('Errors', style: AppTypography.fieldLabel),
          const SizedBox(height: AppSpacing.sm),
          ..._importErrors.take(10).map((e) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Text(
                  'Row ${e['row']}: ${e['error']}',
                  style: AppTypography.caption.copyWith(color: AppColors.destructive),
                ),
              )),
        ],
        const SizedBox(height: AppSpacing.xl),
        AppButton(
          label: 'Import Another',
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(AppRadius.field),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              sourceName,
              style: AppTypography.caption.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const Text('→', style: TextStyle(color: AppColors.textHint, fontSize: 14)),
          const SizedBox(width: AppSpacing.sm),
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            decoration: BoxDecoration(
              color: value != null
                  ? AppColors.accent.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButton<String?>(
              value: value,
              underline: const SizedBox.shrink(),
              hint: Text(
                'Ignore',
                style: AppTypography.caption.copyWith(color: AppColors.textHint),
              ),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Ignore', style: AppTypography.caption),
                ),
                ...fields.map((f) => DropdownMenuItem(
                      value: f,
                      child: Text(f, style: AppTypography.caption),
                    )),
              ],
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
