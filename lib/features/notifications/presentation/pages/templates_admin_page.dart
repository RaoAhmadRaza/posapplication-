import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../domain/entities/message_template.dart';
import '../controllers/admin_controllers.dart';

class TemplatesAdminPage extends ConsumerWidget {
  const TemplatesAdminPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(messageTemplatesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.accent, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Message Templates', style: AppTypography.headline),
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
            child: AppInlineBanner(
              message: 'Could not load templates.',
              type: BannerType.error,
            ),
          ),
        ),
        data: (templates) {
          final sms = templates.where((t) => t.channel == TemplateChannel.sms);
          final email = templates.where((t) => t.channel == TemplateChannel.email);
          return ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPadding,
              vertical: AppSpacing.md,
            ),
            children: [
              _SectionHeader(label: 'SMS'),
              for (final t in sms) _TemplateRow(template: t),
              const SizedBox(height: AppSpacing.xl),
              _SectionHeader(label: 'Email'),
              for (final t in email) _TemplateRow(template: t),
            ],
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text(label, style: AppTypography.footnote.copyWith(color: AppColors.textMuted)),
      );
}

class _TemplateRow extends ConsumerWidget {
  const _TemplateRow({required this.template});
  final MessageTemplate template;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: () => _openEditor(context, ref, template),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(template.name, style: AppTypography.callout),
                      const SizedBox(height: 2),
                      Text(template.templateCode,
                          style: AppTypography.caption
                              .copyWith(color: AppColors.textHint)),
                    ],
                  ),
                ),
                if (!template.isActive)
                  Text('Off',
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textMuted)),
                const SizedBox(width: AppSpacing.sm),
                Icon(Icons.chevron_right, size: 18, color: AppColors.separator),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void _openEditor(BuildContext context, WidgetRef ref, MessageTemplate t) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _TemplateEditor(template: t, ref: ref),
  );
}

class _TemplateEditor extends StatefulWidget {
  const _TemplateEditor({required this.template, required this.ref});
  final MessageTemplate template;
  final WidgetRef ref;

  @override
  State<_TemplateEditor> createState() => _TemplateEditorState();
}

class _TemplateEditorState extends State<_TemplateEditor> {
  late final TextEditingController _name;
  late final TextEditingController _subject;
  late final TextEditingController _body;
  late final TextEditingController _language;
  late bool _active;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.template.name);
    _subject = TextEditingController(text: widget.template.subject ?? '');
    _body = TextEditingController(text: widget.template.body);
    _language = TextEditingController(text: widget.template.language);
    _active = widget.template.isActive;
  }

  @override
  void dispose() {
    _name.dispose();
    _subject.dispose();
    _body.dispose();
    _language.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final updated = widget.template.copyWith(
      name: _name.text.trim(),
      subject: widget.template.channel == TemplateChannel.email
          ? _subject.text.trim()
          : null,
      body: _body.text,
      language: _language.text.trim().isEmpty ? 'en' : _language.text.trim(),
      isActive: _active,
    );
    try {
      await widget.ref.read(messageTemplatesProvider.notifier).upsert(updated);
      if (mounted) Navigator.of(context).pop();
    } on Object catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEmail = widget.template.channel == TemplateChannel.email;
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.screenPadding,
        right: AppSpacing.screenPadding,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.template.templateCode, style: AppTypography.headline),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _name,
              label: 'Name',
              prefixIcon: Icons.label_outline,
            ),
            const SizedBox(height: AppSpacing.md),
            if (isEmail) ...[
              AppTextField(
                controller: _subject,
                label: 'Subject',
                prefixIcon: Icons.subject,
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            Text(isEmail ? 'Body (HTML)' : 'Body',
                style: AppTypography.footnote.copyWith(color: AppColors.textMuted)),
            const SizedBox(height: AppSpacing.xs),
            Container(
              decoration: BoxDecoration(
                color: AppColors.fieldFill,
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: TextField(
                controller: _body,
                maxLines: 6,
                minLines: 3,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Use {{name}}, {{amount}}, {{invoice_number}} placeholders',
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text('Placeholders like {{name}} are filled per recipient when sent.',
                style: AppTypography.caption.copyWith(color: AppColors.textHint)),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _language,
              label: 'Language',
              prefixIcon: Icons.translate,
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(child: Text('Active', style: AppTypography.callout)),
                Switch(
                  value: _active,
                  activeThumbColor: AppColors.accent,
                  onChanged: (v) => setState(() => _active = v),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: _saving ? 'Saving…' : 'Save',
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}
