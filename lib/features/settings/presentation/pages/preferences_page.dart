import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_detail_scaffold.dart';
import '../../../../core/design/widgets/app_dropdown.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../auth/presentation/controllers/permission_controller.dart';
import '../../domain/entities/branch_config.dart';
import '../../domain/failures/settings_failure.dart';
import '../controllers/branches_controller.dart';
import '../controllers/preferences_controller.dart';
import '../widgets/settings_note.dart';

/// Sentinel for "no default branch". The dropdown works in non-null values, so
/// the absence of a branch needs a value of its own rather than null, which the
/// control reserves for "nothing picked yet".
const _noBranch = '';

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
    final lum = context.lum;
    final state = ref.watch(preferencesProvider);
    final branchesState = ref.watch(branchesProvider);
    final branches = branchesState.value ?? const <BranchConfig>[];
    final canEdit =
        ref.watch(permissionMatrixProvider).value?.contains('settings:update') ??
            false;

    return AppDetailScaffold(
      eyebrow: 'Settings',
      title: 'Preferences',
      description: 'How the app looks and behaves for you.',
      child: state.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.xxl),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => AppInlineBanner(
          message: e is SettingsFailure ? e.message : e.toString(),
        ),
        data: (prefs) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!canEdit) ...[
              const SettingsNote(
                'You can view these preferences. Ask an admin to change them '
                'for this account.',
                lumen: true,
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            AppCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _PrefRow(
                    title: 'Theme',
                    description: 'More themes are on the way.',
                    control: AppDropdown<String>(
                      value: prefs.theme,
                      enabled: canEdit,
                      options: const [
                        AppDropdownOption(value: 'light', label: 'Light'),
                      ],
                      onSelected: (value) =>
                          _save(context, ref, theme: value),
                    ),
                  ),
                  Divider(height: 44, color: lum.hairline),
                  _PrefRow(
                    title: 'Language',
                    description: 'Interface language for this account.',
                    control: AppDropdown<String>(
                      value: prefs.language,
                      enabled: canEdit,
                      options: const [
                        AppDropdownOption(value: 'en', label: 'English'),
                        AppDropdownOption(value: 'ur', label: 'اردو · Urdu'),
                      ],
                      onSelected: (value) =>
                          _save(context, ref, language: value),
                    ),
                  ),
                  Divider(height: 44, color: lum.hairline),
                  _PrefRow(
                    title: 'Default branch',
                    description: 'Opens here when you sign in.',
                    control: AppDropdown<String>(
                      value: prefs.defaultBranchId ?? _noBranch,
                      enabled: canEdit,
                      options: [
                        const AppDropdownOption(
                          value: _noBranch,
                          label: 'None',
                        ),
                        for (final b in branches)
                          AppDropdownOption(value: b.id, label: b.name),
                      ],
                      onSelected: (value) => _save(
                        context,
                        ref,
                        defaultBranchId: value == _noBranch ? null : value,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Label + description on the left, a 280px control on the right; both stack
/// when the card is too narrow to hold the pair.
class _PrefRow extends StatelessWidget {
  const _PrefRow({
    required this.title,
    required this.description,
    required this.control,
  });

  final String title;
  final String description;
  final Widget control;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final label = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: AppTypography.body.copyWith(
            fontWeight: FontWeight.w600,
            color: lum.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          description,
          style: AppTypography.footnote.copyWith(color: lum.g500),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 520) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [label, const SizedBox(height: 12), control],
          );
        }
        return Row(
          children: [
            Expanded(child: label),
            const SizedBox(width: 24),
            SizedBox(width: 280, child: control),
          ],
        );
      },
    );
  }
}
