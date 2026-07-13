import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
import '../../data/services/repair_label_pdf_service.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/format.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../../../core/widgets/signature_pad.dart';
import '../../domain/usecases/signature_usecases.dart';
import '../../domain/entities/repair_job.dart';
import '../../domain/entities/repair_part.dart';
import '../../domain/entities/repair_status_history.dart';
import '../../domain/entities/repair_results.dart';
import '../controllers/repair_jobs_controller.dart';
import '../controllers/repair_detail_provider.dart';
import '../widgets/repair_product_picker.dart';
import '../widgets/repair_status_ui.dart';

class RepairDetailPage extends ConsumerWidget {
  const RepairDetailPage({super.key, required this.repairId});
  final String repairId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(repairJobDetailProvider(repairId));
    final techs = ref.watch(techniciansProvider).value ?? const <Technician>[];
    final techNames = {for (final t in techs) t.id: t.name};

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
        title: Text('Repair Job', style: AppTypography.headline),
      ),
      body: SafeArea(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              child: AppInlineBanner(
                  message: 'Could not load this job.',
                  type: BannerType.error),
            ),
          ),
          data: (detail) =>
              _Body(detail: detail, techs: techs, techNames: techNames),
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body(
      {required this.detail, required this.techs, required this.techNames});
  final RepairDetail detail;
  final List<Technician> techs;
  final Map<String, String> techNames;

  RepairJob get job => detail.job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final closed = job.status == RepairStatus.delivered ||
        job.status == RepairStatus.cancelled;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      children: [
        _HeaderCard(job: job, techNames: techNames),
        const SizedBox(height: AppSpacing.md),
        if (!closed) _ActionsRow(job: job, techs: techs),
        if (!closed) const SizedBox(height: AppSpacing.md),
        _DiagnosisCard(job: job),
        const SizedBox(height: AppSpacing.md),
        _PartsCard(detail: detail, editable: !closed),
        const SizedBox(height: AppSpacing.md),
        _CostSummaryCard(detail: detail),
        const SizedBox(height: AppSpacing.md),
        _HistoryCard(history: detail.history),
        const SizedBox(height: AppSpacing.xl),
        if (job.status == RepairStatus.ready)
          PermissionGate(
            module: 'repair',
            action: 'update',
            child: AppButton(
              label: 'Close & Invoice',
              onPressed: () => _openCloseDialog(context, ref, detail),
              fullWidth: true,
            ),
          ),
        if (job.invoiceId != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: Text('Invoiced • delivered',
                textAlign: TextAlign.center,
                style: AppTypography.footnote
                    .copyWith(color: AppColors.success)),
          ),
        if (job.customerSignatureUrl != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: AppButton(
              label: 'View Signature',
              variant: AppButtonVariant.tinted,
              icon: Icons.draw_outlined,
              onPressed: () =>
                  _viewSignature(context, ref, job.customerSignatureUrl!),
              fullWidth: true,
            ),
          ),
      ],
    );
  }
}

/// Fetches a fresh short-lived signed URL for the stored signature path and
/// renders it (never a public link). Read is gated by the storage RLS policy.
Future<void> _viewSignature(
    BuildContext context, WidgetRef ref, String path) async {
  final (url, failure) =
      await ref.read(repairSignatureUrlUseCaseProvider).call(path);
  if (!context.mounted) return;
  if (failure != null || url == null) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(failure?.message ?? 'Could not load signature.')));
    return;
  }
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.background,
      title: const Text('Customer Signature'),
      content: Image.network(url, fit: BoxFit.contain),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close')),
      ],
    ),
  );
}

// ---- Header ----

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.job, required this.techNames});
  final RepairJob job;
  final Map<String, String> techNames;

  @override
  Widget build(BuildContext context) {
    final device = [job.deviceBrand, job.deviceModel]
        .where((e) => e != null && e.isNotEmpty)
        .join(' ');
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(job.jobNumber, style: AppTypography.title2),
              ),
              IconButton(
                icon: const Icon(Icons.qr_code_2, color: AppColors.accent),
                tooltip: 'Print device label',
                onPressed: () => Printing.layoutPdf(
                  onLayout: (_) => RepairLabelPdfService().generate(job),
                ),
              ),
              RepairStatusBadge(status: job.status),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          RepairPriorityChip(priority: job.priority),
          const SizedBox(height: AppSpacing.md),
          _kv('Device',
              device.isEmpty ? job.deviceType : '${job.deviceType} · $device'),
          if (job.serialNo != null) _kv('Serial', job.serialNo!),
          if (job.imei != null) _kv('IMEI', job.imei!),
          if (job.customerName != null) _kv('Customer', job.customerName!),
          _kv(
              'Technician',
              job.technicianId == null
                  ? 'Unassigned'
                  : (techNames[job.technicianId] ?? 'Assigned')),
          const SizedBox(height: AppSpacing.sm),
          Text('Reported issue',
              style: AppTypography.caption
                  .copyWith(color: AppColors.textMuted)),
          const SizedBox(height: 2),
          Text(job.reportedIssue, style: AppTypography.body),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 90,
              child: Text(k,
                  style: AppTypography.footnote
                      .copyWith(color: AppColors.textMuted)),
            ),
            Expanded(child: Text(v, style: AppTypography.footnote)),
          ],
        ),
      );
}

// ---- Actions (status + assign) ----

class _ActionsRow extends ConsumerWidget {
  const _ActionsRow({required this.job, required this.techs});
  final RepairJob job;
  final List<Technician> techs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: PermissionGate(
            module: 'repair',
            action: 'update',
            child: AppButton(
              label: 'Change Status',
              variant: AppButtonVariant.tinted,
              onPressed: () => _openStatusSheet(context, ref, job),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: PermissionGate(
            module: 'repair',
            action: 'update',
            child: AppButton(
              label: 'Assign',
              variant: AppButtonVariant.tinted,
              onPressed: () => _openAssignSheet(context, ref, job, techs),
            ),
          ),
        ),
      ],
    );
  }
}

Future<void> _openStatusSheet(
    BuildContext context, WidgetRef ref, RepairJob job) async {
  final target = await showModalBottomSheet<RepairStatus>(
    context: context,
    builder: (_) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: AppSpacing.md),
          Text('Move to', style: AppTypography.title2),
          const SizedBox(height: AppSpacing.sm),
          for (final s in RepairStatus.values)
            if (s != job.status)
              ListTile(
                title: Text(repairStatusLabels[s]!),
                onTap: () => Navigator.of(context).pop(s),
              ),
        ],
      ),
    ),
  );
  if (target == null || !context.mounted) return;
  final failure = await ref
      .read(repairJobsProvider.notifier)
      .changeStatus(repairId: job.id, newStatus: target);
  if (!context.mounted) return;
  if (failure != null) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(failure.message)));
  }
}

Future<void> _openAssignSheet(BuildContext context, WidgetRef ref,
    RepairJob job, List<Technician> techs) async {
  final tech = await showModalBottomSheet<Technician>(
    context: context,
    builder: (_) => SafeArea(
      child: techs.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Text('No users available to assign.'),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: AppSpacing.md),
                Text('Assign Technician', style: AppTypography.title2),
                const SizedBox(height: AppSpacing.sm),
                for (final t in techs)
                  ListTile(
                    leading: const Icon(Icons.build_outlined),
                    title: Text(t.name),
                    onTap: () => Navigator.of(context).pop(t),
                  ),
              ],
            ),
    ),
  );
  if (tech == null || !context.mounted) return;
  final failure = await ref
      .read(repairJobsProvider.notifier)
      .assignTechnician(job.id, tech.id);
  if (!context.mounted) return;
  if (failure != null) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(failure.message)));
  }
}

// ---- Diagnosis ----

class _DiagnosisCard extends ConsumerWidget {
  const _DiagnosisCard({required this.job});
  final RepairJob job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Diagnosis', style: AppTypography.headline),
              ),
              PermissionGate(
                module: 'repair',
                action: 'update',
                child: TextButton(
                  onPressed: () => _openDiagnosisDialog(context, ref, job),
                  child: Text(job.diagnosis == null ? 'Add' : 'Edit'),
                ),
              ),
            ],
          ),
          Text(
            job.diagnosis ?? 'No diagnosis recorded.',
            style: AppTypography.footnote.copyWith(
                color: job.diagnosis == null
                    ? AppColors.textMuted
                    : AppColors.textPrimary),
          ),
          if (job.estimatedCost != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text('Estimate: ${formatPkr(job.estimatedCost!)}',
                style: AppTypography.footnote
                    .copyWith(color: AppColors.textMuted)),
          ],
          if (job.customerApproved == true) ...[
            const SizedBox(height: 2),
            Text('Customer approved',
                style: AppTypography.caption
                    .copyWith(color: AppColors.success)),
          ],
        ],
      ),
    );
  }
}

Future<void> _openDiagnosisDialog(
    BuildContext context, WidgetRef ref, RepairJob job) async {
  final diagCtrl = TextEditingController(text: job.diagnosis ?? '');
  final estCtrl = TextEditingController(
      text: job.estimatedCost == null ? '' : job.estimatedCost.toString());
  var approved = job.customerApproved ?? false;

  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        backgroundColor: AppColors.background,
        title: const Text('Diagnosis'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(
                  controller: diagCtrl,
                  label: 'Diagnosis',
                  prefixIcon: Icons.medical_services_outlined),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                  controller: estCtrl,
                  label: 'Estimated Cost',
                  prefixIcon: Icons.attach_money,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true)),
              const SizedBox(height: AppSpacing.sm),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: approved,
                onChanged: (v) => setState(() => approved = v ?? false),
                title: const Text('Customer approved'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Save')),
        ],
      ),
    ),
  );
  if (saved != true || !context.mounted) return;
  final failure =
      await ref.read(repairJobsProvider.notifier).setDiagnosis(
            repairId: job.id,
            diagnosis: diagCtrl.text.trim(),
            estimatedCost: double.tryParse(estCtrl.text.trim()),
            customerApproved: approved,
          );
  if (!context.mounted) return;
  if (failure != null) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(failure.message)));
  }
}

// ---- Parts ----

class _PartsCard extends ConsumerWidget {
  const _PartsCard({required this.detail, required this.editable});
  final RepairDetail detail;
  final bool editable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parts = detail.parts;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Parts', style: AppTypography.headline)),
              if (editable)
                PermissionGate(
                  module: 'repair',
                  action: 'update',
                  child: TextButton.icon(
                    onPressed: () =>
                        _openAddPart(context, ref, detail.job.id),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add'),
                  ),
                ),
            ],
          ),
          if (parts.isEmpty)
            Text('No parts used.',
                style: AppTypography.footnote
                    .copyWith(color: AppColors.textMuted))
          else
            for (final p in parts)
              _PartRow(
                part: p,
                editable: editable,
                onRemove: () => _removePart(context, ref, detail.job.id, p),
              ),
        ],
      ),
    );
  }
}

class _PartRow extends StatelessWidget {
  const _PartRow(
      {required this.part, required this.editable, required this.onRemove});
  final RepairPart part;
  final bool editable;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(part.productName ?? 'Part',
                    style: AppTypography.footnote),
                Text('${part.qty.toStringAsFixed(0)} × ${formatPkr(part.unitCost)}',
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textMuted)),
              ],
            ),
          ),
          Text(formatPkr(part.totalCost), style: AppTypography.footnote),
          if (editable)
            IconButton(
              icon: const Icon(Icons.close,
                  size: 18, color: AppColors.destructive),
              onPressed: onRemove,
            ),
        ],
      ),
    );
  }
}

Future<void> _openAddPart(
    BuildContext context, WidgetRef ref, String repairId) async {
  final product = await showRepairProductPicker(context);
  if (product == null || !context.mounted) return;
  final qtyCtrl = TextEditingController(text: '1');
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.background,
      title: Text(product.name),
      content: AppTextField(
        controller: qtyCtrl,
        label: 'Quantity',
        prefixIcon: Icons.numbers,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel')),
        TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Add')),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  final qty = double.tryParse(qtyCtrl.text.trim()) ?? 0;
  if (qty <= 0) return;
  final failure = await ref.read(repairJobsProvider.notifier).addPart(
        repairId: repairId,
        productId: product.id,
        qty: qty,
      );
  if (!context.mounted) return;
  if (failure != null) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(failure.message)));
  }
}

Future<void> _removePart(BuildContext context, WidgetRef ref, String repairId,
    RepairPart part) async {
  final failure =
      await ref.read(repairJobsProvider.notifier).removePart(repairId, part.id);
  if (!context.mounted) return;
  if (failure != null) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(failure.message)));
  }
}

// ---- Cost summary ----

class _CostSummaryCard extends StatelessWidget {
  const _CostSummaryCard({required this.detail});
  final RepairDetail detail;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          _row('Parts cost', formatPkr(detail.partsCost)),
          if (detail.job.estimatedCost != null)
            _row('Estimate', formatPkr(detail.job.estimatedCost!)),
          if (detail.job.finalCost != null)
            _row('Final (invoiced)', formatPkr(detail.job.finalCost!),
                bold: true),
        ],
      ),
    );
  }

  Widget _row(String k, String v, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(k,
                style: AppTypography.footnote
                    .copyWith(color: AppColors.textMuted)),
            Text(v,
                style: AppTypography.footnote.copyWith(
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
          ],
        ),
      );
}

// ---- History ----

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.history});
  final List<RepairStatusHistory> history;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('History', style: AppTypography.headline),
          const SizedBox(height: AppSpacing.sm),
          if (history.isEmpty)
            Text('No status changes yet.',
                style: AppTypography.footnote
                    .copyWith(color: AppColors.textMuted))
          else
            for (final h in history)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.circle, size: 8, color: AppColors.accent),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            h.oldStatus == null
                                ? repairStatusLabels[h.newStatus]!
                                : '${repairStatusLabels[h.oldStatus]!} → ${repairStatusLabels[h.newStatus]!}',
                            style: AppTypography.footnote,
                          ),
                          Text(_fmtDate(h.changedAt),
                              style: AppTypography.caption
                                  .copyWith(color: AppColors.textMuted)),
                          if (h.notes != null && h.notes!.isNotEmpty)
                            Text(h.notes!,
                                style: AppTypography.caption
                                    .copyWith(color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  static String _fmtDate(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }
}

// ---- Close & Invoice ----

Future<void> _openCloseDialog(
    BuildContext context, WidgetRef ref, RepairDetail detail) async {
  final labourCtrl = TextEditingController();
  final taxCtrl = TextEditingController(text: '0');
  final markupCtrl = TextEditingController(text: '0');
  final paidCtrl = TextEditingController();
  final warrantyCtrl = TextEditingController();
  Uint8List? sigBytes;
  String? error;
  var saving = false;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        backgroundColor: AppColors.background,
        title: const Text('Close & Invoice'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(
                  controller: labourCtrl,
                  label: 'Labour Price',
                  prefixIcon: Icons.attach_money,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true)),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                  controller: taxCtrl,
                  label: 'Labour Tax %',
                  prefixIcon: Icons.percent,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true)),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                  controller: markupCtrl,
                  label: 'Parts Markup % (all parts)',
                  prefixIcon: Icons.percent,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true)),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                  controller: paidCtrl,
                  label: 'Paid Amount (blank = full)',
                  prefixIcon: Icons.payments_outlined,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true)),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                  controller: warrantyCtrl,
                  label: 'Warranty Days (optional)',
                  prefixIcon: Icons.verified_outlined,
                  keyboardType: TextInputType.number),
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: saving
                      ? null
                      : () async {
                          final bytes = await captureSignature(ctx);
                          if (bytes != null) {
                            setState(() => sigBytes = bytes);
                          }
                        },
                  icon: Icon(
                    sigBytes != null
                        ? Icons.check_circle
                        : Icons.draw_outlined,
                    color: sigBytes != null
                        ? AppColors.success
                        : AppColors.accent,
                  ),
                  label: Text(sigBytes != null
                      ? 'Signature captured — tap to re-sign'
                      : 'Capture customer signature (optional)'),
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                AppInlineBanner(message: error!, type: BannerType.error),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: saving ? null : () => Navigator.of(ctx).pop(),
              child: const Text('Cancel')),
          TextButton(
            onPressed: saving
                ? null
                : () async {
                    final labour = double.tryParse(labourCtrl.text.trim()) ?? 0;
                    if (labour < 0) {
                      setState(() => error = 'Labour price is invalid.');
                      return;
                    }
                    final markupPct =
                        double.tryParse(markupCtrl.text.trim()) ?? 0;
                    // p_parts_markup is keyed by product_id; one % → all parts.
                    final markup = <String, double>{
                      for (final p in detail.parts) p.productId: markupPct,
                    };
                    final paid = paidCtrl.text.trim().isEmpty
                        ? _estimateGrand(detail, labour, taxCtrl, markupPct)
                        : double.tryParse(paidCtrl.text.trim()) ?? 0;
                    setState(() {
                      saving = true;
                      error = null;
                    });
                    // Upload the signature first (if captured); store its path.
                    String? sigPath;
                    if (sigBytes != null) {
                      final (path, upErr) = await ref
                          .read(uploadRepairSignatureUseCaseProvider)
                          .call(detail.job.id, sigBytes!);
                      if (upErr != null) {
                        if (!ctx.mounted) return;
                        setState(() {
                          saving = false;
                          error = upErr.message;
                        });
                        return;
                      }
                      sigPath = path;
                    }
                    final (result, failure) = await ref
                        .read(repairJobsProvider.notifier)
                        .closeJob(
                          repairId: detail.job.id,
                          labourPrice: labour,
                          labourTaxPct:
                              double.tryParse(taxCtrl.text.trim()) ?? 0,
                          partsMarkup: markup,
                          paidAmount: paid,
                          warrantyDays:
                              int.tryParse(warrantyCtrl.text.trim()),
                          signatureUrl: sigPath,
                        );
                    if (!ctx.mounted) return;
                    if (failure != null) {
                      setState(() {
                        saving = false;
                        error = failure.message;
                      });
                      return;
                    }
                    Navigator.of(ctx).pop();
                    _showInvoiced(context, result!);
                  },
            child: saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Close'),
          ),
        ],
      ),
    ),
  );
}

/// Rough grand-total preview used only to default the Paid field to "full".
double _estimateGrand(RepairDetail detail, double labour,
    TextEditingController taxCtrl, double markupPct) {
  final labourTax = labour * (double.tryParse(taxCtrl.text.trim()) ?? 0) / 100;
  final partsSell = detail.parts
      .fold<double>(0, (sum, p) => sum + p.unitCost * (1 + markupPct / 100) * p.qty);
  return labour + labourTax + partsSell;
}

void _showInvoiced(BuildContext context, RepairCloseResult result) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.background,
      title: const Text('Job Delivered'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Invoice ${result.invoiceNumber}',
              style: AppTypography.headline),
          const SizedBox(height: AppSpacing.xs),
          Text('Total ${formatPkr(result.grandTotal)}',
              style: AppTypography.footnote
                  .copyWith(color: AppColors.textMuted)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(ctx).pop();
            context.go('/repair');
          },
          child: const Text('Done'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(ctx).pop();
            context.go('/sales/invoice/${result.invoiceId}');
          },
          child: const Text('View Invoice'),
        ),
      ],
    ),
  );
}
