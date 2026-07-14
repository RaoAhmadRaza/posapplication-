import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../domain/entities/message_template.dart';
import '../controllers/admin_controllers.dart';

const _segments = {
  'all': 'All customers',
  'with_balance': 'With outstanding balance',
  'by_tag': 'By tag',
};
const _channels = ['SMS', 'EMAIL', 'WHATSAPP'];

class BulkCommunicationPage extends ConsumerStatefulWidget {
  const BulkCommunicationPage({super.key});

  @override
  ConsumerState<BulkCommunicationPage> createState() =>
      _BulkCommunicationPageState();
}

class _BulkCommunicationPageState extends ConsumerState<BulkCommunicationPage> {
  String _segment = 'all';
  final _tag = TextEditingController();
  String _channel = 'SMS';
  String? _templateCode;
  int? _previewCount;
  bool _busy = false;

  @override
  void dispose() {
    _tag.dispose();
    super.dispose();
  }

  bool get _isEmail => _channel == 'EMAIL';

  Future<void> _preview() async {
    setState(() => _busy = true);
    try {
      final n = await ref.read(bulkCommunicationControllerProvider).preview(
            _segment,
            _segment == 'by_tag' ? _tag.text.trim() : null,
            _channel,
          );
      if (mounted) setState(() => _previewCount = n);
    } on Object catch (e) {
      _snack('Preview failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    final code = _templateCode;
    if (code == null) {
      _snack('Pick a template first');
      return;
    }
    final count = _previewCount;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Send bulk message'),
        content: Text(count != null
            ? 'Enqueue to $count recipient(s)? They queue as PENDING and the '
                'sender delivers them.'
            : 'Enqueue this bulk message? Recipients queue as PENDING.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Send')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      final n = await ref.read(bulkCommunicationControllerProvider).enqueue(
            _segment,
            _segment == 'by_tag' ? _tag.text.trim() : null,
            code,
            _channel,
          );
      _snack('Enqueued $n message(s) — queued for the sender.');
      if (mounted) setState(() => _previewCount = null);
    } on Object catch (e) {
      _snack('Enqueue failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String m) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final templatesState = ref.watch(messageTemplatesProvider);
    // SMS + WhatsApp use SMS templates; EMAIL uses email templates.
    final wantChannel =
        _isEmail ? TemplateChannel.email : TemplateChannel.sms;
    final templates = (templatesState.value ?? [])
        .where((t) => t.channel == wantChannel && t.isActive)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.accent, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Bulk Message', style: AppTypography.headline),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenPadding,
          vertical: AppSpacing.md,
        ),
        children: [
          AppCard(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Segment'),
                  DropdownButton<String>(
                    value: _segment,
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    items: [
                      for (final e in _segments.entries)
                        DropdownMenuItem(value: e.key, child: Text(e.value)),
                    ],
                    onChanged: (v) => setState(() {
                      _segment = v!;
                      _previewCount = null;
                    }),
                  ),
                  if (_segment == 'by_tag') ...[
                    const SizedBox(height: AppSpacing.sm),
                    AppTextField(
                      controller: _tag,
                      label: 'Tag',
                      prefixIcon: Icons.sell_outlined,
                      onChanged: (_) => setState(() => _previewCount = null),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  _label('Channel'),
                  DropdownButton<String>(
                    value: _channel,
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    items: [
                      for (final c in _channels)
                        DropdownMenuItem(value: c, child: Text(c)),
                    ],
                    onChanged: (v) => setState(() {
                      _channel = v!;
                      _templateCode = null;
                      _previewCount = null;
                    }),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _label('Template'),
                  DropdownButton<String>(
                    value: _templateCode,
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    hint: const Text('Select a template'),
                    items: [
                      for (final t in templates)
                        DropdownMenuItem(
                            value: t.templateCode, child: Text(t.name)),
                    ],
                    onChanged: (v) => setState(() => _templateCode = v),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (_previewCount != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Text(
                '$_previewCount recipient(s) match.',
                style: AppTypography.callout.copyWith(color: AppColors.accent),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Preview',
                  variant: AppButtonVariant.tinted,
                  onPressed: _busy ? null : _preview,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppButton(
                  label: _busy ? 'Working…' : 'Send',
                  onPressed: _busy ? null : _send,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _label(String s) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
        child: Text(s,
            style: AppTypography.footnote.copyWith(color: AppColors.textMuted)),
      );
}
