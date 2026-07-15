import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../auth/presentation/controllers/permission_controller.dart';
import '../../domain/entities/branch_config.dart';
import '../../domain/failures/settings_failure.dart';
import '../controllers/branches_controller.dart';
import '../controllers/preferences_controller.dart';

class PreferencesPage extends ConsumerWidget {
  const PreferencesPage({super.key});

  Future<void> _save(
    BuildContext context,
    WidgetRef ref, {
    String? theme,
    String? language,
    String? defaultBranchId,
  }) async {
    final failure = await ref.read(preferencesProvider.notifier).save(
          theme: theme,
          language: language,
          defaultBranchId: defaultBranchId,
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(failure == null ? 'Saved' : failure.message),
    ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(preferencesProvider);
    final branchesState = ref.watch(branchesProvider);
    final branches = branchesState.value ?? const <BranchConfig>[];
    final canEdit =
        ref.watch(permissionMatrixProvider).value?.contains('settings:update') ??
            false;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        title: Text('Preferences', style: AppTypography.headline),
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
          data: (prefs) => SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: prefs.theme,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Theme',
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.field),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'light', child: Text('Light')),
                        ],
                        onChanged: canEdit
                            ? (value) {
                                if (value == null) return;
                                _save(context, ref, theme: value);
                              }
                            : null,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text('Light mode only',
                          style: AppTypography.subtitleMuted),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  child: DropdownButtonFormField<String>(
                    initialValue: prefs.language,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Language',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.field),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'en', child: Text('English')),
                      DropdownMenuItem(value: 'ur', child: Text('Urdu')),
                    ],
                    onChanged: canEdit
                        ? (value) {
                            if (value == null) return;
                            _save(context, ref, language: value);
                          }
                        : null,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  child: DropdownButtonFormField<String?>(
                    initialValue: prefs.defaultBranchId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Default branch',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.field),
                      ),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('None')),
                      ...branches.map((b) => DropdownMenuItem(
                            value: b.id,
                            child: Text(b.name),
                          )),
                    ],
                    onChanged: canEdit
                        ? (value) =>
                            _save(context, ref, defaultBranchId: value)
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
