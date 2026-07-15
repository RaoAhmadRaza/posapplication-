import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../auth/presentation/controllers/permission_controller.dart';
import '../../domain/entities/branch_config.dart';
import '../../domain/failures/settings_failure.dart';
import '../controllers/branches_controller.dart';

class BranchesPage extends ConsumerWidget {
  const BranchesPage({super.key});

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref,
    BranchConfig branch,
  ) async {
    final name = TextEditingController(text: branch.name);
    final city = TextEditingController(text: branch.city ?? '');
    final country = TextEditingController(text: branch.country ?? '');
    final currency = TextEditingController(text: branch.currency);
    final timezone = TextEditingController(text: branch.timezone);
    var isActive = branch.isActive;
    var saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.screenPadding,
          right: AppSpacing.screenPadding,
          top: AppSpacing.lg,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom +
              AppSpacing.lg,
        ),
        child: StatefulBuilder(
          builder: (builderContext, setSheetState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(branch.name, style: AppTypography.title2),
              const SizedBox(height: 2),
              Text(branch.code, style: AppTypography.subtitleMuted),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                controller: name,
                label: 'Name',
                prefixIcon: Icons.store_outlined,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: city,
                label: 'City',
                prefixIcon: Icons.location_city_outlined,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: country,
                label: 'Country',
                prefixIcon: Icons.public_outlined,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: currency,
                label: 'Currency',
                prefixIcon: Icons.payments_outlined,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: timezone,
                label: 'Timezone',
                prefixIcon: Icons.schedule_outlined,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: AppColors.accent,
                title: Text('Active', style: AppTypography.body),
                value: isActive,
                onChanged: saving
                    ? null
                    : (v) => setSheetState(() => isActive = v),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'Save',
                loading: saving,
                fullWidth: true,
                onPressed: saving
                    ? null
                    : () async {
                        setSheetState(() => saving = true);
                        final failure = await ref
                            .read(branchesProvider.notifier)
                            .saveBranch(
                              branchId: branch.id,
                              name: name.text.trim(),
                              city: city.text.trim(),
                              country: country.text.trim(),
                              currency: currency.text.trim(),
                              timezone: timezone.text.trim(),
                              isActive: isActive,
                            );
                        if (!builderContext.mounted) return;
                        setSheetState(() => saving = false);
                        if (failure == null) {
                          Navigator.of(builderContext).pop();
                        }
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content:
                              Text(failure == null ? 'Saved' : failure.message),
                        ));
                      },
              ),
            ],
          ),
        ),
      ),
    );

    name.dispose();
    city.dispose();
    country.dispose();
    currency.dispose();
    timezone.dispose();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(branchesProvider);
    final canEdit =
        ref.watch(permissionMatrixProvider).value?.contains('settings:update') ??
            false;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        title: Text('Branches', style: AppTypography.headline),
      ),
      body: SafeArea(
        child: state.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            child: AppInlineBanner(
              message: e is SettingsFailure ? e.message : e.toString(),
            ),
          ),
          data: (branches) => ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            itemCount: branches.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (_, i) => _BranchCard(
              branch: branches[i],
              canEdit: canEdit,
              onTap: canEdit
                  ? () => _openEditor(context, ref, branches[i])
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _BranchCard extends StatelessWidget {
  const _BranchCard({
    required this.branch,
    required this.canEdit,
    required this.onTap,
  });

  final BranchConfig branch;
  final bool canEdit;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final location = [branch.city, branch.country]
        .where((s) => s != null && s.isNotEmpty)
        .join(', ');

    final card = AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(branch.name, style: AppTypography.body),
                    const SizedBox(height: 2),
                    Text(branch.code, style: AppTypography.subtitleMuted),
                  ],
                ),
              ),
              Text(
                branch.isActive ? 'Active' : 'Inactive',
                style: AppTypography.subtitleMuted,
              ),
              if (canEdit) ...[
                const SizedBox(width: AppSpacing.sm),
                const Icon(Icons.chevron_right,
                    size: 20, color: AppColors.textMuted),
              ],
            ],
          ),
          if (location.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            _InfoRow(icon: Icons.location_on_outlined, text: location),
          ],
          const SizedBox(height: AppSpacing.sm),
          _InfoRow(
            icon: Icons.payments_outlined,
            text: '${branch.currency} · ${branch.timezone}',
          ),
        ],
      ),
    );

    if (onTap == null) return card;
    return InkWell(onTap: onTap, child: card);
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textMuted),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: AppTypography.subtitleMuted)),
      ],
    );
  }
}
