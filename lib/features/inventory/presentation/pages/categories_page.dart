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
import '../../domain/entities/category.dart';
import '../controllers/categories_controller.dart';
import '../widgets/inventory_ui.dart';

class CategoriesPage extends ConsumerWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(categoriesProvider);

    return AppDetailScaffold(
      eyebrow: 'Inventory',
      title: 'Categories',
      actions: [
        PermissionGate(
          module: 'inventory',
          action: 'create',
          child: AppButton(
            label: 'Add category',
            icon: LucideIcons.plus,
            size: AppButtonSize.sm,
            onPressed: () => context.push('/inventory/categories/create'),
          ),
        ),
      ],
      child: state.when(
        loading: () => const AppListSkeleton(),
        error: (e, _) => AppErrorState(
          title: "We couldn't load categories",
          body: 'Please try again in a moment.',
          onRetry: () => ref.read(categoriesProvider.notifier).refresh(),
        ),
        data: (categories) {
          if (categories.isEmpty) {
            return AppEmptyState(
              icon: LucideIcons.folderTree,
              title: 'No categories yet',
              body: 'Create a category to organize your products.',
              action: PermissionGate(
                module: 'inventory',
                action: 'create',
                child: AppButton(
                  label: 'Create category',
                  icon: LucideIcons.plus,
                  onPressed: () => context.push('/inventory/categories/create'),
                ),
              ),
            );
          }
          return Column(
            children: [
              for (final c in categories) ...[
                _CategoryCard(category: c),
                if (c != categories.last) const SizedBox(height: 10),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _CategoryCard extends ConsumerWidget {
  const _CategoryCard({required this.category});
  final Category category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lum = context.lum;
    return AppCard(
      onTap: () => context.push('/inventory/categories/${category.id}'),
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
            child: Center(child: Icon(kInvItemIcon, size: 19, color: lum.accent)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(category.name, style: AppTypography.headline.copyWith(color: lum.textPrimary)),
                if (category.description != null && category.description!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    category.description!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.footnote.copyWith(color: lum.g500),
                  ),
                ],
              ],
            ),
          ),
          if (!category.isActive) ...[
            const SizedBox(width: 10),
            const AppPill(label: 'Inactive', tone: AppPillTone.neutral),
          ],
          PermissionGate(
            module: 'inventory',
            action: 'delete',
            child: IconButton(
              icon: Icon(LucideIcons.trash2, size: 18, color: lum.g500),
              tooltip: 'Delete category',
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
      title: 'Delete category',
      message: 'Delete "${category.name}"? This will not delete its products.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    await ref.read(categoriesProvider.notifier).remove(category.id);
    if (context.mounted) showAppToast(context, 'Category deleted');
  }
}
