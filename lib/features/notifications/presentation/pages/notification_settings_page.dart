import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
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
                      onTap: () {
                        final next = {...pref.channels};
                        if (next.contains(c)) {
                          next.remove(c);
                        } else {
                          next.add(c);
                        }
                        if (next.isEmpty) next.add(NotificationChannel.inApp);
                        onChanged(pref.copyWith(channels: next));
                      },
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
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent.withValues(alpha: 0.12)
              : AppColors.fieldFill,
          borderRadius: BorderRadius.circular(AppRadius.chip),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.separator,
            width: 0.5,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.footnote.copyWith(
            color: selected ? AppColors.accent : AppColors.textMuted,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
