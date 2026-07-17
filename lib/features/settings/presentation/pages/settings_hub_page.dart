import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../widgets/settings_nav_tile.dart';

/// The Settings tab: a hub linking to every configuration surface.
/// The whole hub is gated settings:read; individual write actions on the
/// sub-pages are gated settings:update.
class SettingsHubPage extends StatelessWidget {
  const SettingsHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: PermissionGate(
          module: 'settings',
          action: 'read',
          fallback: const _NoAccess(),
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.xl),
                Text('Settings', style: AppTypography.largeTitle),
                const SizedBox(height: AppSpacing.xxl),
                _Group(children: [
                  SettingsNavTile(
                    icon: Icons.person_outline,
                    title: 'Profile & Security',
                    subtitle: 'Your profile, PIN, and biometric login.',
                    showDivider: false,
                    onTap: () => context.push('/settings/profile'),
                  ),
                ]),
                const SizedBox(height: AppSpacing.lg),
                _Label('Team'),
                const SizedBox(height: AppSpacing.sm),
                _Group(children: [
                  SettingsNavTile(
                    icon: Icons.badge_outlined,
                    title: 'Staff',
                    subtitle: 'Invite staff and manage logins.',
                    showDivider: false,
                    onTap: () => context.push('/staff'),
                  ),
                  SettingsNavTile(
                    icon: Icons.shield_outlined,
                    title: 'Roles & permissions',
                    subtitle: 'Define roles and who has them.',
                    onTap: () => context.push('/settings/roles'),
                  ),
                ]),
                const SizedBox(height: AppSpacing.lg),
                _Label('Business'),
                const SizedBox(height: AppSpacing.sm),
                _Group(children: [
                  SettingsNavTile(
                    icon: Icons.store_outlined,
                    title: 'Business settings',
                    subtitle: 'Address, phone, receipt footer, NTN, logo.',
                    showDivider: false,
                    onTap: () => context.push('/settings/business'),
                  ),
                  SettingsNavTile(
                    icon: Icons.account_tree_outlined,
                    title: 'Branches',
                    subtitle: 'Name, city, currency, timezone, active.',
                    onTap: () => context.push('/settings/branches'),
                  ),
                ]),
                const SizedBox(height: AppSpacing.lg),
                _Label('Money'),
                const SizedBox(height: AppSpacing.sm),
                _Group(children: [
                  SettingsNavTile(
                    icon: Icons.payments_outlined,
                    title: 'Payment methods',
                    subtitle: 'Methods, references, and bank/GL linking.',
                    showDivider: false,
                    onTap: () => context.push('/settings/payment-methods'),
                  ),
                  SettingsNavTile(
                    icon: Icons.percent,
                    title: 'Tax rules',
                    subtitle: 'Rates applied as defaults on products and sales.',
                    onTap: () => context.push('/accounting/tax-rules'),
                  ),
                  SettingsNavTile(
                    icon: Icons.tag_outlined,
                    title: 'Number series',
                    subtitle: 'Document prefixes and next numbers.',
                    onTap: () => context.push('/settings/number-series'),
                  ),
                ]),
                const SizedBox(height: AppSpacing.lg),
                _Label('App'),
                const SizedBox(height: AppSpacing.sm),
                _Group(children: [
                  SettingsNavTile(
                    icon: Icons.tune,
                    title: 'Preferences',
                    subtitle: 'Theme, language, default branch.',
                    showDivider: false,
                    onTap: () => context.push('/settings/preferences'),
                  ),
                  SettingsNavTile(
                    icon: Icons.notifications_outlined,
                    title: 'Notifications',
                    subtitle: 'Which events reach you, and how.',
                    onTap: () => context.push('/notifications/settings'),
                  ),
                ]),
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) =>
      AppCard(child: Column(children: children));
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: AppSpacing.sm),
        child: Text(text.toUpperCase(), style: AppTypography.subtitleMuted),
      );
}

class _NoAccess extends StatelessWidget {
  const _NoAccess();
  @override
  Widget build(BuildContext context) => Center(
        child: Text('No access to settings.',
            style: AppTypography.subtitleMuted),
      );
}
