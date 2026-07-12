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
import '../../domain/entities/account.dart';
import '../../domain/entities/bank_account.dart';
import '../controllers/bank_accounts_controller.dart';
import '../controllers/chart_of_accounts_controller.dart';

class BankAccountFormPage extends ConsumerStatefulWidget {
  const BankAccountFormPage({super.key, this.bankAccountId});

  final String? bankAccountId;

  @override
  ConsumerState<BankAccountFormPage> createState() =>
      _BankAccountFormPageState();
}

class _BankAccountFormPageState extends ConsumerState<BankAccountFormPage> {
  final _accountName = TextEditingController();
  final _bankName = TextEditingController();
  final _accountNumber = TextEditingController();
  final _iban = TextEditingController();
  final _swift = TextEditingController();
  final _currency = TextEditingController(text: 'PKR');
  final _openingBalance = TextEditingController(text: '0');
  String? _chartAccountId;
  bool _isActive = true;

  bool _saving = false;
  bool _seeded = false;
  String? _error;

  bool get _isEditing => widget.bankAccountId != null;

  @override
  void dispose() {
    _accountName.dispose();
    _bankName.dispose();
    _accountNumber.dispose();
    _iban.dispose();
    _swift.dispose();
    _currency.dispose();
    _openingBalance.dispose();
    super.dispose();
  }

  void _seed(BankAccount b) {
    _accountName.text = b.accountName;
    _bankName.text = b.bankName ?? '';
    _accountNumber.text = b.accountNumber ?? '';
    _iban.text = b.iban ?? '';
    _swift.text = b.swiftCode ?? '';
    _currency.text = b.currency ?? 'PKR';
    _openingBalance.text = b.openingBalance.toString();
    _chartAccountId = b.chartAccountId;
    _isActive = b.isActive;
  }

  Future<void> _submit() async {
    final accountName = _accountName.text.trim();
    if (accountName.isEmpty) {
      setState(() => _error = 'Account name is required.');
      return;
    }
    final chartAccountId = _chartAccountId;
    if (chartAccountId == null) {
      setState(() => _error = 'Select a chart account.');
      return;
    }
    final opening = double.tryParse(_openingBalance.text.trim());
    if (opening == null) {
      setState(() => _error = 'Opening balance must be a number.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final notifier = ref.read(bankAccountsProvider.notifier);
    final currency = _currency.text.trim();
    final iban = _iban.text.trim();
    final swift = _swift.text.trim();
    final failure = _isEditing
        ? await notifier.edit(
            widget.bankAccountId!,
            accountName: accountName,
            bankName: _bankName.text.trim(),
            accountNumber: _accountNumber.text.trim(),
            iban: iban.isEmpty ? null : iban,
            swiftCode: swift.isEmpty ? null : swift,
            currency: currency.isEmpty ? 'PKR' : currency,
            openingBalance: opening,
            chartAccountId: chartAccountId,
            isActive: _isActive,
          )
        : await notifier.create(
            accountName: accountName,
            bankName: _bankName.text.trim(),
            accountNumber: _accountNumber.text.trim(),
            iban: iban.isEmpty ? null : iban,
            swiftCode: swift.isEmpty ? null : swift,
            currency: currency.isEmpty ? 'PKR' : currency,
            openingBalance: opening,
            chartAccountId: chartAccountId,
            isActive: _isActive,
          );

    if (!mounted) return;
    if (failure != null) {
      setState(() {
        _saving = false;
        _error = failure.message;
      });
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isEditing ? 'Bank account updated' : 'Bank account added')));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final assets = (ref.watch(chartOfAccountsProvider).value ?? const [])
        .where((a) => a.type == AccountType.asset)
        .toList()
      ..sort((a, b) => a.code.compareTo(b.code));

    if (_isEditing && !_seeded) {
      final existing = (ref.watch(bankAccountsProvider).value ?? const [])
          .where((b) => b.id == widget.bankAccountId)
          .firstOrNull;
      if (existing != null) {
        _seed(existing);
        _seeded = true;
      }
    }

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
        title: Text(_isEditing ? 'Edit Bank Account' : 'New Bank Account',
            style: AppTypography.headline),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenPadding),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpacing.lg),
                    if (_error != null) ...[
                      AppInlineBanner(
                          message: _error!, type: BannerType.error),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    AppTextField(
                      controller: _accountName,
                      label: 'Account Name',
                      prefixIcon: Icons.account_balance,
                    ),
                    const SizedBox(height: AppSpacing.fieldGap),
                    AppTextField(
                      controller: _bankName,
                      label: 'Bank Name',
                      prefixIcon: Icons.business,
                    ),
                    const SizedBox(height: AppSpacing.fieldGap),
                    AppTextField(
                      controller: _accountNumber,
                      label: 'Account Number',
                      prefixIcon: Icons.numbers,
                    ),
                    const SizedBox(height: AppSpacing.fieldGap),
                    AppTextField(
                      controller: _iban,
                      label: 'IBAN',
                      prefixIcon: Icons.tag,
                      hint: 'Optional',
                    ),
                    const SizedBox(height: AppSpacing.fieldGap),
                    AppTextField(
                      controller: _swift,
                      label: 'SWIFT Code',
                      prefixIcon: Icons.swap_horiz,
                      hint: 'Optional',
                    ),
                    const SizedBox(height: AppSpacing.fieldGap),
                    AppTextField(
                      controller: _currency,
                      label: 'Currency',
                      prefixIcon: Icons.attach_money,
                    ),
                    const SizedBox(height: AppSpacing.fieldGap),
                    AppTextField(
                      controller: _openingBalance,
                      label: 'Opening Balance',
                      prefixIcon: Icons.account_balance_wallet,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true, signed: true),
                    ),
                    const SizedBox(height: AppSpacing.fieldGap),
                    _group('Chart Account'),
                    _AccountDropdown(
                      value: _chartAccountId,
                      accounts: assets,
                      onChanged: (v) => setState(() => _chartAccountId = v),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      activeThumbColor: AppColors.accent,
                      title: Text('Active', style: AppTypography.subhead),
                      value: _isActive,
                      onChanged: (v) => setState(() => _isActive = v),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    PermissionGate(
                      module: 'accounting',
                      action: _isEditing ? 'update' : 'create',
                      child: AppButton(
                        label: _isEditing ? 'Update' : 'Create',
                        loading: _saving,
                        fullWidth: true,
                        onPressed: _submit,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _group(String label) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text(label.toUpperCase(),
            style: AppTypography.footnote.copyWith(
                color: AppColors.textMuted, fontWeight: FontWeight.w600)),
      );
}

class _AccountDropdown extends StatelessWidget {
  const _AccountDropdown({
    required this.value,
    required this.accounts,
    required this.onChanged,
  });
  final String? value;
  final List<Account> accounts;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.field),
        border: Border.all(color: AppColors.separator),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          hint: Text('Select account',
              style: AppTypography.subhead
                  .copyWith(color: AppColors.textHint)),
          icon: const Icon(Icons.keyboard_arrow_down,
              size: 18, color: AppColors.textMuted),
          style: AppTypography.subhead,
          onChanged: onChanged,
          items: accounts
              .map((a) => DropdownMenuItem(
                  value: a.id,
                  child: Text('${a.code}  ${a.name}',
                      overflow: TextOverflow.ellipsis)))
              .toList(),
        ),
      ),
    );
  }
}
