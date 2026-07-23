import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/clay.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../domain/entities/import_result.dart';
import '../controllers/migration_import_controller.dart';
import 'migration_ui.dart';

enum _StepStatus { locked, idle, parsed, running, result }

/// One import step, rendering all five states off the shared controller state.
/// It watches [migrationImportProvider] itself (like the old page did) and
/// calls back to the page for pick/import so the page keeps owning the
/// completed-set + local result. No controller signature changes.
class ImportStepCard extends ConsumerWidget {
  const ImportStepCard({
    super.key,
    required this.stepNumber,
    required this.kind,
    required this.title,
    required this.columns,
    required this.enabled,
    required this.isDone,
    required this.isStock,
    required this.hasBranch,
    required this.result,
    required this.disabledReason,
    required this.onChoose,
    required this.onImport,
  });

  final int stepNumber;
  final ImportTableKind kind;
  final String title;
  final List<String> columns;
  final bool enabled;
  final bool isDone;
  final bool isStock;
  final bool hasBranch;
  final ImportResult? result;
  final String? disabledReason;
  final VoidCallback onChoose;
  final Future<void> Function() onImport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lum = context.lum;
    final state = ref.watch(migrationImportProvider);

    final isMine = state.kind == kind;
    final isRunning = state.running && isMine;
    final isParsed = !state.running && isMine && state.fileName != null;
    final status = !enabled
        ? _StepStatus.locked
        : isRunning
            ? _StepStatus.running
            : isDone
                ? _StepStatus.result
                : isParsed
                    ? _StepStatus.parsed
                    : _StepStatus.idle;

    return Opacity(
      opacity: status == _StepStatus.locked ? 0.72 : 1,
      child: ClayContainer(
        variant: status == _StepStatus.parsed || status == _StepStatus.running
            ? ClayVariant.raised
            : ClayVariant.soft,
        color: lum.surface,
        borderRadius: AppRadius.lg,
        isDark: lum.isDark,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(context, status),
            _body(context, state, status),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, _StepStatus status) {
    final lum = context.lum;
    final locked = status == _StepStatus.locked;
    return Row(
      children: [
        ClayContainer(
          variant: ClayVariant.soft,
          color: locked ? lum.g100 : lum.accentSoft,
          borderRadius: 14,
          isDark: lum.isDark,
          width: 46,
          height: 46,
          child: Center(
            child: Icon(
              migrationKindIcon(kind),
              size: 22,
              color: locked ? lum.g400 : lum.accent,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Step $stepNumber · $title',
                style: AppTypography.title3.copyWith(
                  fontSize: 17,
                  color: locked ? lum.textTertiary : lum.textPrimary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                columns.join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(
                  fontFamily: AppTypography.mono,
                  color: lum.g500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        _statusPill(status),
      ],
    );
  }

  Widget _statusPill(_StepStatus status) {
    final (String label, AppPillTone tone) = switch (status) {
      _StepStatus.locked => ('Locked', AppPillTone.neutral),
      _StepStatus.idle => ('Ready', AppPillTone.lumen),
      _StepStatus.parsed => ('Preview', AppPillTone.lumen),
      _StepStatus.running => ('Importing', AppPillTone.warning),
      _StepStatus.result => result != null && result!.failed == 0
          ? ('Imported', AppPillTone.success)
          : ('Done · errors', AppPillTone.warning),
    };
    return AppPill(label: label, tone: tone);
  }

  Widget _body(
    BuildContext context,
    MigrationImportState state,
    _StepStatus status,
  ) {
    final top = const SizedBox(height: AppSpacing.base);
    return switch (status) {
      _StepStatus.locked =>
        Column(children: [top, _lockedNote(context)]),
      _StepStatus.idle => Column(children: [top, _idleRow(context)]),
      _StepStatus.running => Column(children: [top, _runningState(context, state)]),
      _StepStatus.parsed =>
        Column(children: [top, _parsedState(context, state)]),
      _StepStatus.result =>
        Column(children: [top, _resultState(context)]),
    };
  }

  Widget _lockedNote(BuildContext context) {
    final lum = context.lum;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: lum.g100,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: lum.hairline2),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.lock, size: 16, color: lum.g500),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              disabledReason ?? 'Complete the previous step first.',
              style: AppTypography.subhead.copyWith(color: lum.g500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _idleRow(BuildContext context) {
    final lum = context.lum;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            'CSV only · columns matched to the fields above.',
            style: AppTypography.subhead.copyWith(color: lum.g500),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        AppButton(
          label: 'Choose CSV',
          icon: LucideIcons.upload,
          onPressed: onChoose,
        ),
      ],
    );
  }

  Widget _runningState(BuildContext context, MigrationImportState state) {
    final lum = context.lum;
    final progress = state.progress;
    final total = progress?.total ?? 0;
    final done = progress?.done ?? 0;
    final pct = total > 0 ? (done / total).clamp(0.0, 1.0) : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation(lum.accent),
                backgroundColor: lum.accentSoft,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(
              total > 0 ? 'Importing… $done / $total' : 'Importing…',
              style: AppTypography.monoValue.copyWith(color: lum.textPrimary),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 8,
            backgroundColor: lum.surface2,
            valueColor: AlwaysStoppedAnimation(lum.accent),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Please keep this screen open.',
          style: AppTypography.caption.copyWith(color: lum.g500),
        ),
      ],
    );
  }

  Widget _parsedState(BuildContext context, MigrationImportState state) {
    final lum = context.lum;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(LucideIcons.fileText, size: 16, color: lum.g500),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                state.fileName ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(
                  fontFamily: AppTypography.mono,
                  color: lum.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '· ${state.parsedRowCount} rows · ${columns.length} columns',
              style: AppTypography.caption.copyWith(color: lum.g500),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (state.preview.isNotEmpty) _PreviewTable(preview: state.preview),
        const SizedBox(height: AppSpacing.base),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                'Showing first ${state.preview.length} of '
                '${state.parsedRowCount} rows',
                style: AppTypography.caption.copyWith(color: lum.g500),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            AppButton(
              label: 'Import ${state.parsedRowCount} rows',
              icon: LucideIcons.arrowRight,
              onPressed: () => onImport(),
            ),
          ],
        ),
        if (isStock && hasBranch) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Imports into the current branch.',
            style: AppTypography.caption.copyWith(color: lum.g500),
          ),
        ],
      ],
    );
  }

  Widget _resultState(BuildContext context) {
    final lum = context.lum;
    final r = result;
    if (r == null) return const SizedBox.shrink();
    final ok = r.failed == 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.base,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: ok ? lum.successSoft : lum.warningSoft,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                ok ? LucideIcons.circleCheckBig : LucideIcons.triangleAlert,
                size: 18,
                color: ok ? lum.successText : lum.warningText,
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  'Imported ${r.inserted}, skipped ${r.skipped}, '
                  'failed ${r.failed}',
                  style: AppTypography.subhead.copyWith(
                    fontWeight: FontWeight.w600,
                    color: ok ? lum.successText : lum.warningText,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (r.errors.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _ErrorAccordion(errors: r.errors),
        ],
        const SizedBox(height: AppSpacing.base),
        Row(
          children: [
            AppButton(
              label: 'Choose another CSV',
              variant: AppButtonVariant.plain,
              size: AppButtonSize.sm,
              icon: LucideIcons.upload,
              onPressed: onChoose,
            ),
            const SizedBox(width: AppSpacing.md),
            Flexible(
              child: Text(
                'Re-running is safe — duplicates are skipped.',
                style: AppTypography.caption.copyWith(color: lum.g500),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Collapsible list of failed rows.
class _ErrorAccordion extends StatefulWidget {
  const _ErrorAccordion({required this.errors});

  final List<ImportRowError> errors;

  @override
  State<_ErrorAccordion> createState() => _ErrorAccordionState();
}

class _ErrorAccordionState extends State<_ErrorAccordion> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final n = widget.errors.length;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: lum.warningSoft),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Semantics(
            button: true,
            expanded: _expanded,
            child: InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Container(
                color: lum.warningSoft,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.base,
                  vertical: AppSpacing.md,
                ),
                child: Row(
                  children: [
                    Icon(LucideIcons.triangleAlert,
                        size: 16, color: lum.warningText),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        '$n row${n == 1 ? '' : 's'} failed — tap to review',
                        style: AppTypography.subhead.copyWith(
                          fontWeight: FontWeight.w600,
                          color: lum.warningText,
                        ),
                      ),
                    ),
                    Icon(
                      _expanded
                          ? LucideIcons.chevronUp
                          : LucideIcons.chevronDown,
                      size: 16,
                      color: lum.warningText,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_expanded)
            Container(
              width: double.infinity,
              color: lum.surface,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: SelectionArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final e in widget.errors)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.base,
                          vertical: 6,
                        ),
                        child: Text(
                          'Row ${e.row}: ${e.error}',
                          style: AppTypography.caption.copyWith(
                            fontFamily: AppTypography.mono,
                            color: lum.dangerText,
                          ),
                        ),
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

/// Mono CSV preview. Horizontal scroll lives in its own box so the page body
/// never scrolls sideways. Header is not sticky (single Table) — a small,
/// deliberate deviation from the export's sticky header.
class _PreviewTable extends StatelessWidget {
  const _PreviewTable({required this.preview});

  final List<Map<String, dynamic>> preview;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final headers = preview.first.keys.toList();

    String trunc(Object? v) {
      final s = v?.toString() ?? '';
      return s.length > 30 ? '${s.substring(0, 27)}…' : s;
    }

    TableRow headerRow() => TableRow(
          decoration: BoxDecoration(color: lum.surface2),
          children: [
            for (final h in headers)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Text(
                  h,
                  style: AppTypography.caption.copyWith(
                    fontFamily: AppTypography.mono,
                    fontWeight: FontWeight.w600,
                    color: lum.g600,
                  ),
                ),
              ),
          ],
        );

    TableRow dataRow(Map<String, dynamic> row, int i) => TableRow(
          decoration: BoxDecoration(
            color: i.isOdd ? lum.g100 : lum.surface,
          ),
          children: [
            for (final h in headers)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Text(
                  trunc(row[h]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    fontFamily: AppTypography.mono,
                    color: lum.g700,
                  ),
                ),
              ),
          ],
        );

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: lum.hairline),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 224),
          child: SingleChildScrollView(
            child: Table(
              defaultColumnWidth: const IntrinsicColumnWidth(),
              children: [
                headerRow(),
                for (var i = 0; i < preview.length; i++)
                  dataRow(preview[i], i),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
