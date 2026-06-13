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
import '../../domain/entities/brand.dart';
import '../controllers/brands_controller.dart';

class BrandsPage extends ConsumerWidget {
  const BrandsPage({super.key});

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
        title: Text('Brands', style: AppTypography.headline),
        actions: [
          PermissionGate(
            module: 'inventory',
            action: 'create',
            child: IconButton(
              icon: const Icon(Icons.add, color: AppColors.accent),
              onPressed: () => context.push('/inventory/brands/create'),
            ),
          ),
        ],
      ),
      body: const _BrandsBody(),
    );
  }
}

class _BrandsBody extends ConsumerStatefulWidget {
  const _BrandsBody();

  @override
  ConsumerState<_BrandsBody> createState() => _BrandsBodyState();
}

class _BrandsBodyState extends ConsumerState<_BrandsBody> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(brandsProvider);

    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppInlineBanner(
                message: 'Could not load brands.',
                type: BannerType.error,
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'Retry',
                onPressed: () => ref.read(brandsProvider.notifier).refresh(),
              ),
            ],
          ),
        ),
      ),
      data: (brands) {
        if (brands.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.branding_watermark, size: 48, color: AppColors.textHint),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'No brands yet',
                    style: AppTypography.subhead.copyWith(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Create a brand to associate with your products.',
                    textAlign: TextAlign.center,
                    style: AppTypography.footnote.copyWith(color: AppColors.textHint),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  PermissionGate(
                    module: 'inventory',
                    action: 'create',
                    child: AppButton(
                      label: 'Create Brand',
                      onPressed: () => context.push('/inventory/brands/create'),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPadding,
            vertical: AppSpacing.md,
          ),
          itemCount: brands.length,
          itemBuilder: (_, i) => Padding(
            padding: EdgeInsets.only(
              bottom: i < brands.length - 1 ? AppSpacing.md : 0,
            ),
            child: _BrandCard(brand: brands[i]),
          ),
        );
      },
    );
  }
}

class _BrandCard extends ConsumerWidget {
  const _BrandCard({required this.brand});
  final Brand brand;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      child: InkWell(
        onTap: () => context.push('/inventory/brands/${brand.id}'),
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Icon(Icons.branding_watermark, color: AppColors.accent, size: 20),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(brand.name, style: AppTypography.headline),
                        if (brand.description != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            brand.description!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.footnote.copyWith(color: AppColors.textMuted),
                          ),
                        ],
                      ],
                    ),
                  ),
                  _ActiveBadge(isActive: brand.isActive),
                ],
              ),
              const Divider(color: AppColors.separator, height: AppSpacing.xl),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  PermissionGate(
                    module: 'inventory',
                    action: 'delete',
                    child: AppButton(
                      label: 'Delete',
                      variant: AppButtonVariant.destructive,
                      onPressed: () => _confirmDelete(context, ref),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Brand'),
        content: Text('Delete "${brand.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(brandsProvider.notifier).remove(brand.id);
            },
            child: Text('Delete', style: TextStyle(color: AppColors.destructive)),
          ),
        ],
      ),
    );
  }
}

class _ActiveBadge extends StatelessWidget {
  const _ActiveBadge({required this.isActive});
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.success : AppColors.textMuted;
    final label = isActive ? 'Active' : 'Inactive';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
