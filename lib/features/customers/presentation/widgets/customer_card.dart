import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/clay.dart';
import '../../../../core/design/widgets/app_money_text.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../domain/entities/customer.dart';

/// Status label + pill tone for a customer, shared by the list and the detail
/// header so the two never drift.
(String, AppPillTone) customerStatusUi(CustomerStatus status) =>
    switch (status) {
      CustomerStatus.active => ('Active', AppPillTone.success),
      CustomerStatus.inactive => ('Inactive', AppPillTone.neutral),
      CustomerStatus.blacklisted => ('Blacklisted', AppPillTone.danger),
    };

/// Initials for the card avatar — first letter of each of the first two words.
String customerInitials(String name) {
  final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  if (words.isEmpty) return '?';
  return words.take(2).map((w) => w[0].toUpperCase()).join();
}

/// One row of the customers list: initials tile, name + status pill, a contact
/// sub-line, and an inline "amount due" pill when a receivable is outstanding.
class CustomerCard extends StatelessWidget {
  const CustomerCard({
    super.key,
    required this.customer,
    required this.receivable,
    required this.onTap,
    this.isWide = false,
  });

  final Customer customer;

  /// Outstanding receivable, or null when the aging call has not resolved — the
  /// card then shows no due pill rather than claiming the account is clear.
  final double? receivable;

  final VoidCallback onTap;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final (statusLabel, tone) = customerStatusUi(customer.status);
    final sub = customer.email ?? customer.phone ?? 'No contact info';
    final owed = receivable ?? 0;

    return Semantics(
      button: true,
      label: '${customer.name}, $statusLabel',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: ClayContainer(
          variant: ClayVariant.soft,
          color: lum.surface,
          borderRadius: AppRadius.lg,
          isDark: lum.isDark,
          padding: EdgeInsets.symmetric(
            horizontal: isWide ? 18 : 16,
            vertical: isWide ? 16 : 14,
          ),
          child: Row(
            children: [
              // ClayVariant.soft with an explicit accentSoft fill — the lumen
              // variant paints no fill of its own.
              ClayContainer(
                variant: ClayVariant.soft,
                color: lum.accentSoft,
                borderRadius: AppRadius.md,
                isDark: lum.isDark,
                width: 46,
                height: 46,
                child: Center(
                  child: Text(
                    customerInitials(customer.name),
                    style: AppTypography.title2.copyWith(
                      fontSize: 16,
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
                    Text(
                      customer.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.headline.copyWith(
                        fontSize: isWide ? 16 : 15,
                        color: lum.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.footnote.copyWith(color: lum.g500),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        AppPill(label: statusLabel, tone: tone),
                        if (receivable != null && owed > 0)
                          _DuePill(amount: owed),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(LucideIcons.chevronRight, size: 20, color: lum.g400),
            ],
          ),
        ),
      ),
    );
  }
}

/// Inline "amount due" pill in the warning tone, mirroring the design's
/// receivable badge on the list row.
class _DuePill extends StatelessWidget {
  const _DuePill({required this.amount});
  final double amount;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: lum.warningSoft,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppMoneyText(amount, size: 12.5, decimals: 2, color: lum.warningText),
          Text(
            ' due',
            style: AppTypography.caption.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: lum.warningText,
            ),
          ),
        ],
      ),
    );
  }
}
