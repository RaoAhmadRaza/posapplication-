import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../auth/presentation/controllers/permission_controller.dart';
import '../../domain/entities/bank_account_ref.dart';
import '../../domain/entities/payment_method_config.dart';
import '../../domain/failures/settings_failure.dart';
import '../controllers/payment_methods_controller.dart';

/// Friendly label for a resolved GL account code (unlinked methods → Cash 1000).
String _glLabel(String? code) => switch (code) {
      '1000' => 'Cash (1000)',
      '1010' => 'Bank (1010)',
      null => 'Cash (1000)',
      _ => 'GL $code',
    };

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

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        title: Text('Payment methods', style: AppTypography.headline),
      ),
      body: SafeArea(
        child: methodsState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            child: AppInlineBanner(
              message: e is SettingsFailure ? e.message : e.toString(),
            ),
          ),
          data: (methods) {
            final banks = banksState.value ?? const <BankAccountRef>[];
            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              itemCount: methods.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppSpacing.md),
              itemBuilder: (_, i) => _MethodCard(
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
                onLinkBank: (bankId) => _run(context,
                    () => ref.read(paymentMethodsProvider.notifier).linkBankAccount(
                          methods[i].id,
                          bankId,
                        )),
              ),
            );
          },
        ),
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
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(method.name, style: AppTypography.body),
                    const SizedBox(height: 2),
                    Text(method.code, style: AppTypography.subtitleMuted),
                  ],
                ),
              ),
              if (method.isSystem)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.textMuted.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                  ),
                  child: Text('SYSTEM', style: AppTypography.subtitleMuted),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // Resolved GL account — where this method's money posts today.
          Row(
            children: [
              const Icon(Icons.account_balance_outlined,
                  size: 16, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Text('Posts to ${_glLabel(method.resolvedAccountCode)}',
                  style: AppTypography.subtitleMuted),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _BankDropdown(
            banks: banks,
            selectedId: method.bankAccountId,
            enabled: canEdit,
            onChanged: onLinkBank,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeThumbColor: AppColors.accent,
            title: Text('Active', style: AppTypography.body),
            value: method.isActive,
            onChanged: canEdit ? onToggleActive : null,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeThumbColor: AppColors.accent,
            title: Text('Requires reference', style: AppTypography.body),
            value: method.requiresReference,
            onChanged: canEdit ? onToggleRef : null,
          ),
        ],
      ),
    );
  }
}

class _BankDropdown extends StatelessWidget {
  const _BankDropdown({
    required this.banks,
    required this.selectedId,
    required this.enabled,
    required this.onChanged,
  });

  final List<BankAccountRef> banks;
  final String? selectedId;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String?>(
      initialValue: selectedId,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Bank account (GL split)',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.field),
        ),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('None — Cash (1000)')),
        for (final b in banks)
          DropdownMenuItem(value: b.id, child: Text(b.label)),
      ],
      onChanged: enabled ? onChanged : null,
    );
  }
}
