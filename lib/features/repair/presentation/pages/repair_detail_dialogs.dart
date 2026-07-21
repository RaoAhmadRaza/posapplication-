part of 'repair_detail_page.dart';

Future<void> _openStatusSheet(
    BuildContext context, WidgetRef ref, RepairJob job) async {
  final target = await showRepairSheet<RepairStatus>(
    context: context,
    builder: (sheetContext) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const RepairSheetHeader(
          title: 'Move to',
          subtitle: 'Pick the next stage for this job.',
        ),
        for (final s in RepairStatus.values)
          if (s != job.status)
            _SheetOption(
              label: repairStatusLabels[s]!,
              dotColor: repairStatusColor(sheetContext, s),
              onTap: () => Navigator.of(sheetContext).pop(s),
            ),
      ],
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
  final tech = await showRepairSheet<Technician>(
    context: context,
    builder: (sheetContext) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const RepairSheetHeader(title: 'Assign technician'),
        if (techs.isEmpty)
          Text(
            'No users available to assign.',
            style: AppTypography.subhead
                .copyWith(color: sheetContext.lum.g500),
          )
        else
          for (final t in techs)
            _SheetOption(
              label: t.name,
              leading: RepairTechAvatar(name: t.name, size: 26),
              onTap: () => Navigator.of(sheetContext).pop(t),
            ),
      ],
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

/// One tappable row inside a repair sheet (44dp minimum).
class _SheetOption extends StatelessWidget {
  const _SheetOption({
    required this.label,
    required this.onTap,
    this.dotColor,
    this.leading,
  });

  final String label;
  final VoidCallback onTap;
  final Color? dotColor;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Container(
          constraints: const BoxConstraints(minHeight: 46),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: 10),
              ] else if (dotColor != null) ...[
                Container(
                  width: 9,
                  height: 9,
                  decoration:
                      BoxDecoration(color: dotColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.label.copyWith(
                    fontSize: 14.5,
                    color: lum.textPrimary,
                  ),
                ),
              ),
              Icon(LucideIcons.chevronRight, size: 16, color: lum.g400),
            ],
          ),
        ),
      ),
    );
  }
}

// ---- Diagnosis ----

Future<void> _openDiagnosisDialog(
    BuildContext context, WidgetRef ref, RepairJob job) async {
  final diagCtrl = TextEditingController(text: job.diagnosis ?? '');
  final estCtrl = TextEditingController(
      text: job.estimatedCost == null ? '' : job.estimatedCost.toString());
  var approved = job.customerApproved ?? false;

  final saved = await showRepairSheet<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const RepairSheetHeader(title: 'Diagnosis'),
          AppTextField(
            controller: diagCtrl,
            label: 'Diagnosis',
            prefixIcon: LucideIcons.stethoscope,
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: estCtrl,
            label: 'Estimated Cost',
            prefixIcon: LucideIcons.banknote,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: AppCheckbox(
              value: approved,
              label: 'Customer approved',
              onChanged: (v) => setState(() => approved = v),
            ),
          ),
          const SizedBox(height: 18),
          _SheetActions(
            cancelLabel: 'Cancel',
            confirmLabel: 'Save',
            onCancel: () => Navigator.of(ctx).pop(false),
            onConfirm: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    ),
  );
  if (saved != true || !context.mounted) return;
  final failure = await ref.read(repairJobsProvider.notifier).setDiagnosis(
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

/// Cancel / confirm pair sitting at the foot of a repair sheet.
class _SheetActions extends StatelessWidget {
  const _SheetActions({
    required this.cancelLabel,
    required this.confirmLabel,
    required this.onCancel,
    required this.onConfirm,
    this.loading = false,
  });

  final String cancelLabel;
  final String confirmLabel;
  final VoidCallback? onCancel;
  final VoidCallback? onConfirm;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: AppButton(
            label: cancelLabel,
            variant: AppButtonVariant.tinted,
            fullWidth: true,
            onPressed: onCancel,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: AppButton(
            label: confirmLabel,
            fullWidth: true,
            loading: loading,
            onPressed: onConfirm,
          ),
        ),
      ],
    );
  }
}

// ---- Parts ----

Future<void> _openAddPart(
    BuildContext context, WidgetRef ref, String repairId) async {
  final product = await showRepairProductPicker(context);
  if (product == null || !context.mounted) return;
  final qtyCtrl = TextEditingController(text: '1');
  final confirmed = await showRepairSheet<bool>(
    context: context,
    builder: (ctx) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        RepairSheetHeader(title: product.name, subtitle: 'How many?'),
        AppTextField(
          controller: qtyCtrl,
          label: 'Quantity',
          prefixIcon: LucideIcons.hash,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        const SizedBox(height: 18),
        _SheetActions(
          cancelLabel: 'Cancel',
          confirmLabel: 'Add',
          onCancel: () => Navigator.of(ctx).pop(false),
          onConfirm: () => Navigator.of(ctx).pop(true),
        ),
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

/// Label/value row shared by the cost card and the close breakdown.
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
  await showRepairSheet<void>(
    context: context,
    builder: (ctx) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const RepairSheetHeader(title: 'Customer signature'),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            color: ctx.lum.surface2,
            padding: const EdgeInsets.all(10),
            child: Image.network(url, fit: BoxFit.contain),
          ),
        ),
        const SizedBox(height: 18),
        AppButton(
          label: 'Close',
          variant: AppButtonVariant.tinted,
          fullWidth: true,
          onPressed: () => Navigator.of(ctx).pop(),
        ),
      ],
    ),
  );
}

/// Signature capture control shared by the two close sheets.
class _SignatureRow extends StatelessWidget {
  const _SignatureRow({required this.captured, required this.onTap});

  final bool captured;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: AppButton(
        label: captured
            ? 'Signature captured — tap to re-sign'
            : 'Capture customer signature (optional)',
        variant: AppButtonVariant.plain,
        size: AppButtonSize.sm,
        icon: captured ? LucideIcons.circleCheck : LucideIcons.signature,
        onPressed: onTap,
      ),
    );
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

  await showRepairSheet<void>(
    context: context,
    width: 460,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const RepairSheetHeader(
            title: 'Close & invoice',
            subtitle: 'Price the job, then hand the device back.',
          ),
          AppTextField(
            controller: labourCtrl,
            label: 'Labour Price',
            prefixIcon: LucideIcons.banknote,
            onChanged: (_) => setState(() {}),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 10),
          AppTextField(
            controller: taxCtrl,
            label: 'Labour Tax %',
            prefixIcon: LucideIcons.percent,
            onChanged: (_) => setState(() {}),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 10),
          AppTextField(
            controller: markupCtrl,
            label: 'Parts Markup % (all parts)',
            prefixIcon: LucideIcons.percent,
            onChanged: (_) => setState(() {}),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 10),
          AppTextField(
            controller: paidCtrl,
            label: 'Paid Amount (blank = full)',
            prefixIcon: LucideIcons.coins,
            onChanged: (_) => setState(() {}),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 10),
          AppTextField(
            controller: warrantyCtrl,
            label: 'Warranty Days (optional)',
            prefixIcon: LucideIcons.shieldCheck,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 14),
          _CloseBreakdown(
            detail: detail,
            labour: double.tryParse(labourCtrl.text.trim()) ?? 0,
            labourTaxPct: double.tryParse(taxCtrl.text.trim()) ?? 0,
            markupPct: double.tryParse(markupCtrl.text.trim()) ?? 0,
            paidText: paidCtrl.text.trim(),
          ),
          const SizedBox(height: 8),
          _SignatureRow(
            captured: sigBytes != null,
            onTap: saving
                ? null
                : () async {
                    final bytes = await captureSignature(ctx);
                    if (bytes != null) {
                      setState(() => sigBytes = bytes);
                    }
                  },
          ),
          if (error != null) ...[
            const SizedBox(height: 10),
            AppInlineBanner(message: error!, type: BannerType.error),
          ],
          const SizedBox(height: 18),
          _SheetActions(
            cancelLabel: 'Cancel',
            confirmLabel: 'Invoice & close',
            loading: saving,
            onCancel: saving ? null : () => Navigator.of(ctx).pop(),
            onConfirm: saving
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
                    final (result, failure) =
                        await ref.read(repairJobsProvider.notifier).closeJob(
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
  final partsSell = detail.parts.fold<double>(
      0, (sum, p) => sum + p.unitCost * (1 + markupPct / 100) * p.qty);
  return labour + labourTax + partsSell;
}

// ---- Live close breakdown ----

Future<void> _openWarrantyClaimDialog(
    BuildContext context, WidgetRef ref, RepairJob job) async {
  final issueCtrl = TextEditingController();
  String? error;
  var saving = false;

  await showRepairSheet<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          RepairSheetHeader(
            title: 'Warranty claim',
            subtitle: 'Opens a new no-charge repair linked to '
                '${job.jobNumber}. This job moves to Warranty Claim.',
          ),
          AppTextField(
            controller: issueCtrl,
            label: 'Reported issue',
            prefixIcon: LucideIcons.triangleAlert,
          ),
          if (error != null) ...[
            const SizedBox(height: 10),
            AppInlineBanner(message: error!, type: BannerType.error),
          ],
          const SizedBox(height: 18),
          _SheetActions(
            cancelLabel: 'Cancel',
            confirmLabel: 'Open claim',
            loading: saving,
            onCancel: saving ? null : () => Navigator.of(ctx).pop(),
            onConfirm: saving
                ? null
                : () async {
                    final issue = issueCtrl.text.trim();
                    if (issue.isEmpty) {
                      setState(() => error = 'Describe the reported issue.');
                      return;
                    }
                    setState(() {
                      saving = true;
                      error = null;
                    });
                    final (result, failure) = await ref
                        .read(repairJobsProvider.notifier)
                        .openWarrantyClaim(
                            originalRepairId: job.id, reportedIssue: issue);
                    if (!ctx.mounted) return;
                    if (failure != null) {
                      setState(() {
                        saving = false;
                        error = failure.message;
                      });
                      return;
                    }
                    Navigator.of(ctx).pop();
                    context.push('/repair/${result!.claimRepairId}');
                  },
          ),
        ],
      ),
    ),
  );
}

// ---- Warranty claim CLOSE — no charge ----

Future<void> _openWarrantyCloseDialog(
    BuildContext context, WidgetRef ref, RepairDetail detail) async {
  final warrantyCtrl = TextEditingController();
  Uint8List? sigBytes;
  String? error;
  var saving = false;

  await showRepairSheet<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const RepairSheetHeader(title: 'Close (warranty — no charge)'),
          AppInlineBanner(
            message: 'No charge. Parts cost '
                '(${formatPkr(detail.partsCost)}) is booked to warranty '
                'expense — the customer is not invoiced.',
            type: BannerType.info,
          ),
          const SizedBox(height: 14),
          AppTextField(
            controller: warrantyCtrl,
            label: 'Warranty Days (optional)',
            prefixIcon: LucideIcons.shieldCheck,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 8),
          _SignatureRow(
            captured: sigBytes != null,
            onTap: saving
                ? null
                : () async {
                    final bytes = await captureSignature(ctx);
                    if (bytes != null) {
                      setState(() => sigBytes = bytes);
                    }
                  },
          ),
          if (error != null) ...[
            const SizedBox(height: 10),
            AppInlineBanner(message: error!, type: BannerType.error),
          ],
          const SizedBox(height: 18),
          _SheetActions(
            cancelLabel: 'Cancel',
            confirmLabel: 'Close (no charge)',
            loading: saving,
            onCancel: saving ? null : () => Navigator.of(ctx).pop(),
            onConfirm: saving
                ? null
                : () async {
                    setState(() {
                      saving = true;
                      error = null;
                    });
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
                        .closeWarrantyClaim(
                          repairId: detail.job.id,
                          warrantyDays: int.tryParse(warrantyCtrl.text.trim()),
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
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(
                            'Warranty repair delivered — no charge (cost '
                            '${formatPkr(result!.warrantyCost)}).')));
                    context.go('/repair');
                  },
          ),
        ],
      ),
    ),
  );
}

// ---- Invoiced result ----

void _showInvoiced(BuildContext context, RepairCloseResult result) {
  showRepairSheet<void>(
    context: context,
    builder: (ctx) {
      final lum = ctx.lum;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const RepairSheetHeader(title: 'Job delivered'),
          Row(
            children: [
              Icon(LucideIcons.circleCheck, size: 18, color: lum.successText),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Invoice ${result.invoiceNumber}',
                  style: AppTypography.label
                      .copyWith(fontSize: 15, color: lum.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Total',
                  style: AppTypography.subhead
                      .copyWith(fontSize: 13.5, color: lum.g500),
                ),
              ),
              AppMoneyText(result.grandTotal, size: 20),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Done',
                  variant: AppButtonVariant.tinted,
                  fullWidth: true,
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    context.go('/repair');
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppButton(
                  label: 'View invoice',
                  fullWidth: true,
                  icon: LucideIcons.fileText,
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    context.go('/sales/invoice/${result.invoiceId}');
                  },
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
}
