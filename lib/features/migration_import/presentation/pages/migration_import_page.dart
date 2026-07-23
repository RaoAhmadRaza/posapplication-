import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_detail_scaffold.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../../auth/presentation/controllers/branch_controller.dart';
import '../../domain/entities/import_result.dart';
import '../controllers/migration_import_controller.dart';
import '../widgets/import_log_panel.dart';
import '../widgets/import_step_card.dart';

/// One-time bulk migration from a lumina-bak-tool bundle: four CSVs imported in
/// FK order, each step unlocking the next. Reached from Settings.
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
      columns: ['id', 'name', 'slug', 'is_active', 'sort_order'],
    ),
    (
      kind: ImportTableKind.brands,
      title: 'Brands',
      columns: ['id', 'name', 'slug', 'is_active'],
    ),
    (
      kind: ImportTableKind.products,
      title: 'Products',
      columns: [
        'id', 'sku', 'barcode', 'name', 'description',
        'brand_id', 'category_id', 'selling_price', 'cost_price',
        'min_selling_price', 'wholesale_price', 'unit_of_measure',
        'tax_rate', 'reorder_point', 'is_active', 'status', 'type',
      ],
    ),
    (
      kind: ImportTableKind.stock,
      title: 'Stock balances',
      columns: ['product_id', 'qty_on_hand', 'avg_cost'],
    ),
  ];

  bool _isEnabled(int index) {
    if (index == 0) return true;
    return _completed.contains(_steps[index - 1].kind);
  }

  String? _disabledReason(int index) {
    if (_isEnabled(index)) return null;
    return 'Import ${_steps[index - 1].title.toLowerCase()} first.';
  }

  Future<void> _import(ImportTableKind kind, String? branchId) async {
    final notifier = ref.read(migrationImportProvider.notifier);
    if (kind == ImportTableKind.stock) {
      await notifier.run(kind, branchId: branchId);
    } else {
      await notifier.run(kind);
    }
    final result = ref.read(migrationImportProvider).result;
    setState(() {
      _results[kind] = result;
      if (result != null && result.ok > 0) _completed.add(kind);
    });
  }

  @override
  Widget build(BuildContext context) {
    final branch = ref.watch(currentBranchProvider);
    final state = ref.watch(migrationImportProvider);

    return PermissionGate(
      module: 'inventory',
      action: 'create',
      child: AppDetailScaffold(
        eyebrow: 'Settings',
        title: 'Import migration',
        description:
            'Import your four CSVs in order — each step unlocks the next.',
        maxContentWidth: 760,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _InfoBanner(branchName: branch?.name ?? '—'),
            if (state.failure != null) ...[
              const SizedBox(height: AppSpacing.base),
              AppInlineBanner(
                message: state.failure!.message,
                type: BannerType.error,
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            for (var i = 0; i < _steps.length; i++) ...[
              if (i > 0) const SizedBox(height: AppSpacing.base),
              ImportStepCard(
                stepNumber: i + 1,
                kind: _steps[i].kind,
                title: _steps[i].title,
                columns: _steps[i].columns,
                enabled: _isEnabled(i),
                isDone: _completed.contains(_steps[i].kind),
                isStock: _steps[i].kind == ImportTableKind.stock,
                hasBranch: branch?.id != null,
                result: _results[_steps[i].kind],
                disabledReason: _disabledReason(i),
                onChoose: () => ref
                    .read(migrationImportProvider.notifier)
                    .pickAndParse(_steps[i].kind),
                onImport: () => _import(_steps[i].kind, branch?.id),
              ),
            ],
            if (state.logs.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              ImportLogPanel(logs: state.logs),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.branchName});

  final String branchName;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: lum.accentSoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.info, size: 18, color: lum.accentPress),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: AppTypography.subhead.copyWith(color: lum.accentPress),
                children: [
                  const TextSpan(text: 'Data imports into your tenant · '),
                  TextSpan(
                    text: branchName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const TextSpan(
                    text: ' branch. Re-running is safe — duplicates are '
                        'skipped automatically.',
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
