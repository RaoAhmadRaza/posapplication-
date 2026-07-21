part of 'repair_detail_page.dart';

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final isWide = ModuleScaffold.isWideOf(context);
    return AppCard(
      padding: EdgeInsets.all(isWide ? _kCardPadWide : _kCardPadNarrow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.title3.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: lum.textPrimary,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

// ---- Header ----

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.job, required this.techNames});
  final RepairJob job;
  final Map<String, String> techNames;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final isWide = ModuleScaffold.isWideOf(context);
    final model = [job.deviceBrand, job.deviceModel]
        .where((e) => e != null && e.isNotEmpty)
        .join(' ');
    final device = model.isEmpty ? job.deviceType : '${job.deviceType} · $model';
    final techName = job.technicianId == null
        ? null
        : (techNames[job.technicianId] ?? 'Assigned');

    final identity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            RepairStatusBadge(status: job.status),
            RepairPriorityChip(priority: job.priority, suffix: ' priority'),
            if (job.isWarrantyClaim)
              const AppPill(
                label: 'Warranty',
                tone: AppPillTone.transit,
                showDot: false,
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          device,
          style: AppTypography.title1.copyWith(
            fontSize: isWide ? 25 : 21,
            fontWeight: FontWeight.w700,
            letterSpacing: (isWide ? 25 : 21) * -0.02,
            color: lum.textPrimary,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          job.customerName ?? 'Walk-in customer',
          style: AppTypography.subhead.copyWith(fontSize: 14, color: lum.g600),
        ),
        const SizedBox(height: 5),
        Text(
          'IMEI ${job.imei ?? '—'}',
          style: AppTypography.monoValue.copyWith(
            fontSize: 12.5,
            color: lum.g500,
          ),
        ),
        if (job.serialNo != null)
          Text(
            'SERIAL ${job.serialNo}',
            style: AppTypography.monoValue.copyWith(
              fontSize: 12.5,
              color: lum.g500,
            ),
          ),
      ],
    );

    final estimate = Column(
      crossAxisAlignment:
          isWide ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Estimate',
          style: AppTypography.caption.copyWith(fontSize: 12, color: lum.g500),
        ),
        const SizedBox(height: 3),
        if (job.estimatedCost != null)
          AppMoneyText(job.estimatedCost!, size: 22)
        else
          Text(
            '—',
            style: AppTypography.monoValue
                .copyWith(fontSize: 22, color: lum.g400),
          ),
      ],
    );

    return AppCard(
      padding: EdgeInsets.all(isWide ? _kCardPadWide : _kCardPadNarrow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(job.jobNumber, style: _jobNumberStyle(lum))),
              _PrintLabelButton(job: job),
            ],
          ),
          const SizedBox(height: 10),
          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: identity),
                const SizedBox(width: 16),
                estimate,
              ],
            )
          else ...[
            identity,
            const SizedBox(height: 14),
            estimate,
          ],
          const SizedBox(height: 14),
          Divider(height: 1, thickness: 1, color: lum.hairline),
          const SizedBox(height: 12),
          Row(
            children: [
              RepairTechAvatar(name: techName, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  techName ?? 'Unassigned',
                  style: AppTypography.footnote.copyWith(color: lum.g600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Reported issue',
            style: AppTypography.caption.copyWith(fontSize: 12, color: lum.g500),
          ),
          const SizedBox(height: 3),
          Text(
            job.reportedIssue,
            style: AppTypography.body.copyWith(
              fontSize: 14,
              height: 1.55,
              color: lum.g700,
            ),
          ),
        ],
      ),
    );
  }

  static TextStyle _jobNumberStyle(LumColors lum) =>
      AppTypography.monoValue.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: lum.g500,
      );
}

class _PrintLabelButton extends StatelessWidget {
  const _PrintLabelButton({required this.job});
  final RepairJob job;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Print device label',
      child: IconButton(
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        tooltip: 'Print device label',
        icon: Icon(LucideIcons.qrCode, size: 20, color: context.lum.accent),
        onPressed: () => Printing.layoutPdf(
          onLayout: (_) => RepairLabelPdfService().generate(job),
        ),
      ),
    );
  }
}

// ---- Actions (status + assign + close) ----

class _ClosedStrip extends StatelessWidget {
  const _ClosedStrip({required this.job});
  final RepairJob job;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final cancelled = job.status == RepairStatus.cancelled;
    final warranty = job.isWarrantyClaim && job.invoiceId == null;

    final (Color bg, Color fg, IconData icon, String label) = cancelled
        ? (lum.dangerSoft, lum.dangerText, LucideIcons.x, 'Job cancelled')
        : warranty
            ? (
                lum.successSoft,
                lum.successText,
                LucideIcons.shieldCheck,
                'Closed as warranty — no charge',
              )
            : (
                lum.successSoft,
                lum.successText,
                LucideIcons.circleCheck,
                job.invoiceId != null
                    ? 'Delivered & invoiced'
                    : 'Delivered',
              );

    return Semantics(
      label: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            Icon(icon, size: 17, color: fg),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                label,
                style: AppTypography.label.copyWith(fontSize: 13.5, color: fg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiagnosisCard extends ConsumerWidget {
  const _DiagnosisCard({required this.job});
  final RepairJob job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lum = context.lum;
    final hasDiagnosis = job.diagnosis != null && job.diagnosis!.isNotEmpty;

    return _SectionCard(
      title: 'Diagnosis',
      trailing: PermissionGate(
        module: 'repair',
        action: 'update',
        child: AppButton(
          label: job.diagnosis == null ? 'Add' : 'Edit',
          variant: AppButtonVariant.plain,
          size: AppButtonSize.sm,
          icon: job.diagnosis == null ? LucideIcons.plus : LucideIcons.penLine,
          onPressed: () => _openDiagnosisDialog(context, ref, job),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            hasDiagnosis
                ? job.diagnosis!
                : 'No diagnosis yet — add findings once the device has been '
                    'inspected.',
            style: AppTypography.body.copyWith(
              fontSize: 14,
              height: 1.55,
              color: hasDiagnosis ? lum.g700 : lum.g500,
            ),
          ),
          if (hasDiagnosis) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: _IconPill(
                icon: job.customerApproved == true
                    ? LucideIcons.circleCheck
                    : LucideIcons.clock,
                label: job.customerApproved == true
                    ? 'Customer approved'
                    : 'Awaiting customer approval',
                bg: job.customerApproved == true
                    ? lum.successSoft
                    : lum.warningSoft,
                fg: job.customerApproved == true
                    ? lum.successText
                    : lum.warningText,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _IconPill extends StatelessWidget {
  const _IconPill({
    required this.icon,
    required this.label,
    required this.bg,
    required this.fg,
  });

  final IconData icon;
  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

class _PartsCard extends ConsumerWidget {
  const _PartsCard({required this.detail, required this.editable});
  final RepairDetail detail;
  final bool editable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lum = context.lum;
    final parts = detail.parts;

    return _SectionCard(
      title: 'Parts',
      trailing: editable
          ? PermissionGate(
              module: 'repair',
              action: 'update',
              child: AppButton(
                label: 'Add part',
                variant: AppButtonVariant.plain,
                size: AppButtonSize.sm,
                icon: LucideIcons.plus,
                onPressed: () => _openAddPart(context, ref, detail.job.id),
              ),
            )
          : null,
      child: parts.isEmpty
          ? Text(
              'No parts added.',
              style: AppTypography.subhead.copyWith(color: lum.g500),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < parts.length; i++) ...[
                  if (i > 0)
                    Divider(height: 1, thickness: 1, color: lum.hairline),
                  _PartRow(
                    part: parts[i],
                    editable: editable,
                    onRemove: () =>
                        _removePart(context, ref, detail.job.id, parts[i]),
                  ),
                ],
              ],
            ),
    );
  }
}

class _PartRow extends StatelessWidget {
  const _PartRow({
    required this.part,
    required this.editable,
    required this.onRemove,
  });

  final RepairPart part;
  final bool editable;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  part.productName ?? 'Part',
                  style: AppTypography.label.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: lum.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'qty ${part.qty.toStringAsFixed(0)} × '
                  '${formatPkr(part.unitCost)}',
                  style: AppTypography.monoValue.copyWith(
                    fontSize: 11.5,
                    color: lum.g500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          AppMoneyText(part.totalCost, size: 14),
          if (editable)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Semantics(
                button: true,
                label: 'Remove ${part.productName ?? 'part'}',
                child: IconButton(
                  constraints:
                      const BoxConstraints(minWidth: 44, minHeight: 44),
                  tooltip: 'Remove part',
                  icon: Icon(LucideIcons.x, size: 16, color: lum.danger),
                  onPressed: onRemove,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MoneyRow extends StatelessWidget {
  const _MoneyRow({required this.label, required this.value, this.strong = false});

  final String label;
  final double value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: strong
                  ? AppTypography.label
                      .copyWith(fontSize: 13.5, color: lum.textPrimary)
                  : AppTypography.subhead
                      .copyWith(fontSize: 13.5, color: lum.g500),
            ),
          ),
          AppMoneyText(value, size: strong ? 16 : 14),
        ],
      ),
    );
  }
}

/// Parts / Estimate / Final — there is no labour figure on a job, so none is
/// shown here; labour is only entered at close time.
class _CostCard extends StatelessWidget {
  const _CostCard({required this.detail});
  final RepairDetail detail;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final job = detail.job;
    return _SectionCard(
      title: 'Cost summary',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _MoneyRow(label: 'Parts', value: detail.partsCost),
          if (job.estimatedCost != null)
            _MoneyRow(label: 'Estimate', value: job.estimatedCost!),
          if (job.finalCost != null) ...[
            const SizedBox(height: 6),
            Divider(height: 1, thickness: 1, color: lum.hairline),
            const SizedBox(height: 6),
            _MoneyRow(
              label: 'Final (invoiced)',
              value: job.finalCost!,
              strong: true,
            ),
          ],
        ],
      ),
    );
  }
}

// ---- Warranty actions ----

class _WarrantyCard extends ConsumerWidget {
  const _WarrantyCard({required this.detail});
  final RepairDetail detail;

  RepairJob get job => detail.job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lum = context.lum;
    // Claims can only be raised on a DELIVERED job still inside its warranty;
    // a warranty claim itself closes with no charge once it is READY.
    final canClaim = job.status == RepairStatus.delivered &&
        _inWarranty(job.warrantyExpiresAt);
    final canCloseFree =
        job.status == RepairStatus.ready && job.isWarrantyClaim;

    return _SectionCard(
      title: 'Warranty',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            job.warrantyExpiresAt == null
                ? 'No warranty recorded for this job yet.'
                : 'Covered until ${_fmtDay(job.warrantyExpiresAt!)}. A claim '
                    'opens a linked no-charge repair.',
            style: AppTypography.body.copyWith(
              fontSize: 14,
              height: 1.55,
              color: lum.g700,
            ),
          ),
          if (canClaim || canCloseFree) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (canClaim)
                  PermissionGate(
                    module: 'repair',
                    action: 'create',
                    child: AppButton(
                      label: 'Open claim',
                      variant: AppButtonVariant.tinted,
                      size: AppButtonSize.sm,
                      icon: LucideIcons.shieldCheck,
                      onPressed: () =>
                          _openWarrantyClaimDialog(context, ref, job),
                    ),
                  ),
                if (canCloseFree)
                  PermissionGate(
                    module: 'repair',
                    action: 'update',
                    child: AppButton(
                      label: 'Close (no charge)',
                      variant: AppButtonVariant.tinted,
                      size: AppButtonSize.sm,
                      icon: LucideIcons.badgeCheck,
                      onPressed: () =>
                          _openWarrantyCloseDialog(context, ref, detail),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _fmtDay(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }
}

/// True when a delivered job is still under warranty (expiry date >= today).
bool _inWarranty(DateTime? expiry) {
  if (expiry == null) return false;
  final now = DateTime.now();
  return !expiry.isBefore(DateTime(now.year, now.month, now.day));
}

// ---- Warranty linkage ----

class _WarrantyLinkCard extends StatelessWidget {
  const _WarrantyLinkCard({required this.detail});
  final RepairDetail detail;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Linked jobs',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (detail.original != null)
            _linkTile(context, 'Warranty claim of', detail.original!),
          for (final c in detail.claims)
            _linkTile(context, 'Warranty claim', c),
        ],
      ),
    );
  }

  Widget _linkTile(BuildContext context, String label, RepairLink link) {
    final lum = context.lum;
    return Semantics(
      button: true,
      label: '$label ${link.jobNumber}',
      child: InkWell(
        onTap: () => context.push('/repair/${link.id}'),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            children: [
              Icon(LucideIcons.link, size: 15, color: lum.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$label ${link.jobNumber}',
                  style: AppTypography.footnote.copyWith(color: lum.accent),
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

// ---- History ----

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.history, required this.techNames});
  final List<RepairStatusHistory> history;
  final Map<String, String> techNames;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return _SectionCard(
      title: 'Status history',
      child: history.isEmpty
          ? Text(
              'No status changes yet.',
              style: AppTypography.subhead.copyWith(color: lum.g500),
            )
          : RepairTimeline(
              history: history,
              // changed_by is a user id; resolve it against the technicians we
              // already loaded and show nothing when it is not one of them.
              nameFor: (id) => techNames[id],
              formatAt: _fmtDate,
            ),
    );
  }

  static String _fmtDate(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }
}

// ---- Signature ----

/// Fetches a fresh short-lived signed URL for the stored signature path and
/// renders it (never a public link). Read is gated by the storage RLS policy.
class _CloseBreakdown extends StatelessWidget {
  const _CloseBreakdown({
    required this.detail,
    required this.labour,
    required this.labourTaxPct,
    required this.markupPct,
    required this.paidText,
  });

  final RepairDetail detail;
  final double labour;
  final double labourTaxPct;
  final double markupPct;
  final String paidText;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final partsSell = detail.parts.fold<double>(
        0, (sum, p) => sum + p.unitCost * (1 + markupPct / 100) * p.qty);
    final labourTax = labour * labourTaxPct / 100;
    // Client estimate excludes parts output tax (resolved server-side at close).
    final estTotal = labour + partsSell + labourTax;
    final paid = paidText.isEmpty ? estTotal : (double.tryParse(paidText) ?? 0);
    final balance = estTotal - paid;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: lum.surface2,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _MoneyRow(label: 'Labour', value: labour),
          _MoneyRow(label: 'Parts (with markup)', value: partsSell),
          _MoneyRow(label: 'Labour tax', value: labourTax),
          const SizedBox(height: 6),
          Divider(height: 1, thickness: 1, color: lum.hairline),
          const SizedBox(height: 6),
          _MoneyRow(label: 'Estimated total', value: estTotal, strong: true),
          if (balance > 0.005)
            _MoneyRow(label: 'Balance (to A/R)', value: balance),
          const SizedBox(height: 6),
          Text(
            'Parts output tax is added at close.',
            style: AppTypography.caption.copyWith(fontSize: 12, color: lum.g500),
          ),
        ],
      ),
    );
  }
}

// ---- Warranty claim OPEN ----

