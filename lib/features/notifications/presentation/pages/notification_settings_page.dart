import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_detail_scaffold.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_toggle.dart';
import '../../../auth/presentation/controllers/permission_controller.dart';
import '../../domain/entities/notification.dart';
import '../controllers/notifications_controller.dart';

/// Static UI copy describing each event type. Icon + description are descriptive
/// labels for the event's meaning — not backend fields.
class _EventMeta {
  const _EventMeta(this.label, this.description, this.icon);
  final String label;
  final String description;
  final IconData icon;
}

const _eventTypes = <String, _EventMeta>{
  'repair_status': _EventMeta(
      'Repair status updates', 'Sent when a repair changes state',
      LucideIcons.wrench),
  'low_stock': _EventMeta('Low stock alerts',
      'When an item drops below its reorder point', LucideIcons.package),
  'overdue_receivable': _EventMeta(
      'Overdue receivables', 'Reminders for invoices past due',
      LucideIcons.clock),
  'approval_required': _EventMeta(
      'Approvals needed', 'When something is waiting on you',
      LucideIcons.badgeCheck),
  'payment_received': _EventMeta(
      'Payments received', 'Confirmations when a payment lands',
      LucideIcons.wallet),
  'scheduled_report': _EventMeta(
      'Scheduled reports', 'Delivery of recurring reports',
      LucideIcons.fileText),
};

class _AdminLinkSpec {
  const _AdminLinkSpec(this.icon, this.title, this.subtitle, this.route);
  final IconData icon;
  final String title;
  final String subtitle;
  final String route;
}

class NotificationSettingsPage extends ConsumerWidget {
  const NotificationSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationPreferencesProvider);
    final matrix = ref.watch(permissionMatrixProvider).value;
    bool can(String action) => matrix?.contains('notifications:$action') ?? false;

    // Same permission keys as before (notifications:read/update/create) — the
    // section header only appears when at least one link is permitted.
    final links = <_AdminLinkSpec>[
      if (can('read'))
        const _AdminLinkSpec(LucideIcons.scrollText, 'Communication logs',
            "Every message we've tried to send", '/notifications/logs'),
      if (can('update'))
        const _AdminLinkSpec(LucideIcons.fileText, 'Message templates',
            'SMS & email copy with placeholders', '/notifications/templates'),
      if (can('create'))
        const _AdminLinkSpec(LucideIcons.send, 'Bulk message',
            'Send to a customer segment', '/notifications/bulk'),
    ];

    return AppDetailScaffold(
      eyebrow: 'Notifications',
      title: 'Notification settings',
      description: 'Choose what reaches you and how.',
      child: state.when(
        loading: () => const Padding(
          padding: EdgeInsets.only(top: 64),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => const AppInlineBanner(
          message: 'Could not load preferences.',
          type: BannerType.error,
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

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (links.isNotEmpty) ...[
                const _SectionLabel('Manage'),
                const SizedBox(height: AppSpacing.sm),
                for (var i = 0; i < links.length; i++) ...[
                  if (i > 0) const SizedBox(height: AppSpacing.sm),
                  _AdminLink(spec: links[i]),
                ],
                const SizedBox(height: AppSpacing.xl),
              ],
              const _SectionLabel('Notify me about'),
              const SizedBox(height: AppSpacing.sm),
              for (final entry in _eventTypes.entries) ...[
                _PrefCard(
                  meta: entry.value,
                  pref: forType(entry.key),
                  onChanged: (p) => ref
                      .read(notificationPreferencesProvider.notifier)
                      .upsert(p),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Text(
      text.toUpperCase(),
      style: AppTypography.caption.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.7,
        color: lum.g500,
      ),
    );
  }
}

class _AdminLink extends StatelessWidget {
  const _AdminLink({required this.spec});

  final _AdminLinkSpec spec;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.base),
      onTap: () => context.push(spec.route),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: lum.g100,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(spec.icon, size: 19, color: lum.g600),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  spec.title,
                  style: AppTypography.callout.copyWith(
                    fontWeight: FontWeight.w600,
                    color: lum.textPrimary,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  spec.subtitle,
                  style: AppTypography.caption.copyWith(color: lum.g500),
                ),
              ],
            ),
          ),
          Icon(LucideIcons.chevronRight, size: 18, color: lum.g400),
        ],
      ),
    );
  }
}

class _PrefCard extends StatelessWidget {
  const _PrefCard({
    required this.meta,
    required this.pref,
    required this.onChanged,
  });

  final _EventMeta meta;
  final NotificationPreference pref;
  final ValueChanged<NotificationPreference> onChanged;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: lum.g100,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(meta.icon, size: 20, color: lum.g600),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      meta.label,
                      style: AppTypography.callout.copyWith(
                        fontWeight: FontWeight.w600,
                        color: lum.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      meta.description,
                      style: AppTypography.caption.copyWith(color: lum.g500),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              AppToggle(
                value: pref.enabled,
                semanticLabel: meta.label,
                onChanged: (v) => onChanged(pref.copyWith(enabled: v)),
              ),
            ],
          ),
          if (pref.enabled) ...[
            const SizedBox(height: 15),
            Divider(height: 1, color: lum.hairline),
            const SizedBox(height: 15),
            Wrap(
              spacing: 9,
              runSpacing: 9,
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
    final lum = context.lum;
    final disabled = onTap == null;
    final chip = Opacity(
      opacity: disabled ? 0.5 : 1,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? lum.accentSoft : lum.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: selected ? Colors.transparent : lum.hairline,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.footnote.copyWith(
            fontWeight: FontWeight.w600,
            color: selected ? lum.accentPress : lum.g600,
          ),
        ),
      ),
    );
    if (disabled) {
      return Tooltip(message: disabledReason ?? '', child: chip);
    }
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(onTap: onTap, child: chip),
    );
  }
}
