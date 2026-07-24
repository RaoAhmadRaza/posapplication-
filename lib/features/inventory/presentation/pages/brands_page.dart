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
import '../../../../core/design/widgets/app_confirm_dialog.dart';
import '../../../../core/design/widgets/app_detail_scaffold.dart';
import '../../../../core/design/widgets/app_list_skeleton.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../../../core/design/widgets/app_states.dart';
import '../../../../core/design/widgets/app_toast.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../domain/entities/brand.dart';
import '../controllers/brands_controller.dart';

class BrandsPage extends ConsumerWidget {
  const BrandsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(brandsProvider);

    return AppDetailScaffold(
      eyebrow: 'Inventory',
      title: 'Brands',
      actions: [
        PermissionGate(
          module: 'inventory',
          action: 'create',
          child: AppButton(
            label: 'Add brand',
            icon: LucideIcons.plus,
            size: AppButtonSize.sm,
            onPressed: () => context.push('/inventory/brands/create'),
          ),
        ),
      ],
      child: state.when(
        loading: () => const AppListSkeleton(),
        error: (e, _) => AppErrorState(
          title: "We couldn't load brands",
          body: 'Please try again in a moment.',
          onRetry: () => ref.read(brandsProvider.notifier).refresh(),
        ),
        data: (brands) {
          if (brands.isEmpty) {
            return AppEmptyState(
              icon: LucideIcons.tag,
              title: 'No brands yet',
              body: 'Create a brand to associate with your products.',
              action: PermissionGate(
                module: 'inventory',
                action: 'create',
                child: AppButton(
                  label: 'Create brand',
                  icon: LucideIcons.plus,
                  onPressed: () => context.push('/inventory/brands/create'),
                ),
              ),
            );
          }
          return Column(
            children: [
              for (final b in brands) ...[
                _BrandCard(brand: b),
                if (b != brands.last) const SizedBox(height: 10),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _BrandCard extends ConsumerWidget {
  const _BrandCard({required this.brand});
  final Brand brand;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lum = context.lum;
    return AppCard(
      onTap: () => context.push('/inventory/brands/${brand.id}'),
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
            child: Center(child: Icon(LucideIcons.tag, size: 19, color: lum.accent)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(brand.name, style: AppTypography.headline.copyWith(color: lum.textPrimary)),
                if (brand.description != null && brand.description!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    brand.description!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.footnote.copyWith(color: lum.g500),
                  ),
                ],
              ],
            ),
          ),
          if (!brand.isActive) ...[
            const SizedBox(width: 10),
            const AppPill(label: 'Inactive', tone: AppPillTone.neutral),
          ],
          PermissionGate(
            module: 'inventory',
            action: 'delete',
            child: IconButton(
              icon: Icon(LucideIcons.trash2, size: 18, color: lum.g500),
              tooltip: 'Delete brand',
              onPressed: () => _confirmDelete(context, ref),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showAppConfirm(
      context,
      title: 'Delete brand',
      message: 'Delete "${brand.name}"? This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    await ref.read(brandsProvider.notifier).remove(brand.id);
    if (context.mounted) showAppToast(context, 'Brand deleted');
  }
}
