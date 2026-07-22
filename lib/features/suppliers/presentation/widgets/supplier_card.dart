import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/clay.dart';
import '../../../../core/design/widgets/app_money_text.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../domain/entities/supplier.dart';

/// Status label + pill tone for a supplier, shared by the list and the detail
/// header so the two never drift.
(String, AppPillTone) supplierStatusUi(SupplierStatus status) =>
    switch (status) {
      SupplierStatus.active => ('Active', AppPillTone.success),
      SupplierStatus.inactive => ('Inactive', AppPillTone.neutral),
      SupplierStatus.blacklisted => ('Blacklisted', AppPillTone.danger),
    };

/// Initials for the card avatar — first letter of each of the first two words.
String supplierInitials(String name) {
  final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  if (words.isEmpty) return '?';
  return words.take(2).map((w) => w[0].toUpperCase()).join();
}

/// One row of the suppliers list: initials tile, name + status, contact line,
/// and the outstanding payable on the right.
class SupplierCard extends StatelessWidget {
  const SupplierCard({
    super.key,
    required this.supplier,
    required this.payable,
    required this.onTap,
    this.isWide = false,
  });

  final Supplier supplier;

  /// Outstanding payable, or null when the aging call has not resolved — the
  /// card then shows nothing rather than claiming the account is settled.
  final double? payable;

  final VoidCallback onTap;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final (statusLabel, tone) = supplierStatusUi(supplier.status);
    final owed = payable ?? 0;

    return Semantics(
      button: true,
      label: '${supplier.name}, $statusLabel',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: ClayContainer(
          variant: ClayVariant.soft,
          color: lum.surface,
          borderRadius: AppRadius.lg,
          isDark: lum.isDark,
          padding: EdgeInsets.symmetric(
            horizontal: isWide ? 20 : 16,
            vertical: isWide ? 18 : 14,
          ),
          child: Row(
            children: [
              // ClayVariant.lumen paints no fill of its own — the accent wash
              // has to be passed explicitly.
              ClayContainer(
                variant: ClayVariant.soft,
                color: lum.accentSoft,
                borderRadius: AppRadius.md,
                isDark: lum.isDark,
                width: 44,
                height: 44,
                child: Center(
                  child: Text(
                    supplierInitials(supplier.name),
                    style: AppTypography.title2.copyWith(
                      fontSize: 17,
                      color: lum.accentPress,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          supplier.name,
                          style: AppTypography.headline.copyWith(
                            fontSize: isWide ? 16 : 15,
                            color: lum.textPrimary,
                          ),
                        ),
                        AppPill(label: statusLabel, tone: tone),
                      ],
                    ),
                    if (supplier.contactPerson != null ||
                        supplier.phone != null) ...[
                      const SizedBox(height: 3),
                      _ContactLine(
                        contact: supplier.contactPerson,
                        phone: supplier.phone,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (payable == null)
                    const SizedBox.shrink()
                  else if (owed > 0) ...[
                    Text(
                      'PAYABLE',
                      style: AppTypography.caption.copyWith(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: lum.g400,
                      ),
                    ),
                    const SizedBox(height: 2),
                    AppMoneyText(owed,
                        size: 14, decimals: 2, color: lum.dangerText),
                  ] else
                    Text(
                      'Settled',
                      style: AppTypography.footnote.copyWith(color: lum.g400),
                    ),
                ],
              ),
              const SizedBox(width: 8),
              Icon(LucideIcons.chevronRight, size: 18, color: lum.g400),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactLine extends StatelessWidget {
  const _ContactLine({this.contact, this.phone});

  final String? contact;
  final String? phone;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Row(
      children: [
        if (contact != null)
          Flexible(
            child: Text(
              contact!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.footnote.copyWith(color: lum.g500),
            ),
          ),
        if (contact != null && phone != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text('·', style: TextStyle(color: lum.g300)),
          ),
        if (phone != null)
          Text(
            phone!,
            style: AppTypography.monoValue
                .copyWith(fontSize: 12.5, color: lum.g500),
          ),
      ],
    );
  }
}
