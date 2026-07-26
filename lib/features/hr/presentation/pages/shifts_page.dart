import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/clay.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_detail_scaffold.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../../../core/design/widgets/app_sheet.dart';
import '../../../../core/design/widgets/app_states.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../../core/design/widgets/app_toast.dart';
import '../../../../core/design/widgets/app_toggle.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../domain/entities/shift.dart';
import '../controllers/shifts_controller.dart';

class ShiftsPage extends ConsumerWidget {
  const ShiftsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(shiftsProvider);
    return AppDetailScaffold(
      eyebrow: 'HR',
      title: 'Shifts',
      description: 'Define the working windows staff are scheduled against.',
      maxContentWidth: 820,
      actions: [
        PermissionGate(
          module: 'hr',
          action: 'update',
          child: AppButton(
            label: 'New shift',
            icon: LucideIcons.plus,
            size: AppButtonSize.sm,
            onPressed: () => _edit(context, ref, null),
          ),
        ),
      ],
      child: async.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.xxl),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => const AppInlineBanner(
          message: 'Unable to load shifts.',
          type: BannerType.error,
        ),
        data: (shifts) {
          if (shifts.isEmpty) {
            return const AppEmptyState(
              icon: LucideIcons.clock,
              title: 'No shifts yet',
              body: 'Create a shift to define the windows staff work against.',
            );
          }
          return LayoutBuilder(
            builder: (context, constraints) {
              const gap = 12.0;
              const minTile = 240.0;
              final cols =
                  (constraints.maxWidth / (minTile + gap)).floor().clamp(1, 6);
              final tileWidth =
                  (constraints.maxWidth - gap * (cols - 1)) / cols;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final s in shifts)
                    SizedBox(
                      width: tileWidth,
                      child: _ShiftCard(
                        shift: s,
                        onTap: () => _edit(context, ref, s),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, Shift? shift) async {
    final data = await showAppSheet<Map<String, dynamic>>(
      context: context,
      builder: (_) => _ShiftSheet(shift: shift),
    );
    if (data == null || !context.mounted) return;
    final failure = await ref.read(shiftsProvider.notifier).upsert(data);
    if (!context.mounted) return;
    if (failure != null) {
      showAppToast(context, failure.message, type: BannerType.error);
    }
  }
}

class _ShiftCard extends StatelessWidget {
  const _ShiftCard({required this.shift, required this.onTap});
  final Shift shift;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Semantics(
      button: true,
      label: '${shift.name}, ${shift.isActive ? 'active' : 'inactive'}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: ClayContainer(
          variant: ClayVariant.soft,
          color: lum.surface,
          borderRadius: AppRadius.lg,
          isDark: lum.isDark,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      shift.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.headline.copyWith(
                        fontSize: 15,
                        color: lum.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  AppPill(
                    label: shift.isActive ? 'Active' : 'Inactive',
                    tone: shift.isActive
                        ? AppPillTone.success
                        : AppPillTone.neutral,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(LucideIcons.clock, size: 16, color: lum.g400),
                  const SizedBox(width: 8),
                  Text(
                    '${shift.startTime} – ${shift.endTime}',
                    style: AppTypography.monoValue.copyWith(
                      fontSize: 15,
                      color: lum.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${shift.graceMinutes} min grace · ${shift.breakMinutes} min break',
                style: AppTypography.caption.copyWith(color: lum.g500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShiftSheet extends StatefulWidget {
  const _ShiftSheet({this.shift});
  final Shift? shift;

  @override
  State<_ShiftSheet> createState() => _ShiftSheetState();
}

class _ShiftSheetState extends State<_ShiftSheet> {
  late final _nameCtrl = TextEditingController(text: widget.shift?.name);
  late final _graceCtrl = TextEditingController(
      text: (widget.shift?.graceMinutes ?? 15).toString());
  late final _breakCtrl = TextEditingController(
      text: (widget.shift?.breakMinutes ?? 60).toString());
  late String _start = widget.shift?.startTime ?? '09:00';
  late String _end = widget.shift?.endTime ?? '18:00';
  late bool _active = widget.shift?.isActive ?? true;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _graceCtrl.dispose();
    _breakCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickTime(bool start) async {
    final current = start ? _start : _end;
    final parts = current.split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 9,
          minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0),
    );
    if (picked == null) return;
    final text =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    setState(() => start ? _start = text : _end = text);
  }

  void _save() {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Name is required.');
      return;
    }
    Navigator.of(context).pop({
      'p_id': widget.shift?.id,
      'p_name': _nameCtrl.text.trim(),
      'p_start': _start,
      'p_end': _end,
      'p_grace': int.tryParse(_graceCtrl.text.trim()) ?? 15,
      'p_break': int.tryParse(_breakCtrl.text.trim()) ?? 60,
      'p_active': _active,
    });
  }

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSheetHeader(title: widget.shift == null ? 'New shift' : 'Edit shift'),
        AppTextField(
          controller: _nameCtrl,
          label: 'Name',
          prefixIcon: LucideIcons.tag,
        ),
        const SizedBox(height: AppSpacing.base),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _TimeField(
                label: 'Start',
                value: _start,
                onTap: () => _pickTime(true),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _TimeField(
                label: 'End',
                value: _end,
                onTap: () => _pickTime(false),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.base),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppTextField(
                controller: _graceCtrl,
                label: 'Grace (min)',
                prefixIcon: LucideIcons.timer,
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AppTextField(
                controller: _breakCtrl,
                label: 'Break (min)',
                prefixIcon: LucideIcons.coffee,
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.base),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: lum.surface2,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Active',
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: lum.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              AppToggle(
                value: _active,
                semanticLabel: 'Active',
                onChanged: (v) => setState(() => _active = v),
              ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.base),
          AppInlineBanner(message: _error!, type: BannerType.error),
        ],
        const SizedBox(height: AppSpacing.xl),
        AppButton(label: 'Save shift', fullWidth: true, onPressed: _save),
      ],
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField(
      {required this.label, required this.value, required this.onTap});
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Text(
            label,
            style: AppTypography.fieldLabel.copyWith(color: lum.g700),
          ),
        ),
        Semantics(
          button: true,
          label: '$label time, $value',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: ClayContainer(
              variant: ClayVariant.inset,
              color: lum.surface2,
              borderRadius: AppRadius.md,
              isDark: lum.isDark,
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Icon(LucideIcons.clock, size: 17, color: lum.g400),
                  const SizedBox(width: 10),
                  Text(
                    value,
                    style: AppTypography.monoValue.copyWith(
                      fontSize: 15,
                      color: lum.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
