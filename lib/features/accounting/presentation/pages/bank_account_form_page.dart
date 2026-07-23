import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_detail_scaffold.dart';
import '../../../../core/design/widgets/app_dropdown.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../../core/design/widgets/app_toast.dart';
import '../../../../core/design/widgets/app_toggle.dart';
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
      setState(() => _saving = false);
      showAppToast(context, failure.message, type: BannerType.error);
      return;
    }
    showAppToast(
      context,
      _isEditing ? 'Bank account updated' : 'Bank account added',
      type: BannerType.success,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
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

    final fields = <Widget>[
      AppTextField(
        controller: _accountName,
        label: 'Account name',
        prefixIcon: LucideIcons.landmark,
      ),
      AppTextField(
        controller: _bankName,
        label: 'Bank name',
        prefixIcon: LucideIcons.building2,
      ),
      AppTextField(
        controller: _accountNumber,
        label: 'Account number',
        prefixIcon: LucideIcons.hash,
      ),
      AppTextField(
        controller: _iban,
        label: 'IBAN',
        prefixIcon: LucideIcons.hash,
        hint: 'Optional',
      ),
      AppTextField(
        controller: _swift,
        label: 'SWIFT',
        prefixIcon: LucideIcons.globe,
        hint: 'Optional',
      ),
      AppTextField(
        controller: _currency,
        label: 'Currency',
        prefixIcon: LucideIcons.coins,
      ),
      AppTextField(
        controller: _openingBalance,
        label: 'Opening balance',
        prefixIcon: LucideIcons.banknote,
        keyboardType: const TextInputType.numberWithOptions(
            decimal: true, signed: true),
      ),
      _LabeledField(
        label: 'Chart account',
        child: AppDropdown<String>(
          value: _chartAccountId,
          placeholder: 'Select account',
          options: [
            for (final a in assets)
              AppDropdownOption(value: a.id, label: '${a.code} · ${a.name}'),
          ],
          onSelected: (v) => setState(() => _chartAccountId = v),
        ),
      ),
    ];

    return AppDetailScaffold(
      eyebrow: 'Accounting',
      title: _isEditing ? 'Edit bank account' : 'New bank account',
      maxContentWidth: 720,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            AppInlineBanner(message: _error!, type: BannerType.error),
            const SizedBox(height: 16),
          ],
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (context, c) => _grid(fields, c.maxWidth < 560),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Active',
                              style: AppTypography.headline.copyWith(
                                  fontSize: 14.5, color: lum.textPrimary)),
                          const SizedBox(height: 2),
                          Text('Show this account in pickers and reports',
                              style: AppTypography.subhead
                                  .copyWith(color: lum.g500)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    AppToggle(
                      value: _isActive,
                      semanticLabel: 'Active',
                      onChanged: (v) => setState(() => _isActive = v),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          PermissionGate(
            module: 'accounting',
            action: _isEditing ? 'update' : 'create',
            child: AppButton(
              label: _isEditing ? 'Update account' : 'Create account',
              icon: LucideIcons.check,
              loading: _saving,
              fullWidth: true,
              onPressed: _submit,
            ),
          ),
        ],
      ),
    );
  }

  /// Lays the fields out as a single column (narrow) or paired two-up rows
  /// (wide), each cell taking an equal half — no hand-picked ratio.
  Widget _grid(List<Widget> fields, bool narrow) {
    const gap = 16.0;
    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < fields.length; i++) ...[
            if (i > 0) const SizedBox(height: gap),
            fields[i],
          ],
        ],
      );
    }
    final rows = <Widget>[];
    for (var i = 0; i < fields.length; i += 2) {
      final left = fields[i];
      final right = i + 1 < fields.length ? fields[i + 1] : null;
      rows.add(Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: left),
          const SizedBox(width: gap),
          Expanded(child: right ?? const SizedBox.shrink()),
        ],
      ));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: gap),
          rows[i],
        ],
      ],
    );
  }
}

/// A field label rendered in the AppTextField label style, stacked over a
/// non-text control (the chart-account dropdown) so it aligns with its
/// neighbours in the grid.
class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Text(label,
              style: AppTypography.fieldLabel.copyWith(color: lum.g700)),
        ),
        child,
      ],
    );
  }
}
