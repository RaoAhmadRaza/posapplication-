import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_confirm_dialog.dart';
import '../../../../core/design/widgets/app_detail_scaffold.dart';
import '../../../../core/design/widgets/app_dropdown.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../../core/design/widgets/app_toast.dart';
import '../../domain/entities/message_template.dart';
import '../controllers/admin_controllers.dart';

const _segments = {
  'all': 'All customers',
  'with_balance': 'With outstanding balance',
  'by_tag': 'By tag',
};
const _channels = ['SMS', 'EMAIL', 'WHATSAPP'];

/// Sentinel for the "no template picked yet" dropdown option.
const _noTemplate = '';

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
      _toast('Preview failed: $e', BannerType.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    final code = _templateCode;
    if (code == null) {
      _toast('Pick a template first', BannerType.warning);
      return;
    }
    final count = _previewCount;
    final confirmed = await showAppConfirm(
      context,
      title: 'Send bulk message',
      message: count != null
          ? 'This will enqueue $count message(s). They queue as PENDING and '
              'send in the background.'
          : 'This will enqueue the message. Recipients queue as PENDING and '
              'send in the background.',
      confirmLabel: 'Send',
    );
    if (!confirmed) return;

    setState(() => _busy = true);
    try {
      final n = await ref.read(bulkCommunicationControllerProvider).enqueue(
            _segment,
            _segment == 'by_tag' ? _tag.text.trim() : null,
            code,
            _channel,
          );
      _toast('Enqueued $n message(s) — sending in the background.',
          BannerType.success);
      if (mounted) setState(() => _previewCount = null);
    } on Object catch (e) {
      _toast('Enqueue failed: $e', BannerType.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String m, BannerType type) {
    if (mounted) showAppToast(context, m, type: type);
  }

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final templatesState = ref.watch(messageTemplatesProvider);
    // SMS + WhatsApp use SMS templates; EMAIL uses email templates.
    final wantChannel = _isEmail ? TemplateChannel.email : TemplateChannel.sms;
    final templates = (templatesState.value ?? [])
        .where((t) => t.channel == wantChannel && t.isActive)
        .toList();

    return AppDetailScaffold(
      eyebrow: 'Notifications',
      title: 'Bulk message',
      description: 'Send an SMS, email or WhatsApp to a customer segment.',
      maxContentWidth: 640,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _FieldLabel('Audience segment'),
                AppDropdown<String>(
                  value: _segment,
                  options: [
                    for (final e in _segments.entries)
                      AppDropdownOption(value: e.key, label: e.value),
                  ],
                  onSelected: (v) => setState(() {
                    _segment = v;
                    _previewCount = null;
                  }),
                ),
                if (_segment == 'by_tag') ...[
                  const SizedBox(height: AppSpacing.md),
                  _FieldLabel('Tag'),
                  AppTextField(
                    controller: _tag,
                    label: 'Tag',
                    prefixIcon: LucideIcons.tag,
                    hint: 'e.g. vip',
                    onChanged: (_) => setState(() => _previewCount = null),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                _FieldLabel('Channel'),
                AppDropdown<String>(
                  value: _channel,
                  options: [
                    for (final c in _channels)
                      AppDropdownOption(value: c, label: c),
                  ],
                  onSelected: (v) => setState(() {
                    _channel = v;
                    _templateCode = null;
                    _previewCount = null;
                  }),
                ),
                const SizedBox(height: AppSpacing.md),
                _FieldLabel('Template'),
                AppDropdown<String>(
                  value: _templateCode ?? _noTemplate,
                  options: [
                    const AppDropdownOption(
                        value: _noTemplate, label: 'Select a template…'),
                    for (final t in templates)
                      AppDropdownOption(value: t.templateCode, label: t.name),
                  ],
                  onSelected: (v) => setState(
                      () => _templateCode = v == _noTemplate ? null : v),
                ),
                const SizedBox(height: 7),
                Text(
                  'SMS and WhatsApp share the SMS template family.',
                  style: AppTypography.caption.copyWith(color: lum.g500),
                ),
              ],
            ),
          ),
          if (_previewCount != null) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
              decoration: BoxDecoration(
                color: lum.accentSoft,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.usersRound, size: 20, color: lum.accentPress),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'This will reach $_previewCount recipient(s).',
                      style: AppTypography.callout.copyWith(
                        fontWeight: FontWeight.w600,
                        color: lum.accentPress,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Preview',
                  variant: AppButtonVariant.tinted,
                  icon: LucideIcons.eye,
                  onPressed: _busy ? null : _preview,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppButton(
                  label: 'Send',
                  icon: LucideIcons.send,
                  loading: _busy,
                  onPressed: _busy ? null : _send,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: AppTypography.fieldLabel.copyWith(color: lum.g700),
      ),
    );
  }
}
