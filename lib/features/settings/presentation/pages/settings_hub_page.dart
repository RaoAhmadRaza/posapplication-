import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../widgets/settings_nav_tile.dart';

/// The Settings tab: a hub linking to every configuration surface.
/// Self-service groups (Profile & Security, App) are visible to every
/// authenticated user — a CASHIER must be able to reach own-account security
/// (PIN, biometric, MFA enrolment) without an admin-tier permission. The
/// tenant-admin groups (Team, Business, Money) are gated settings:read; write
/// actions on the sub-pages are further gated settings:update.
class SettingsHubPage extends StatelessWidget {
  const SettingsHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.xl),
              Text('Settings', style: AppTypography.largeTitle),
              const SizedBox(height: AppSpacing.xxl),
              // Self-service — always visible.
              _Group(children: [
                SettingsNavTile(
                  icon: Icons.person_outline,
                  title: 'Profile & Security',
                  subtitle: 'Your profile, PIN, biometric, and authenticator.',
                  showDivider: false,
                  onTap: () => context.push('/settings/profile'),
                ),
              ]),
              // Tenant-admin groups — gated settings:read (hidden for CASHIER).
              _AdminGroup(
                label: 'Team',
                tiles: [
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
                ],
              ),
              _AdminGroup(
                label: 'Business',
                tiles: [
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
                ],
              ),
              _AdminGroup(
                label: 'Money',
                tiles: [
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
                ],
              ),
              // Self-service — always visible.
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
    );
  }
}

/// A labelled settings group visible only to users with settings:read. The whole
/// block (top spacer, label, and tiles) collapses together when hidden, so no
/// stray spacing is left for a CASHIER.
class _AdminGroup extends StatelessWidget {
  const _AdminGroup({required this.label, required this.tiles});
  final String label;
  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    return PermissionGate(
      module: 'settings',
      action: 'read',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.lg),
          _Label(label),
          const SizedBox(height: AppSpacing.sm),
          _Group(children: tiles),
        ],
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
