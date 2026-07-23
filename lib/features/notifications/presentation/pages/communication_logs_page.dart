import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_detail_scaffold.dart';
import '../../../../core/design/widgets/app_filter_chips.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../../../core/design/widgets/app_states.dart';
import '../../domain/entities/communication_log.dart';
import '../controllers/admin_controllers.dart';

class CommunicationLogsPage extends ConsumerStatefulWidget {
  const CommunicationLogsPage({super.key});

  @override
  ConsumerState<CommunicationLogsPage> createState() =>
      _CommunicationLogsPageState();
}

class _CommunicationLogsPageState extends ConsumerState<CommunicationLogsPage> {
  int _channelIndex = 0; // 0 = all
  String? _status; // null = all

  // Index 0 is "All"; the rest map 1:1 onto these channel codes.
  static const _channelCodes = ['SMS', 'EMAIL', 'WHATSAPP', 'PUSH'];
  static const _channelLabels = ['All', 'SMS', 'Email', 'WhatsApp', 'Push'];
  static const _statuses = ['PENDING', 'SENT', 'FAILED'];

  String? get _channel =>
      _channelIndex == 0 ? null : _channelCodes[_channelIndex - 1];

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(communicationLogProvider);

    return AppDetailScaffold(
      eyebrow: 'Notifications',
      title: 'Communication logs',
      description: "Every message we've tried to send.",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppFilterChips(
            labels: _channelLabels,
            selected: _channelIndex,
            onSelected: (i) => setState(() => _channelIndex = i),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: [
              for (final s in _statuses)
                AppFilterChip(
                  label: _statusLabel(s),
                  active: _status == s,
                  onTap: () =>
                      setState(() => _status = _status == s ? null : s),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          state.when(
            loading: () => const Padding(
              padding: EdgeInsets.only(top: 64),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => AppErrorState(
              title: 'Could not load logs',
              body: 'Something went wrong while loading the message history. '
                  'Try again.',
              onRetry: () =>
                  ref.read(communicationLogProvider.notifier).refresh(),
            ),
            data: (all) {
              final items = all.where((e) {
                if (_channel != null && e.channel != _channel) return false;
                if (_status != null && e.status != _status) return false;
                return true;
              }).toList();
              if (items.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.only(top: 48),
                  child: AppEmptyState(
                    icon: LucideIcons.inbox,
                    title: 'No messages',
                    body: 'Messages you send will show up here with their '
                        'delivery status.',
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    if (i > 0) const SizedBox(height: AppSpacing.md),
                    _LogCard(entry: items[i]),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

String _statusLabel(String s) => switch (s) {
      'PENDING' => 'Queued',
      'SENT' => 'Sent',
      'FAILED' => 'Failed',
      _ => s,
    };

AppPillTone _statusTone(String s) => switch (s) {
      'SENT' => AppPillTone.success,
      'FAILED' => AppPillTone.danger,
      'PENDING' => AppPillTone.warning,
      _ => AppPillTone.neutral,
    };

class _LogCard extends StatelessWidget {
  const _LogCard({required this.entry});
  final CommunicationLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  entry.recipient ?? entry.channel,
                  style: AppTypography.monoValue.copyWith(
                    fontSize: 13.5,
                    color: lum.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),
              AppPill(
                label: _statusLabel(entry.status),
                tone: _statusTone(entry.status),
                showDot: false,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              AppPill(
                label: entry.channel,
                tone: AppPillTone.neutral,
                showDot: false,
              ),
              Text(_sourceLabel(entry.source),
                  style: AppTypography.caption.copyWith(color: lum.g500)),
              if (entry.templateCode != null) ...[
                Text('·', style: AppTypography.caption.copyWith(color: lum.g400)),
                Text(entry.templateCode!,
                    style: AppTypography.monoValue
                        .copyWith(fontSize: 12, color: lum.g500)),
              ],
              Text('·', style: AppTypography.caption.copyWith(color: lum.g400)),
              Text(
                entry.sentAt != null ? _fmt(entry.sentAt!) : _fmt(entry.createdAt),
                style: AppTypography.caption.copyWith(color: lum.g500),
              ),
            ],
          ),
          if (entry.error != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: lum.dangerSoft,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(LucideIcons.circleAlert, size: 15, color: lum.dangerText),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      entry.error!,
                      style: AppTypography.caption.copyWith(
                        color: lum.dangerText,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _sourceLabel(CommSource s) => switch (s) {
        CommSource.communication => 'Customer',
        CommSource.reportDelivery => 'Report',
        CommSource.notification => 'Notification',
      };

  String _fmt(DateTime dt) =>
      '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}
