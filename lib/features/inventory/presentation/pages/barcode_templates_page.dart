import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/clay.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_detail_scaffold.dart';
import '../../../../core/design/widgets/app_list_skeleton.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../../../core/design/widgets/app_states.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../domain/entities/barcode_template.dart';
import '../controllers/barcode_templates_controller.dart';

class BarcodeTemplatesPage extends ConsumerWidget {
  const BarcodeTemplatesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(barcodeTemplatesProvider);

    return AppDetailScaffold(
      eyebrow: 'Inventory',
      title: 'Barcode templates',
      actions: [
        PermissionGate(
          module: 'inventory',
          action: 'create',
          child: AppButton(
            label: 'Add template',
            icon: LucideIcons.plus,
            size: AppButtonSize.sm,
            onPressed: () => context.push('/inventory/barcode-templates/create'),
          ),
        ),
      ],
      child: state.when(
        loading: () => const AppListSkeleton(),
        error: (e, _) => AppErrorState(
          title: "We couldn't load templates",
          body: 'Please try again in a moment.',
          onRetry: () => ref.read(barcodeTemplatesProvider.notifier).refresh(),
        ),
        data: (templates) {
          if (templates.isEmpty) {
            return AppEmptyState(
              icon: LucideIcons.scanLine,
              title: 'No barcode templates',
              body: 'Create a template for label printing.',
              action: PermissionGate(
                module: 'inventory',
                action: 'create',
                child: AppButton(
                  label: 'Create template',
                  icon: LucideIcons.plus,
                  onPressed: () =>
                      context.push('/inventory/barcode-templates/create'),
                ),
              ),
            );
          }
          return Column(
            children: [
              for (final t in templates) ...[
                _TemplateCard(template: t),
                if (t != templates.last) const SizedBox(height: 10),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({required this.template});
  final BarcodeTemplate template;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return AppCard(
      onTap: () => context.push('/inventory/barcode-templates/${template.id}'),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          ClayContainer(
            variant: ClayVariant.soft,
            color: lum.accentSoft,
            borderRadius: AppRadius.sm,
            isDark: lum.isDark,
            width: 42,
            height: 42,
            child: Center(
              child: Icon(LucideIcons.scanLine, size: 19, color: lum.accent),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  template.name,
                  style: AppTypography.headline.copyWith(color: lum.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  '${template.format} · ${template.widthMm}×${template.heightMm} mm',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.footnote.copyWith(color: lum.g500),
                ),
              ],
            ),
          ),
          if (template.isDefault) ...[
            const SizedBox(width: 10),
            const AppPill(label: 'Default', tone: AppPillTone.lumen),
          ],
        ],
      ),
    );
  }
}
