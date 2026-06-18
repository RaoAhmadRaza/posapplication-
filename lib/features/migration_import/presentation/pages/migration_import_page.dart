import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../../auth/presentation/controllers/branch_controller.dart';
import '../../domain/entities/import_result.dart';
import '../controllers/migration_import_controller.dart';

class MigrationImportPage extends ConsumerStatefulWidget {
  const MigrationImportPage({super.key});

  @override
  ConsumerState<MigrationImportPage> createState() =>
      _MigrationImportPageState();
}

class _MigrationImportPageState extends ConsumerState<MigrationImportPage> {
  final _results = <ImportTableKind, ImportResult?>{};
  final _completed = <ImportTableKind>{};

  static const _steps = [
    (
      kind: ImportTableKind.categories,
      title: 'Categories',
      icon: Icons.category,
      fields: ['id', 'name', 'slug', 'is_active', 'sort_order'],
    ),
    (
      kind: ImportTableKind.brands,
      title: 'Brands',
      icon: Icons.branding_watermark,
      fields: ['id', 'name', 'slug', 'is_active'],
    ),
    (
      kind: ImportTableKind.products,
      title: 'Products',
      icon: Icons.inventory_2,
      fields: [
        'id', 'sku', 'barcode', 'name', 'description',
        'brand_id', 'category_id', 'selling_price', 'cost_price',
        'min_selling_price', 'wholesale_price', 'unit_of_measure',
        'tax_rate', 'reorder_point', 'is_active', 'status', 'type',
      ],
    ),
    (
      kind: ImportTableKind.stock,
      title: 'Stock Balances',
      icon: Icons.bar_chart,
      fields: ['product_id', 'qty_on_hand', 'avg_cost'],
    ),
  ];

  bool _isEnabled(int index) {
    if (index == 0) return true;
    return _completed.contains(_steps[index - 1].kind);
  }

  String? _disabledReason(int index) {
    if (_isEnabled(index)) return null;
    return 'Import ${_steps[index - 1].title.toLowerCase()} first';
  }

  @override
  Widget build(BuildContext context) {
    final branch = ref.watch(currentBranchProvider);
    final importState = ref.watch(migrationImportProvider);

    return PermissionGate(
      module: 'inventory',
      action: 'create',
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          surfaceTintColor: AppColors.background,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios,
                color: AppColors.accent, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text('Import Data', style: AppTypography.headline),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.lg),
                _buildHeaderNote(branch?.name ?? '—'),
                if (importState.failure != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  AppInlineBanner(
                    message: importState.failure!.message,
                    type: BannerType.error,
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                for (var i = 0; i < _steps.length; i++) ...[
                  if (i > 0) const SizedBox(height: AppSpacing.md),
                  _buildStepCard(i, branch?.id),
                ],
                if (importState.logs.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xl),
                  _LogsPanel(logs: importState.logs),
                ],
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderNote(String branchName) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.separator, width: 0.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.accent, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Data imports into your tenant / $branchName branch. '
              'Re-running is safe (duplicates are skipped).',
              style: AppTypography.footnote.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepCard(int index, String? branchId) {
    final step = _steps[index];
    final enabled = _isEnabled(index);
    final reason = _disabledReason(index);
    final state = ref.watch(migrationImportProvider);
    final isActive =
        !state.running && state.kind == step.kind && state.fileName != null;
    final isRunning = state.running && state.kind == step.kind;
    final localResult = _results[step.kind];
    final isDone = _completed.contains(step.kind);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: AppColors.separator,
          width: 0.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.base),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCardHeader(
              index: index + 1,
              icon: step.icon,
              title: step.title,
              fields: step.fields,
              enabled: enabled,
              isDone: isDone,
            ),
            if (enabled) ...[
              const SizedBox(height: AppSpacing.md),
              if (!isActive && !isRunning && !isDone)
                _buildPickButton(step.kind)
              else if (isRunning)
                _buildRunningState(state)
              else if (isActive)
                _buildParsedState(state, step.kind, branchId)
              else if (isDone) ...[
                _buildResultState(localResult),
                const SizedBox(height: AppSpacing.sm),
                _buildPickButton(step.kind),
              ],
            ] else ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                reason!,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textHint,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCardHeader({
    required int index,
    required IconData icon,
    required String title,
    required List<String> fields,
    required bool enabled,
    required bool isDone,
  }) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isDone
                ? AppColors.success.withValues(alpha: 0.12)
                : enabled
                    ? AppColors.accent.withValues(alpha: 0.1)
                    : AppColors.fieldFill,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isDone ? Icons.check_circle : icon,
            size: 16,
            color: isDone
                ? AppColors.success
                : enabled
                    ? AppColors.accent
                    : AppColors.textHint,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$index. $title',
                style: AppTypography.headline.copyWith(
                  color: enabled
                      ? AppColors.textPrimary
                      : AppColors.textHint,
                ),
              ),
              Text(
                'Columns: ${fields.join(', ')}',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textHint,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPickButton(ImportTableKind kind) {
    return AppButton(
      label: 'Choose CSV',
      variant: AppButtonVariant.tinted,
      icon: Icons.file_open,
      onPressed: () async {
        await ref.read(migrationImportProvider.notifier).pickAndParse(kind);
      },
    );
  }

  Widget _buildRunningState(MigrationImportState state) {
    final progress = state.progress;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          const CircularProgressIndicator(color: AppColors.accent),
          if (progress != null && progress.total > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Importing… ${progress.done} / ${progress.total}',
              style: AppTypography.caption.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildParsedState(
    MigrationImportState state,
    ImportTableKind kind,
    String? branchId,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.description, color: AppColors.textMuted, size: 16),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                '${state.fileName} · ${state.parsedRowCount} rows',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (state.preview.isNotEmpty) _buildPreviewTable(state.preview),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Import ${state.parsedRowCount} rows',
                fullWidth: true,
                icon: Icons.upload,
                onPressed: () async {
                  final notifier =
                      ref.read(migrationImportProvider.notifier);
                  if (kind == ImportTableKind.stock) {
                    await notifier.run(kind, branchId: branchId);
                  } else {
                    await notifier.run(kind);
                  }
                  final result = ref.read(migrationImportProvider).result;
                  setState(() {
                    _results[kind] = result;
                    if (result != null && result.ok > 0) {
                      _completed.add(kind);
                    }
                  });
                },
              ),
            ),
          ],
        ),
        if (kind == ImportTableKind.stock && branchId != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Importing into current branch',
            style: AppTypography.caption.copyWith(
              color: AppColors.textHint,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPreviewTable(List<Map<String, dynamic>> preview) {
    if (preview.isEmpty) return const SizedBox.shrink();

    final headers = preview.first.keys.toList();

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
          dataTextStyle: AppTypography.caption.copyWith(fontSize: 11),
          columnSpacing: AppSpacing.sm,
          dataRowMinHeight: 28,
          dataRowMaxHeight: 32,
          columns: headers
              .map((h) => DataColumn(
                  label: Text(h,
                      style: const TextStyle(fontSize: 11))))
              .toList(),
          rows: preview.map((row) {
            return DataRow(
              cells: headers.map((h) {
                final v = row[h]?.toString() ?? '';
                return DataCell(Text(
                  v.length > 30 ? '${v.substring(0, 27)}...' : v,
                  style: const TextStyle(fontSize: 11),
                ));
              }).toList(),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildResultState(ImportResult? result) {
    if (result == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: result.failed == 0
                ? AppColors.success.withValues(alpha: 0.08)
                : Colors.orange.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppRadius.field),
          ),
          child: Row(
            children: [
              Icon(
                result.failed == 0
                    ? Icons.check_circle
                    : Icons.warning_amber_rounded,
                size: 18,
                color: result.failed == 0
                    ? AppColors.success
                    : Colors.orange,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Imported ${result.inserted}, Skipped ${result.skipped}, Failed ${result.failed}',
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (result.errors.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          _ErrorList(errors: result.errors),
        ],
      ],
    );
  }
}

class _ErrorList extends StatefulWidget {
  const _ErrorList({required this.errors});
  final List<ImportRowError> errors;

  @override
  State<_ErrorList> createState() => _ErrorListState();
}

class _ErrorListState extends State<_ErrorList> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Row(
            children: [
              Icon(
                _expanded
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                size: 16,
                color: AppColors.destructive,
              ),
              const SizedBox(width: 4),
              Text(
                '${widget.errors.length} error${widget.errors.length == 1 ? '' : 's'}',
                style: AppTypography.caption.copyWith(
                  color: AppColors.destructive,
                ),
              ),
            ],
          ),
        ),
        if (_expanded) ...[
          const SizedBox(height: AppSpacing.xs),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.destructive.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(AppRadius.field),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: widget.errors.map((e) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    'Row ${e.row}: ${e.error}',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.destructive,
                      fontSize: 11,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }
}

class _LogsPanel extends StatefulWidget {
  const _LogsPanel({required this.logs});
  final List<String> logs;

  @override
  State<_LogsPanel> createState() => _LogsPanelState();
}

class _LogsPanelState extends State<_LogsPanel> {
  bool _expanded = true;
  final _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.separator, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.base,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_right,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'Logs (${widget.logs.length})',
                    style: AppTypography.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(
                        ClipboardData(text: widget.logs.join('\n')),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Logs copied to clipboard'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    child: Text(
                      'Copy',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppColors.separator, width: 0.5),
                ),
              ),
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: SelectableText(
                  widget.logs.join('\n'),
                  style: TextStyle(
                    fontFamily: 'Courier',
                    fontSize: 10,
                    color: AppColors.textPrimary,
                    height: 1.4,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
