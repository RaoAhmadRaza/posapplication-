import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_detail_scaffold.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../../../core/design/widgets/app_section_card.dart';
import '../../../../core/design/widgets/app_sheet.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../../core/design/widgets/app_toast.dart';
import '../../../../core/design/widgets/app_toggle.dart';
import '../../domain/entities/message_template.dart';
import '../controllers/admin_controllers.dart';

class TemplatesAdminPage extends ConsumerWidget {
  const TemplatesAdminPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(messageTemplatesProvider);

    return AppDetailScaffold(
      eyebrow: 'Notifications',
      title: 'Message templates',
      description: 'SMS & email copy sent to your customers.',
      child: state.when(
        loading: () => const Padding(
          padding: EdgeInsets.only(top: 64),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => const AppInlineBanner(
          message: 'Unable to load templates.',
          type: BannerType.error,
        ),
        data: (templates) {
          final sms =
              templates.where((t) => t.channel == TemplateChannel.sms).toList();
          final email = templates
              .where((t) => t.channel == TemplateChannel.email)
              .toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TemplateSection(
                eyebrow: 'SMS templates',
                templates: sms,
                icon: LucideIcons.messageSquare,
                accent: TemplateChannel.sms,
              ),
              const SizedBox(height: AppSpacing.lg),
              _TemplateSection(
                eyebrow: 'Email templates',
                templates: email,
                icon: LucideIcons.mail,
                accent: TemplateChannel.email,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TemplateSection extends ConsumerWidget {
  const _TemplateSection({
    required this.eyebrow,
    required this.templates,
    required this.icon,
    required this.accent,
  });

  final String eyebrow;
  final List<MessageTemplate> templates;
  final IconData icon;
  final TemplateChannel accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lum = context.lum;
    return AppSectionCard(
      eyebrow: eyebrow,
      padded: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < templates.length; i++) ...[
            if (i > 0) Divider(height: 1, color: lum.hairline),
            _TemplateRow(
              template: templates[i],
              icon: icon,
              isEmail: accent == TemplateChannel.email,
              onTap: () => _openEditor(context, ref, templates[i]),
            ),
          ],
        ],
      ),
    );
  }
}

class _TemplateRow extends StatelessWidget {
  const _TemplateRow({
    required this.template,
    required this.icon,
    required this.isEmail,
    required this.onTap,
  });

  final MessageTemplate template;
  final IconData icon;
  final bool isEmail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isEmail ? lum.beamSoft : lum.accentSoft,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(icon,
                  size: 18, color: isEmail ? lum.beam : lum.accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    template.name,
                    style: AppTypography.callout.copyWith(
                      fontWeight: FontWeight.w600,
                      color: lum.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    template.templateCode,
                    style: AppTypography.monoValue.copyWith(
                      fontSize: 11.5,
                      color: lum.g500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            AppPill(
              label: template.isActive ? 'On' : 'Off',
              tone: template.isActive ? AppPillTone.success : AppPillTone.neutral,
              showDot: false,
            ),
            const SizedBox(width: 8),
            Icon(LucideIcons.chevronRight, size: 18, color: lum.g400),
          ],
        ),
      ),
    );
  }
}

void _openEditor(BuildContext context, WidgetRef ref, MessageTemplate t) {
  showAppSheet<void>(
    context: context,
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
      if (mounted) {
        Navigator.of(context).pop();
        showAppToast(context, 'Template saved', type: BannerType.success);
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showAppToast(context, 'Save failed: $e', type: BannerType.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final isEmail = widget.template.channel == TemplateChannel.email;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSheetHeader(
          title: 'Edit template',
          subtitle: widget.template.templateCode,
        ),
        AppTextField(
          controller: _name,
          label: 'Name',
          prefixIcon: LucideIcons.tag,
        ),
        const SizedBox(height: AppSpacing.md),
        if (isEmail) ...[
          AppTextField(
            controller: _subject,
            label: 'Subject',
            prefixIcon: LucideIcons.type,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        AppTextField(
          controller: _body,
          label: isEmail ? 'Body (HTML)' : 'Body',
          prefixIcon: LucideIcons.alignLeft,
          maxLines: 5,
          helperText:
              'Placeholders like {{name}}, {{amount}}, {{invoice_number}} '
              'are filled per recipient when sent.',
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          controller: _language,
          label: 'Language',
          prefixIcon: LucideIcons.languages,
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: Text(
                'Active',
                style: AppTypography.callout.copyWith(
                  fontWeight: FontWeight.w600,
                  color: lum.textPrimary,
                ),
              ),
            ),
            AppToggle(
              value: _active,
              semanticLabel: 'Active',
              onChanged: (v) => setState(() => _active = v),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: 'Save',
          fullWidth: true,
          loading: _saving,
          onPressed: _saving ? null : _save,
        ),
      ],
    );
  }
}
