import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:printing/printing.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/format.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_checkbox.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_money_text.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../../core/widgets/module_scaffold.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../../../core/widgets/signature_pad.dart';
import '../../data/services/repair_label_pdf_service.dart';
import '../../domain/entities/repair_job.dart';
import '../../domain/entities/repair_part.dart';
import '../../domain/entities/repair_results.dart';
import '../../domain/entities/repair_status_history.dart';
import '../../domain/usecases/signature_usecases.dart';
import '../controllers/repair_detail_provider.dart';
import '../controllers/repair_jobs_controller.dart';
import '../widgets/repair_job_card.dart';
import '../widgets/repair_product_picker.dart';
import '../widgets/repair_sheet.dart';
import '../widgets/repair_status_ui.dart';
import '../widgets/repair_timeline.dart';

part 'repair_detail_cards.dart';
part 'repair_detail_dialogs.dart';

/// Body measure + gutters from the design export.
const _kMaxContentWidth = 940.0;
const _kGapWide = 16.0;
const _kGapNarrow = 12.0;
const _kCardPadWide = 22.0;
const _kCardPadNarrow = 16.0;

class RepairDetailPage extends ConsumerWidget {
  const RepairDetailPage({super.key, required this.repairId});
  final String repairId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(repairJobDetailProvider(repairId));
    final techs = ref.watch(techniciansProvider).value ?? const <Technician>[];
    final techNames = {for (final t in techs) t.id: t.name};
    final isWide = ModuleScaffold.isWideOf(context);

    return ModuleScaffold(
      title: 'Repair Job',
      maxContentWidth: _kMaxContentWidth,
      padding: EdgeInsets.fromLTRB(
        isWide ? 28 : 14,
        isWide ? 22 : 14,
        isWide ? 28 : 14,
        isWide ? 28 : 20,
      ),
      leading: Semantics(
        button: true,
        label: 'Back',
        child: IconButton(
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          tooltip: 'Back',
          icon: Icon(LucideIcons.arrowLeft, size: 20, color: context.lum.accent),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const Center(
          child: AppInlineBanner(
            message: 'Unable to load this job.',
            type: BannerType.error,
          ),
        ),
        data: (detail) =>
            _Body(detail: detail, techs: techs, techNames: techNames),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.detail,
    required this.techs,
    required this.techNames,
  });

  final RepairDetail detail;
  final List<Technician> techs;
  final Map<String, String> techNames;

  RepairJob get job => detail.job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWide = ModuleScaffold.isWideOf(context);
    final gap = isWide ? _kGapWide : _kGapNarrow;
    final closed = job.status == RepairStatus.delivered ||
        job.status == RepairStatus.cancelled;

    final left = <Widget>[
      _HeaderCard(job: job, techNames: techNames),
      if (closed)
        _ClosedStrip(job: job)
      else
        _ActionsRow(detail: detail, techs: techs),
      if (job.customerSignatureUrl != null)
        AppButton(
          label: 'View signature',
          variant: AppButtonVariant.tinted,
          size: AppButtonSize.sm,
          icon: LucideIcons.signature,
          onPressed: () =>
              _viewSignature(context, ref, job.customerSignatureUrl!),
        ),
      _DiagnosisCard(job: job),
      _PartsCard(detail: detail, editable: !closed),
    ];

    final right = <Widget>[
      _CostCard(detail: detail),
      _WarrantyCard(detail: detail),
      if (detail.original != null || detail.claims.isNotEmpty)
        _WarrantyLinkCard(detail: detail),
      _HistoryCard(history: detail.history, techNames: techNames),
    ];

    if (!isWide) {
      return ListView(
        children: _spaced([...left, ...right], gap),
      );
    }

    return SingleChildScrollView(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 155,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _spaced(left, gap),
            ),
          ),
          SizedBox(width: gap),
          Expanded(
            flex: 100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _spaced(right, gap),
            ),
          ),
        ],
      ),
    );
  }

  /// Inserts a fixed gap between children without trailing whitespace.
  static List<Widget> _spaced(List<Widget> items, double gap) => [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) SizedBox(height: gap),
          items[i],
        ],
      ];
}

/// Clay card with the design's display-face title and an optional right control.
class _ActionsRow extends ConsumerWidget {
  const _ActionsRow({required this.detail, required this.techs});
  final RepairDetail detail;
  final List<Technician> techs;

  RepairJob get job => detail.job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // READY close: warranty claims close with NO charge (close_warranty_claim);
    // normal jobs go through Close & Invoice. Branch on originalRepairId.
    final canCloseAndInvoice =
        job.status == RepairStatus.ready && !job.isWarrantyClaim;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        if (canCloseAndInvoice)
          PermissionGate(
            module: 'repair',
            action: 'update',
            child: AppButton(
              label: 'Close & invoice',
              icon: LucideIcons.receipt,
              size: AppButtonSize.sm,
              onPressed: () => _openCloseDialog(context, ref, detail),
            ),
          ),
        PermissionGate(
          module: 'repair',
          action: 'update',
          child: AppButton(
            label: 'Change status',
            variant: canCloseAndInvoice
                ? AppButtonVariant.tinted
                : AppButtonVariant.filled,
            size: AppButtonSize.sm,
            onPressed: () => _openStatusSheet(context, ref, job),
          ),
        ),
        PermissionGate(
          module: 'repair',
          action: 'update',
          child: AppButton(
            label: job.technicianId == null ? 'Assign' : 'Reassign',
            variant: AppButtonVariant.tinted,
            size: AppButtonSize.sm,
            icon: LucideIcons.userPlus,
            onPressed: () => _openAssignSheet(context, ref, job, techs),
          ),
        ),
      ],
    );
  }
}

/// Replaces the actions row once the job can no longer move.
