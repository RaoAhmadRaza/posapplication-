import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../domain/entities/report_schedule.dart';
import '../controllers/reporting_controllers.dart';

const _reportTypes = <String>[
  'daily_sales',
  'inventory_valuation',
  'product_performance',
  'customer_aging',
  'supplier_aging',
];
const _frequencies = <String>['DAILY', 'WEEKLY', 'MONTHLY'];
const _formats = <String>['PDF', 'EXCEL'];

/// Zero-pads to 2 digits.
String _pad2(int n) => n.toString().padLeft(2, '0');

/// Formats a date as 'yyyy-MM-dd HH:mm' (no intl); returns '—' when null.
String _formatRun(DateTime? d) {
  if (d == null) return '—';
  return '${d.year}-${_pad2(d.month)}-${_pad2(d.day)} '
      '${_pad2(d.hour)}:${_pad2(d.minute)}';
}

class ScheduledReportsPage extends ConsumerWidget {
  const ScheduledReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        title: Text('Scheduled Reports', style: AppTypography.largeTitle),
        actions: [
          PermissionGate(
            module: 'reports',
            action: 'export',
            child: IconButton(
              icon: const Icon(Icons.add, color: AppColors.accent),
              tooltip: 'New schedule',
              onPressed: () => _openForm(context, ref, null),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: PermissionGate(
          module: 'reports',
          action: 'export',
          fallback: Center(
            child: Text(
              'No access.',
              style:
                  AppTypography.subhead.copyWith(color: AppColors.textMuted),
            ),
          ),
          child: _Body(),
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedules = ref.watch(reportSchedulesProvider);
    return ListView(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
      children: [
        const SizedBox(height: AppSpacing.base),
        const AppInlineBanner(
          type: BannerType.info,
          message:
              'Delivery email send activates with Notifications (M11); '
              'until then runs are queued.',
        ),
        const SizedBox(height: AppSpacing.lg),
        ...switch (schedules) {
          AsyncData(:final value) when value.isEmpty => [_muted(
              'No scheduled reports yet.')],
          AsyncData(:final value) => value
              .map((s) => _ScheduleCard(
                    schedule: s,
                    onTap: () => _openForm(context, ref, s),
                  ))
              .toList(),
          AsyncError() => const [
              AppInlineBanner(
                type: BannerType.error,
                message: 'Could not load schedules.',
              ),
            ],
          _ => const [
              Padding(
                padding: EdgeInsets.only(top: AppSpacing.xxl),
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
        },
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }

  Widget _muted(String text) => Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xxl),
        child: Center(
          child: Text(
            text,
            style: AppTypography.subhead.copyWith(color: AppColors.textMuted),
          ),
        ),
      );
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({required this.schedule, required this.onTap});

  final ReportSchedule schedule;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.separator, width: 0.5),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.base, vertical: AppSpacing.sm),
        title: Text(
          schedule.name,
          style: AppTypography.headline.copyWith(color: AppColors.textPrimary),
        ),
        subtitle: Text(
          '${schedule.reportType} · ${schedule.frequency} · '
          'next: ${_formatRun(schedule.nextRunAt)}',
          style: AppTypography.footnote.copyWith(color: AppColors.textHint),
        ),
        trailing: _StatusChip(active: schedule.isActive),
        onTap: onTap,
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.success : AppColors.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Text(
        active ? 'Active' : 'Paused',
        style: AppTypography.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

Future<void> _openForm(
  BuildContext context,
  WidgetRef ref,
  ReportSchedule? existing,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
    ),
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
    _reportType = e?.reportType ?? _reportTypes.first;
    _frequency = e?.frequency ?? _frequencies.first;
    _format = e?.outputFormat ?? _formats.first;
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(failure.message)));
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
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
            Text(
              isEdit ? 'Edit Schedule' : 'New Schedule',
              style: AppTypography.title2,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              controller: _nameCtrl,
              label: 'Name',
              prefixIcon: Icons.badge_outlined,
              hint: 'Weekly sales summary',
            ),
            const SizedBox(height: AppSpacing.fieldGap),
            _Dropdown(
              label: 'Report type',
              value: _reportType,
              options: _reportTypes,
              onChanged: (v) => setState(() => _reportType = v),
            ),
            const SizedBox(height: AppSpacing.fieldGap),
            _Dropdown(
              label: 'Frequency',
              value: _frequency,
              options: _frequencies,
              onChanged: (v) => setState(() => _frequency = v),
            ),
            const SizedBox(height: AppSpacing.fieldGap),
            AppTextField(
              controller: _recipientsCtrl,
              label: 'Recipients (comma-separated)',
              prefixIcon: Icons.email_outlined,
              hint: 'a@x.com, b@y.com',
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: AppSpacing.fieldGap),
            _Dropdown(
              label: 'Format',
              value: _format,
              options: _formats,
              onChanged: (v) => setState(() => _format = v),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Text('Active', style: AppTypography.fieldLabel),
                const Spacer(),
                Switch(
                  value: _active,
                  activeThumbColor: AppColors.accent,
                  onChanged: (v) => setState(() => _active = v),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: isEdit ? 'Save changes' : 'Create schedule',
              fullWidth: true,
              loading: _saving,
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}

class _Dropdown extends StatelessWidget {
  const _Dropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(label, style: AppTypography.fieldLabel),
        ),
        Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.fieldFill,
            borderRadius: BorderRadius.circular(AppRadius.field),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: value,
              style: AppTypography.fieldText,
              icon: const Icon(Icons.expand_more, color: AppColors.textMuted),
              items: options
                  .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                  .toList(),
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ),
      ],
    );
  }
}
