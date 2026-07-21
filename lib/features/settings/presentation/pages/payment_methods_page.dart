import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_detail_scaffold.dart';
import '../../../../core/design/widgets/app_dropdown.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../../../core/design/widgets/app_toggle.dart';
import '../../../auth/presentation/controllers/permission_controller.dart';
import '../../domain/entities/bank_account_ref.dart';
import '../../domain/entities/payment_method_config.dart';
import '../../domain/failures/settings_failure.dart';
import '../controllers/payment_methods_controller.dart';
import '../widgets/settings_note.dart';

/// Friendly label for a resolved GL account code (unlinked methods → Cash 1000).
String _glLabel(String? code) => switch (code) {
      '1000' => 'Cash (1000)',
      '1010' => 'Bank (1010)',
      null => 'Cash (1000)',
      _ => 'GL $code',
    };

/// Sentinel for "no bank linked" — the dropdown reserves null for "unset".
const _noBank = '';

/// Glyph for a method, keyed off its code. Anything unrecognised falls back to
/// a generic wallet rather than guessing at a payment rail.
IconData _methodIcon(String code) {
  final c = code.toUpperCase();
  if (c.contains('CASH')) return LucideIcons.banknote;
  if (c.contains('CARD')) return LucideIcons.creditCard;
  if (c.contains('BANK') || c.contains('TRANSFER')) return LucideIcons.landmark;
  if (c.contains('WALLET') || c.contains('JAZZ') || c.contains('EASYPAISA')) {
    return LucideIcons.smartphone;
  }
  if (c.contains('CREDIT')) return LucideIcons.fileText;
  if (c.contains('CHEQUE') || c.contains('CHECK')) return LucideIcons.fileText;
  return LucideIcons.wallet;
}

class PaymentMethodsPage extends ConsumerWidget {
  const PaymentMethodsPage({super.key});

  Future<void> _run(
    BuildContext context,
    Future<SettingsFailure?> Function() op,
  ) async {
    final failure = await op();
    if (!context.mounted || failure == null) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(failure.message)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final methodsState = ref.watch(paymentMethodsProvider);
    final banksState = ref.watch(bankAccountsProvider);
    final canEdit = ref.watch(permissionMatrixProvider).value?.contains(
              'settings:update',
            ) ??
        false;

    return AppDetailScaffold(
      eyebrow: 'Settings',
      title: 'Payment methods',
      description: 'How customers can pay and where it posts.',
      child: methodsState.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.xxl),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => AppInlineBanner(
          message: e is SettingsFailure ? e.message : e.toString(),
        ),
        data: (methods) {
          final banks = banksState.value ?? const <BankAccountRef>[];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < methods.length; i++) ...[
                if (i > 0) const SizedBox(height: AppSpacing.md),
                _MethodCard(
                  method: methods[i],
                  banks: banks,
                  canEdit: canEdit,
                  onToggleActive: (v) => _run(context,
                      () => ref.read(paymentMethodsProvider.notifier).edit(
                            methods[i].id,
                            isActive: v,
                          )),
                  onToggleRef: (v) => _run(context,
                      () => ref.read(paymentMethodsProvider.notifier).edit(
                            methods[i].id,
                            requiresReference: v,
                          )),
                  onLinkBank: (bankId) => _run(
                      context,
                      () => ref
                          .read(paymentMethodsProvider.notifier)
                          .linkBankAccount(
                            methods[i].id,
                            bankId,
                          )),
                ),
              ],
              const SizedBox(height: AppSpacing.base),
              const SettingsNote(
                "Adding or removing a payment method isn't available from this "
                'screen yet — the methods above are configured for your '
                'business.',
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MethodCard extends StatelessWidget {
  const _MethodCard({
    required this.method,
    required this.banks,
    required this.canEdit,
    required this.onToggleActive,
    required this.onToggleRef,
    required this.onLinkBank,
  });

  final PaymentMethodConfig method;
  final List<BankAccountRef> banks;
  final bool canEdit;
  final ValueChanged<bool> onToggleActive;
  final ValueChanged<bool> onToggleRef;
  final ValueChanged<String?> onLinkBank;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: lum.g100,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(
                  _methodIcon(method.code),
                  size: 22,
                  color: lum.g600,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            method.name,
                            style: AppTypography.headline.copyWith(
                              fontSize: 16,
                              color: lum.textPrimary,
                            ),
                          ),
                        ),
                        if (method.isSystem) ...[
                          const SizedBox(width: 8),
                          const AppPill(label: 'SYSTEM', showDot: false),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    // Resolved GL account — where this method's money posts
                    // today. Only the code exists in the payload, so no
                    // account name is invented alongside it.
                    Text(
                      'Posts to ${_glLabel(method.resolvedAccountCode)}',
                      style: AppTypography.monoValue.copyWith(
                        fontSize: 12.5,
                        color: lum.g500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Divider(height: 33, color: lum.hairline),
          Text(
            'Bank account (GL split)',
            style: AppTypography.fieldLabel.copyWith(color: lum.g700),
          ),
          const SizedBox(height: 8),
          AppDropdown<String>(
            value: method.bankAccountId ?? _noBank,
            enabled: canEdit,
            options: [
              const AppDropdownOption(
                value: _noBank,
                label: 'None — Cash (1000)',
              ),
              for (final b in banks)
                AppDropdownOption(value: b.id, label: b.label),
            ],
            onSelected: (value) => onLinkBank(value == _noBank ? null : value),
          ),
          const SizedBox(height: 14),
          _ToggleRow(
            title: 'Active',
            description: 'Available at the point of sale.',
            value: method.isActive,
            enabled: canEdit,
            onChanged: onToggleActive,
          ),
          const SizedBox(height: 14),
          _ToggleRow(
            title: 'Requires reference',
            description: 'Cashier must enter a txn / cheque number.',
            value: method.requiresReference,
            enabled: canEdit,
            onChanged: onToggleRef,
          ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.title,
    required this.description,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String title;
  final String description;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: AppTypography.body.copyWith(
                  fontWeight: FontWeight.w600,
                  color: lum.textPrimary,
                ),
              ),
              Text(
                description,
                style: AppTypography.caption.copyWith(color: lum.g500),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        AppToggle(
          value: value,
          enabled: enabled,
          semanticLabel: title,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
