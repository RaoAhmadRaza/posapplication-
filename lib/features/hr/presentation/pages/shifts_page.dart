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
import '../../domain/entities/shift.dart';
import '../controllers/shifts_controller.dart';

class ShiftsPage extends ConsumerWidget {
  const ShiftsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(shiftsProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios,
              color: AppColors.accent, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Shifts', style: AppTypography.headline),
      ),
      floatingActionButton: PermissionGate(
        module: 'hr',
        action: 'update',
        child: FloatingActionButton(
          backgroundColor: AppColors.accent,
          onPressed: () => _edit(context, ref, null),
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              child: AppInlineBanner(
                  message: 'Could not load shifts.', type: BannerType.error),
            ),
          ),
          data: (shifts) {
            if (shifts.isEmpty) {
              return Center(
                child: Text('No shifts yet.',
                    style: AppTypography.footnote
                        .copyWith(color: AppColors.textMuted)),
              );
            }
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              children: [
                for (final s in shifts)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _ShiftRow(
                        shift: s, onTap: () => _edit(context, ref, s)),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _edit(
      BuildContext context, WidgetRef ref, Shift? shift) async {
    final data = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      builder: (_) => _ShiftSheet(shift: shift),
    );
    if (data == null || !context.mounted) return;
    final failure = await ref.read(shiftsProvider.notifier).upsert(data);
    if (!context.mounted) return;
    if (failure != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }
}

class _ShiftRow extends StatelessWidget {
  const _ShiftRow({required this.shift, required this.onTap});
  final Shift shift;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.separator, width: 0.5),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(shift.name,
                        style: AppTypography.subhead
                            .copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                        '${shift.startTime}–${shift.endTime} · grace ${shift.graceMinutes}m · break ${shift.breakMinutes}m',
                        style: AppTypography.caption
                            .copyWith(color: AppColors.textMuted)),
                  ],
                ),
              ),
              if (!shift.isActive)
                Text('Inactive',
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textMuted)),
              const Icon(Icons.chevron_right, color: AppColors.textMuted),
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
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.screenPadding,
        right: AppSpacing.screenPadding,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.shift == null ? 'New Shift' : 'Edit Shift',
              style: AppTypography.headline),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
              controller: _nameCtrl,
              label: 'Name',
              prefixIcon: Icons.schedule),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                  child: _TimeField(
                      label: 'Start',
                      value: _start,
                      onTap: () => _pickTime(true))),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                  child: _TimeField(
                      label: 'End',
                      value: _end,
                      onTap: () => _pickTime(false))),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                  child: AppTextField(
                      controller: _graceCtrl,
                      label: 'Grace (min)',
                      prefixIcon: Icons.timer_outlined,
                      keyboardType: TextInputType.number)),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                  child: AppTextField(
                      controller: _breakCtrl,
                      label: 'Break (min)',
                      prefixIcon: Icons.free_breakfast_outlined,
                      keyboardType: TextInputType.number)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeThumbColor: AppColors.accent,
            title: Text('Active', style: AppTypography.body),
            value: _active,
            onChanged: (v) => setState(() => _active = v),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            AppInlineBanner(message: _error!, type: BannerType.error),
          ],
          const SizedBox(height: AppSpacing.md),
          AppButton(label: 'Save', fullWidth: true, onPressed: _save),
        ],
      ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(label, style: AppTypography.fieldLabel),
        ),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.fieldFill,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              const Icon(Icons.access_time,
                  color: AppColors.textMuted, size: 20),
              const SizedBox(width: 10),
              Text(value, style: AppTypography.fieldText),
            ]),
          ),
        ),
      ],
    );
  }
}
