import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/clay.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_detail_scaffold.dart';
import '../../../../core/design/widgets/app_dropdown.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../../../core/design/widgets/app_sheet.dart';
import '../../../../core/design/widgets/app_states.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../../core/design/widgets/app_toast.dart';
import '../../../../core/design/widgets/app_toggle.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../domain/entities/report_schedule.dart';
import '../controllers/reporting_controllers.dart';

/// Report-type options with human labels (the raw values are the RPC contract).
const _reportTypeOptions = <AppDropdownOption<String>>[
  AppDropdownOption(value: 'daily_sales', label: 'Daily sales'),
  AppDropdownOption(value: 'inventory_valuation', label: 'Inventory valuation'),
  AppDropdownOption(value: 'product_performance', label: 'Product performance'),
  AppDropdownOption(value: 'customer_aging', label: 'Customer aging'),
  AppDropdownOption(value: 'supplier_aging', label: 'Supplier aging'),
];
const _frequencyOptions = <AppDropdownOption<String>>[
  AppDropdownOption(value: 'DAILY', label: 'Daily'),
  AppDropdownOption(value: 'WEEKLY', label: 'Weekly'),
  AppDropdownOption(value: 'MONTHLY', label: 'Monthly'),
];
const _formatOptions = <AppDropdownOption<String>>[
  AppDropdownOption(value: 'PDF', label: 'PDF'),
  AppDropdownOption(value: 'EXCEL', label: 'Excel'),
];

String _reportTypeLabel(String value) => _reportTypeOptions
    .firstWhere(
      (o) => o.value == value,
      orElse: () => AppDropdownOption(value: value, label: value),
    )
    .label;

String _pad2(int n) => n.toString().padLeft(2, '0');

String _formatRun(DateTime? d) => d == null
    ? '—'
    : '${d.year}-${_pad2(d.month)}-${_pad2(d.day)} '
        '${_pad2(d.hour)}:${_pad2(d.minute)}';

class ScheduledReportsPage extends ConsumerWidget {
  const ScheduledReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lum = context.lum;
    return AppDetailScaffold(
      eyebrow: 'Reports',
      title: 'Scheduled reports',
      description: 'Automated report delivery, by email, on a schedule.',
      actions: [
        PermissionGate(
          module: 'reports',
          action: 'export',
          child: AppButton(
            label: 'New',
            size: AppButtonSize.sm,
            icon: LucideIcons.plus,
            onPressed: () => _openForm(context, ref, null),
          ),
        ),
      ],
      child: PermissionGate(
        module: 'reports',
        action: 'export',
        fallback: Center(
          child: Text(
            'You don’t have access to scheduled reports.',
            style: AppTypography.subhead.copyWith(color: lum.g500),
          ),
        ),
        child: _Body(),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedules = ref.watch(reportSchedulesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppInlineBanner(
          type: BannerType.info,
          message: 'Email delivery activates with Notifications; until '
              'then, due runs are queued.',
        ),
        const SizedBox(height: AppSpacing.lg),
        ...switch (schedules) {
                  AsyncData(:final value) when value.isEmpty => [
                      const AppEmptyState(
                        icon: LucideIcons.calendarClock,
                        title: 'No scheduled reports yet',
                        body: 'Create one to have a report emailed on a '
                            'recurring schedule.',
                      ),
                    ],
                  AsyncData(:final value) => [
                      for (final s in value) ...[
                        _ScheduleCard(
                          schedule: s,
                          onTap: () => _openForm(context, ref, s),
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                    ],
                  AsyncError() => const [
                      AppErrorState(
                        title: 'Unable to load schedules',
                        body: 'We couldn’t reach the server. Please try again.',
                      ),
                    ],
                  _ => const [
                      Padding(
                        padding: EdgeInsets.only(top: AppSpacing.xxl),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ],
                },
      ],
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({required this.schedule, required this.onTap});

  final ReportSchedule schedule;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      onTap: onTap,
      child: Row(
        children: [
          ClayContainer(
            variant: ClayVariant.soft,
            color: lum.accentSoft,
            borderRadius: 13,
            isDark: lum.isDark,
            width: 42,
            height: 42,
            child: Icon(LucideIcons.calendarClock, size: 20, color: lum.accent),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  schedule.name,
                  style: AppTypography.callout.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: lum.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_reportTypeLabel(schedule.reportType)} · '
                  '${schedule.frequency.toLowerCase()} · '
                  'next: ${_formatRun(schedule.nextRunAt)}',
                  style: AppTypography.footnote.copyWith(color: lum.g500),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          AppPill(
            label: schedule.isActive ? 'Active' : 'Paused',
            tone: schedule.isActive ? AppPillTone.success : AppPillTone.neutral,
          ),
          const SizedBox(width: 10),
          Icon(LucideIcons.chevronRight, size: 18, color: lum.g400),
        ],
      ),
    );
  }
}

Future<void> _openForm(
  BuildContext context,
  WidgetRef ref,
  ReportSchedule? existing,
) {
  return showAppSheet<void>(
    context: context,
    builder: (_) => _ScheduleForm(existing: existing),
  );
}

class _ScheduleForm extends ConsumerStatefulWidget {
  const _ScheduleForm({this.existing});

  final ReportSchedule? existing;

  @override
  ConsumerState<_ScheduleForm> createState() => _ScheduleFormState();
}

class _ScheduleFormState extends ConsumerState<_ScheduleForm> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _recipientsCtrl;
  late String _reportType;
  late String _frequency;
  late String _format;
  late bool _active;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _recipientsCtrl =
        TextEditingController(text: e?.recipients.join(', ') ?? '');
    _reportType = e?.reportType ?? _reportTypeOptions.first.value;
    _frequency = e?.frequency ?? _frequencyOptions.first.value;
    _format = e?.outputFormat ?? _formatOptions.first.value;
    _active = e?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _recipientsCtrl.dispose();
    super.dispose();
  }

  List<String> _parseRecipients() => _recipientsCtrl.text
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  Future<void> _save() async {
    setState(() => _saving = true);
    final failure = await ref.read(reportSchedulesProvider.notifier).upsert(
          id: widget.existing?.id,
          reportType: _reportType,
          name: _nameCtrl.text.trim(),
          frequency: _frequency,
          filters: const <String, dynamic>{},
          recipients: _parseRecipients(),
          format: _format,
          active: _active,
        );
    if (!mounted) return;
    if (failure != null) {
      setState(() => _saving = false);
      showAppToast(context, failure.message, type: BannerType.error);
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final isEdit = widget.existing != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSheetHeader(title: isEdit ? 'Edit schedule' : 'New schedule'),
        AppTextField(
          controller: _nameCtrl,
          label: 'Name',
          prefixIcon: LucideIcons.tag,
          hint: 'Weekly sales summary',
        ),
        const SizedBox(height: AppSpacing.fieldGap),
        _Field(
          label: 'Report type',
          child: AppDropdown<String>(
            value: _reportType,
            options: _reportTypeOptions,
            onSelected: (v) => setState(() => _reportType = v),
          ),
        ),
        const SizedBox(height: AppSpacing.fieldGap),
        _Field(
          label: 'Frequency',
          child: AppDropdown<String>(
            value: _frequency,
            options: _frequencyOptions,
            onSelected: (v) => setState(() => _frequency = v),
          ),
        ),
        const SizedBox(height: AppSpacing.fieldGap),
        AppTextField(
          controller: _recipientsCtrl,
          label: 'Recipients',
          prefixIcon: LucideIcons.mail,
          hint: 'comma-separated emails',
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: AppSpacing.fieldGap),
        _Field(
          label: 'Format',
          child: AppDropdown<String>(
            value: _format,
            options: _formatOptions,
            onSelected: (v) => setState(() => _format = v),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Active',
                    style: AppTypography.label.copyWith(color: lum.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Paused schedules don’t send.',
                    style: AppTypography.footnote.copyWith(color: lum.g500),
                  ),
                ],
              ),
            ),
            AppToggle(
              value: _active,
              semanticLabel: 'Active',
              onChanged: (v) => setState(() => _active = v),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Cancel',
                variant: AppButtonVariant.tinted,
                onPressed: _saving ? null : () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AppButton(
                label: isEdit ? 'Save changes' : 'Create schedule',
                loading: _saving,
                onPressed: _saving ? null : _save,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: AppTypography.fieldLabel.copyWith(color: lum.g600),
          ),
        ),
        child,
      ],
    );
  }
}
