import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../domain/entities/barcode_template.dart';
import '../controllers/barcode_templates_controller.dart';

class BarcodeTemplatesPage extends ConsumerWidget {
  const BarcodeTemplatesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.accent, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Barcode Templates', style: AppTypography.headline),
        actions: [
          PermissionGate(
            module: 'inventory',
            action: 'create',
            child: IconButton(
              icon: const Icon(Icons.add, color: AppColors.accent),
              onPressed: () => context.push('/inventory/barcode-templates/create'),
            ),
          ),
        ],
      ),
      body: const _Body(),
    );
  }
}

class _Body extends ConsumerStatefulWidget {
  const _Body();

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(barcodeTemplatesProvider);

    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppInlineBanner(message: 'Could not load templates.', type: BannerType.error),
              const SizedBox(height: AppSpacing.md),
              AppButton(label: 'Retry', onPressed: () => ref.read(barcodeTemplatesProvider.notifier).refresh()),
            ],
          ),
        ),
      ),
      data: (templates) {
        if (templates.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.qr_code_2, size: 48, color: AppColors.textHint),
                  const SizedBox(height: AppSpacing.md),
                  Text('No barcode templates', style: AppTypography.subhead.copyWith(color: AppColors.textMuted)),
                  const SizedBox(height: AppSpacing.xs),
                  Text('Create a template for label printing.', textAlign: TextAlign.center, style: AppTypography.footnote.copyWith(color: AppColors.textHint)),
                  const SizedBox(height: AppSpacing.xl),
                  PermissionGate(
                    module: 'inventory',
                    action: 'create',
                    child: AppButton(label: 'Create Template', onPressed: () => context.push('/inventory/barcode-templates/create')),
                  ),
                ],
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding, vertical: AppSpacing.md),
          itemCount: templates.length,
          itemBuilder: (_, i) => Padding(
            padding: EdgeInsets.only(bottom: i < templates.length - 1 ? AppSpacing.md : 0),
            child: _TemplateCard(template: templates[i]),
          ),
        );
      },
    );
  }
}

class _TemplateCard extends ConsumerWidget {
  const _TemplateCard({required this.template});
  final BarcodeTemplate template;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      child: InkWell(
        onTap: () => context.push('/inventory/barcode-templates/${template.id}'),
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: const Center(child: Icon(Icons.qr_code_2, color: AppColors.accent, size: 20)),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(template.name, style: AppTypography.headline),
              Text('${template.format} · ${template.widthMm}×${template.heightMm}mm', style: AppTypography.footnote.copyWith(color: AppColors.textMuted)),
            ])),
            if (template.isDefault)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
                decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadius.chip)),
                child: Text('Default', style: AppTypography.caption.copyWith(color: AppColors.success, fontWeight: FontWeight.w600)),
              ),
          ]),
        ),
      ),
    );
  }
}
