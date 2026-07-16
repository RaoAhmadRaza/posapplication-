import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../domain/entities/notification.dart';
import '../controllers/notifications_controller.dart';

// Known event types the app produces (label shown to the user).
const _eventTypes = <String, String>{
  'repair_status': 'Repair status updates',
  'low_stock': 'Low stock alerts',
  'overdue_receivable': 'Overdue receivables',
  'approval_required': 'Approvals needed',
  'payment_received': 'Payments received',
  'scheduled_report': 'Scheduled reports',
};

class NotificationSettingsPage extends ConsumerWidget {
  const NotificationSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationPreferencesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.accent, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Notification Settings', style: AppTypography.headline),
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
            child: AppInlineBanner(
              message: 'Could not load preferences.',
              type: BannerType.error,
            ),
          ),
        ),
        data: (prefs) {
          NotificationPreference forType(String type) {
            for (final p in prefs) {
              if (p.eventType == type) return p;
            }
            return NotificationPreference(
              eventType: type,
              channels: const {NotificationChannel.inApp},
              enabled: true,
            );
          }

          return ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPadding,
              vertical: AppSpacing.md,
            ),
            children: [
              const PermissionGate(
                module: 'notifications',
                action: 'read',
                child: _AdminLink(
                  icon: Icons.history,
                  label: 'Communication logs',
                  route: '/notifications/logs',
                ),
              ),
              const PermissionGate(
                module: 'notifications',
                action: 'update',
                child: _AdminLink(
                  icon: Icons.description_outlined,
                  label: 'Message templates',
                  route: '/notifications/templates',
                ),
              ),
              const PermissionGate(
                module: 'notifications',
                action: 'create',
                child: _AdminLink(
                  icon: Icons.campaign_outlined,
                  label: 'Bulk message',
                  route: '/notifications/bulk',
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Per-event channels',
                  style: AppTypography.footnote
                      .copyWith(color: AppColors.textMuted)),
              const SizedBox(height: AppSpacing.sm),
              for (final entry in _eventTypes.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: _PrefCard(
                    label: entry.value,
                    pref: forType(entry.key),
                    onChanged: (p) => ref
                        .read(notificationPreferencesProvider.notifier)
                        .upsert(p),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _AdminLink extends StatelessWidget {
  const _AdminLink({required this.icon, required this.label, required this.route});

  final IconData icon;
  final String label;
  final String route;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: () => context.push(route),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Icon(icon, color: AppColors.accent, size: 22),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: Text(label, style: AppTypography.callout)),
                Icon(Icons.chevron_right, size: 18, color: AppColors.separator),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PrefCard extends StatelessWidget {
  const _PrefCard({
    required this.label,
    required this.pref,
    required this.onChanged,
  });

  final String label;
  final NotificationPreference pref;
  final ValueChanged<NotificationPreference> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(label, style: AppTypography.callout),
                ),
                Switch(
                  value: pref.enabled,
                  activeThumbColor: AppColors.accent,
                  onChanged: (v) => onChanged(pref.copyWith(enabled: v)),
                ),
              ],
            ),
            if (pref.enabled) ...[
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final c in NotificationChannel.values)
                    _ChannelChip(
                      label: c.label,
                      selected: pref.channels.contains(c),
                      // PUSH has no working delivery path: no device can register a
                      // token (the Flutter half is deferred). Disabled, not hidden —
                      // a missing control reads as a bug, a disabled one with a
                      // reason reads as a roadmap.
                      onTap: c == NotificationChannel.push
                          ? null
                          : () {
                              final next = {...pref.channels};
                              if (next.contains(c)) {
                                next.remove(c);
                              } else {
                                next.add(c);
                              }
                              if (next.isEmpty) next.add(NotificationChannel.inApp);
                              onChanged(pref.copyWith(channels: next));
                            },
                      disabledReason: c == NotificationChannel.push
                          ? "Push notifications aren't available yet"
                          : null,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChannelChip extends StatelessWidget {
  const _ChannelChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.disabledReason,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final String? disabledReason;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
      decoration: BoxDecoration(
        color: disabled
            ? AppColors.fieldFill
            : selected
                ? AppColors.accent.withValues(alpha: 0.12)
                : AppColors.fieldFill,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(
          color: disabled
              ? AppColors.separator
              : selected
                  ? AppColors.accent
                  : AppColors.separator,
          width: 0.5,
        ),
      ),
      child: Text(
        label,
        style: AppTypography.footnote.copyWith(
          color: disabled
              ? AppColors.textHint
              : selected
                  ? AppColors.accent
                  : AppColors.textMuted,
          fontWeight: !disabled && selected ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    );
    if (disabled) {
      return Tooltip(message: disabledReason ?? '', child: chip);
    }
    return GestureDetector(onTap: onTap, child: chip);
  }
}
