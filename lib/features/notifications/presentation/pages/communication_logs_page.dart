import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../domain/entities/communication_log.dart';
import '../controllers/admin_controllers.dart';

class CommunicationLogsPage extends ConsumerStatefulWidget {
  const CommunicationLogsPage({super.key});

  @override
  ConsumerState<CommunicationLogsPage> createState() =>
      _CommunicationLogsPageState();
}

class _CommunicationLogsPageState extends ConsumerState<CommunicationLogsPage> {
  String? _channel; // null = all
  String? _status; // null = all

  static const _channels = ['SMS', 'EMAIL', 'WHATSAPP', 'PUSH'];
  static const _statuses = ['PENDING', 'SENT', 'FAILED'];

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(communicationLogProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.accent, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Communication Logs', style: AppTypography.headline),
      ),
      body: Column(
        children: [
          _FilterBar(
            channel: _channel,
            status: _status,
            channels: _channels,
            statuses: _statuses,
            onChannel: (c) => setState(() => _channel = c),
            onStatus: (s) => setState(() => _status = s),
          ),
          Expanded(
            child: state.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenPadding),
                  child: AppInlineBanner(
                    message: 'Could not load logs.',
                    type: BannerType.error,
                  ),
                ),
              ),
              data: (all) {
                final items = all.where((e) {
                  if (_channel != null && e.channel != _channel) return false;
                  if (_status != null && e.status != _status) return false;
                  return true;
                }).toList();
                return RefreshIndicator(
                  onRefresh: () =>
                      ref.read(communicationLogProvider.notifier).refresh(),
                  child: items.isEmpty
                      ? ListView(children: const [
                          SizedBox(height: 140),
                          Center(child: Text('No messages')),
                        ])
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.screenPadding,
                            vertical: AppSpacing.md,
                          ),
                          itemCount: items.length,
                          itemBuilder: (_, i) => Padding(
                            padding: EdgeInsets.only(
                              bottom: i < items.length - 1 ? AppSpacing.md : 0,
                            ),
                            child: _LogCard(entry: items[i]),
                          ),
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.channel,
    required this.status,
    required this.channels,
    required this.statuses,
    required this.onChannel,
    required this.onStatus,
  });

  final String? channel;
  final String? status;
  final List<String> channels;
  final List<String> statuses;
  final ValueChanged<String?> onChannel;
  final ValueChanged<String?> onStatus;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenPadding,
        vertical: AppSpacing.sm,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.separator, width: 0.5)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _Chip(label: 'All', selected: channel == null, onTap: () => onChannel(null)),
            for (final c in channels) ...[
              const SizedBox(width: AppSpacing.sm),
              _Chip(label: c, selected: channel == c, onTap: () => onChannel(c)),
            ],
            const SizedBox(width: AppSpacing.sm),
            Container(width: 0.5, height: 20, color: AppColors.separator),
            const SizedBox(width: AppSpacing.sm),
            for (final s in statuses) ...[
              _Chip(
                label: _statusLabel(s),
                selected: status == s,
                onTap: () => onStatus(status == s ? null : s),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
          ],
        ),
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

Color _statusColor(String s) => switch (s) {
      'SENT' => AppColors.success,
      'FAILED' => AppColors.destructive,
      'PENDING' => AppColors.warning,
      _ => AppColors.textMuted,
    };

class _LogCard extends StatelessWidget {
  const _LogCard({required this.entry});
  final CommunicationLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(entry.status);
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    entry.recipient ?? entry.channel,
                    style: AppTypography.callout.copyWith(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                  ),
                  child: Text(
                    _statusLabel(entry.status),
                    style: AppTypography.caption
                        .copyWith(color: color, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${entry.channel} · ${_sourceLabel(entry.source)}'
              '${entry.templateCode != null ? ' · ${entry.templateCode}' : ''}',
              style: AppTypography.footnote.copyWith(color: AppColors.textMuted),
            ),
            if (entry.error != null) ...[
              const SizedBox(height: 4),
              Text(
                entry.error!,
                style: AppTypography.caption.copyWith(color: AppColors.destructive),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 6),
            Text(
              entry.sentAt != null
                  ? 'Sent ${_fmt(entry.sentAt!)}'
                  : 'Created ${_fmt(entry.createdAt)}',
              style: AppTypography.caption.copyWith(color: AppColors.textHint),
            ),
          ],
        ),
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

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});

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
