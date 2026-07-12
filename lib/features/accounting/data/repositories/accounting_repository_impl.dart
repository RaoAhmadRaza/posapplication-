import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/account.dart';
import '../../domain/entities/account_ledger.dart';
import '../../domain/entities/accounting_results.dart';
import '../../domain/entities/bank_account.dart';
import '../../domain/entities/bank_reconciliation.dart';
import '../../domain/entities/expense.dart';
import '../../domain/entities/expense_category.dart';
import '../../domain/entities/financial_reports.dart';
import '../../domain/entities/fiscal_period.dart';
import '../../domain/entities/journal_entry.dart';
import '../../domain/entities/reconciliation_result.dart';
import '../../domain/entities/journal_line.dart';
import '../../domain/entities/tax_rule.dart';
import '../../domain/entities/voucher.dart';
import '../../domain/failures/accounting_failure.dart';
import '../../domain/repositories/accounting_repository.dart';
import '../datasources/accounting_remote_datasource.dart';
import '../models/account_ledger_model.dart';
import '../models/account_model.dart';
import '../models/accounting_result_models.dart';
import '../models/financial_reports_model.dart';
import '../models/fiscal_period_model.dart';
import '../models/reconciliation_result_model.dart';
import '../models/bank_reconciliation_model.dart';
import '../models/bank_account_model.dart';
import '../models/expense_category_model.dart';
import '../models/expense_model.dart';
import '../models/journal_entry_model.dart';
import '../models/journal_line_model.dart';
import '../models/tax_rule_model.dart';
import '../models/voucher_model.dart';

final accountingRepositoryProvider = Provider<AccountingRepository>((ref) {
  return AccountingRepositoryImpl(ref.read(accountingRemoteDataSourceProvider));
});

class AccountingRepositoryImpl implements AccountingRepository {
  final AccountingRemoteDataSource _ds;

  AccountingRepositoryImpl(this._ds);

  AccountingFailure _mapError(Object e) {
    if (e is PostgrestException) {
      final msg = e.message.toLowerCase();
      final code = e.code;
      if (msg.contains('err_permission_denied') || code == '42501') {
        return AccountingPermissionDeniedFailure();
      }
      if (msg.contains('err_journal_unbalanced')) {
        return AccountingUnbalancedFailure();
      }
      if (msg.contains('err_accounting_period_closed') ||
          msg.contains('period closed')) {
        return AccountingPeriodClosedFailure();
      }
      if (msg.contains('err_account_not_found')) {
        return AccountingAccountNotFoundFailure();
      }
      if (msg.contains('err_period_locked')) {
        return AccountingPeriodLockedFailure();
      }
      if (msg.contains('err_period_already_closed')) {
        return AccountingPeriodAlreadyClosedFailure();
      }
      if (msg.contains('err_already_completed')) {
        return AccountingAlreadyCompletedFailure();
      }
      if (msg.contains('_not_found') || code == 'PGRST116') {
        return AccountingNotFoundFailure();
      }
    }
    if (e is AuthException) return AccountingPermissionDeniedFailure();
    if (e is SocketException || e is TimeoutException) {
      return AccountingUnknownFailure(
        'Network error. Please check your connection.',
      );
    }
    return AccountingUnknownFailure(e.toString());
  }

  static String? _dateOnly(DateTime? d) =>
      d?.toIso8601String().substring(0, 10);

  @override
  Future<(List<Account>, AccountingFailure?)> loadChartOfAccounts() async {
    try {
      final rows = await _ds.loadChartOfAccounts();
      return (rows.map(AccountModel.fromJson).toList(), null);
    } catch (e) {
      return (<Account>[], _mapError(e));
    }
  }

  @override
  Future<(AccountLedger?, AccountingFailure?)> loadAccountLedger({
    required String accountId,
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      final row = await _ds.accountLedger(
        accountId: accountId,
        from: from,
        to: to,
      );
      return (AccountLedgerModel.fromJson(row), null);
    } catch (e) {
      return (null, _mapError(e));
    }
  }

  @override
  Future<(PostJournalResult?, AccountingFailure?)> postJournal({
    required String branchId,
    required String description,
    required List<Map<String, dynamic>> lines,
    DateTime? date,
  }) async {
    try {
      final row = await _ds.postJournal(
        branchId: branchId,
        description: description,
        lines: lines,
        date: date,
      );
      return (PostJournalResultModel.fromJson(row), null);
    } catch (e) {
      return (null, _mapError(e));
    }
  }

  @override
  Future<(ReverseJournalResult?, AccountingFailure?)> reverseJournal({
    required String entryId,
    required String reason,
  }) async {
    try {
      final row = await _ds.reverseJournal(entryId: entryId, reason: reason);
      return (ReverseJournalResultModel.fromJson(row), null);
    } catch (e) {
      return (null, _mapError(e));
    }
  }

  @override
  Future<(List<JournalEntry>, AccountingFailure?)> loadJournalEntries({
    int? limit,
  }) async {
    try {
      final rows = await _ds.loadJournalEntries(limit: limit);
      return (rows.map(JournalEntryModel.fromJson).toList(), null);
    } catch (e) {
      return (<JournalEntry>[], _mapError(e));
    }
  }

  @override
  Future<(JournalEntry?, List<JournalLine>, AccountingFailure?)>
  loadJournalEntry(String id) async {
    try {
      final entryRow = await _ds.loadJournalEntry(id);
      final lineRows = await _ds.loadJournalLines(id);
      return (
        JournalEntryModel.fromJson(entryRow),
        lineRows.map(JournalLineModel.fromJson).toList(),
        null,
      );
    } catch (e) {
      return (null, <JournalLine>[], _mapError(e));
    }
  }

  @override
  Future<(VoucherResult?, AccountingFailure?)> createVoucher({
    required String branchId,
    required VoucherType type,
    required double amount,
    EntityType? partyType,
    String? partyId,
    String? bankAccountId,
    String? paymentMethod,
    String? reference,
    required String description,
    required List<Map<String, dynamic>> lines,
    DateTime? date,
  }) async {
    try {
      final row = await _ds.createVoucher(
        branchId: branchId,
        type: VoucherModel.typeToDb(type),
        amount: amount,
        partyType: partyType == null ? null : VoucherModel.partyToDb(partyType),
        partyId: partyId,
        bankAccountId: bankAccountId,
        paymentMethod: paymentMethod,
        reference: reference,
        description: description,
        lines: lines,
        date: date,
      );
      return (VoucherResultModel.fromJson(row), null);
    } catch (e) {
      return (null, _mapError(e));
    }
  }

  @override
  Future<(List<Voucher>, AccountingFailure?)> loadVouchers({
    VoucherType? type,
  }) async {
    try {
      final rows = await _ds.loadVouchers(
        type: type == null ? null : VoucherModel.typeToDb(type),
      );
      return (rows.map(VoucherModel.fromJson).toList(), null);
    } catch (e) {
      return (<Voucher>[], _mapError(e));
    }
  }

  @override
  Future<(ExpenseResult?, AccountingFailure?)> createExpense({
    required String branchId,
    required String categoryId,
    required double amount,
    required double taxAmount,
    required DateTime expenseDate,
    required String paymentMethod,
    String? bankAccountId,
    String? reference,
    required String description,
  }) async {
    try {
      final row = await _ds.createExpense(
        branchId: branchId,
        categoryId: categoryId,
        amount: amount,
        taxAmount: taxAmount,
        expenseDate: expenseDate,
        paymentMethod: paymentMethod,
        bankAccountId: bankAccountId,
        reference: reference,
        description: description,
      );
      return (ExpenseResultModel.fromJson(row), null);
    } catch (e) {
      return (null, _mapError(e));
    }
  }

  @override
  Future<(List<Expense>, AccountingFailure?)> loadExpenses() async {
    try {
      final rows = await _ds.loadExpenses();
      return (rows.map(ExpenseModel.fromJson).toList(), null);
    } catch (e) {
      return (<Expense>[], _mapError(e));
    }
  }

  @override
  Future<(List<ExpenseCategory>, AccountingFailure?)>
  loadExpenseCategories() async {
    try {
      final rows = await _ds.loadExpenseCategories();
      return (rows.map(ExpenseCategoryModel.fromJson).toList(), null);
    } catch (e) {
      return (<ExpenseCategory>[], _mapError(e));
    }
  }

  @override
  Future<(ExpenseCategory?, AccountingFailure?)> createExpenseCategory({
    required String name,
    required String accountId,
    String? parentId,
    String? description,
  }) async {
    try {
      final row = await _ds.insertExpenseCategory({
        'name': name,
        'account_id': accountId,
        'parent_id': parentId,
        'description': description,
      });
      return (ExpenseCategoryModel.fromJson(row), null);
    } catch (e) {
      return (null, _mapError(e));
    }
  }

  @override
  Future<(List<BankAccount>, AccountingFailure?)> loadBankAccounts() async {
    try {
      final rows = await _ds.loadBankAccounts();
      return (rows.map(BankAccountModel.fromJson).toList(), null);
    } catch (e) {
      return (<BankAccount>[], _mapError(e));
    }
  }

  Map<String, dynamic> _bankPayload({
    required String accountName,
    required String bankName,
    required String accountNumber,
    String? iban,
    String? swiftCode,
    String? currency,
    double? openingBalance,
    required String chartAccountId,
    required bool isActive,
  }) {
    return {
      'account_name': accountName,
      'bank_name': bankName,
      'account_number': accountNumber,
      'iban': iban,
      'swift_code': swiftCode,
      'currency': currency,
      'opening_balance': openingBalance,
      'chart_account_id': chartAccountId,
      'is_active': isActive,
    };
  }

  @override
  Future<(BankAccount?, AccountingFailure?)> createBankAccount({
    required String accountName,
    required String bankName,
    required String accountNumber,
    String? iban,
    String? swiftCode,
    String? currency,
    double? openingBalance,
    required String chartAccountId,
    required bool isActive,
  }) async {
    try {
      final row = await _ds.insertBankAccount(
        _bankPayload(
          accountName: accountName,
          bankName: bankName,
          accountNumber: accountNumber,
          iban: iban,
          swiftCode: swiftCode,
          currency: currency,
          openingBalance: openingBalance,
          chartAccountId: chartAccountId,
          isActive: isActive,
        ),
      );
      return (BankAccountModel.fromJson(row), null);
    } catch (e) {
      return (null, _mapError(e));
    }
  }

  @override
  Future<(BankAccount?, AccountingFailure?)> updateBankAccount(
    String id, {
    required String accountName,
    required String bankName,
    required String accountNumber,
    String? iban,
    String? swiftCode,
    String? currency,
    double? openingBalance,
    required String chartAccountId,
    required bool isActive,
  }) async {
    try {
      final row = await _ds.updateBankAccount(
        id,
        _bankPayload(
          accountName: accountName,
          bankName: bankName,
          accountNumber: accountNumber,
          iban: iban,
          swiftCode: swiftCode,
          currency: currency,
          openingBalance: openingBalance,
          chartAccountId: chartAccountId,
          isActive: isActive,
        ),
      );
      return (BankAccountModel.fromJson(row), null);
    } catch (e) {
      return (null, _mapError(e));
    }
  }

  @override
  Future<(List<TaxRule>, AccountingFailure?)> loadTaxRules() async {
    try {
      final rows = await _ds.loadTaxRules();
      return (rows.map(TaxRuleModel.fromJson).toList(), null);
    } catch (e) {
      return (<TaxRule>[], _mapError(e));
    }
  }

  Map<String, dynamic> _taxPayload({
    required String name,
    required String code,
    required double rate,
    required TaxMode mode,
    required bool isDefault,
    required String appliesTo,
    String? description,
    required bool isActive,
    DateTime? effectiveFrom,
    DateTime? effectiveUntil,
  }) {
    return {
      'name': name,
      'code': code,
      'rate': rate,
      'mode': TaxRuleModel.modeToDb(mode),
      'is_default': isDefault,
      'applies_to': appliesTo,
      'description': description,
      'is_active': isActive,
      'effective_from': _dateOnly(effectiveFrom),
      'effective_until': _dateOnly(effectiveUntil),
    };
  }

  @override
  Future<(TaxRule?, AccountingFailure?)> createTaxRule({
    required String name,
    required String code,
    required double rate,
    required TaxMode mode,
    required bool isDefault,
    required String appliesTo,
    String? description,
    required bool isActive,
    DateTime? effectiveFrom,
    DateTime? effectiveUntil,
  }) async {
    try {
      final row = await _ds.insertTaxRule(
        _taxPayload(
          name: name,
          code: code,
          rate: rate,
          mode: mode,
          isDefault: isDefault,
          appliesTo: appliesTo,
          description: description,
          isActive: isActive,
          effectiveFrom: effectiveFrom,
          effectiveUntil: effectiveUntil,
        ),
      );
      return (TaxRuleModel.fromJson(row), null);
    } catch (e) {
      return (null, _mapError(e));
    }
  }

  @override
  Future<(TaxRule?, AccountingFailure?)> updateTaxRule(
    String id, {
    required String name,
    required String code,
    required double rate,
    required TaxMode mode,
    required bool isDefault,
    required String appliesTo,
    String? description,
    required bool isActive,
    DateTime? effectiveFrom,
    DateTime? effectiveUntil,
  }) async {
    try {
      final row = await _ds.updateTaxRule(
        id,
        _taxPayload(
          name: name,
          code: code,
          rate: rate,
          mode: mode,
          isDefault: isDefault,
          appliesTo: appliesTo,
          description: description,
          isActive: isActive,
          effectiveFrom: effectiveFrom,
          effectiveUntil: effectiveUntil,
        ),
      );
      return (TaxRuleModel.fromJson(row), null);
    } catch (e) {
      return (null, _mapError(e));
    }
  }

  @override
  Future<(TrialBalance?, AccountingFailure?)> loadTrialBalance({
    DateTime? asOf,
    String? branchId,
  }) async {
    try {
      final row = await _ds.trialBalance(asOf: asOf, branchId: branchId);
      return (FinancialReportsModel.trialBalance(row), null);
    } catch (e) {
      return (null, _mapError(e));
    }
  }

  @override
  Future<(ProfitLoss?, AccountingFailure?)> loadProfitLoss({
    required DateTime from,
    required DateTime to,
    String? branchId,
  }) async {
    try {
      final row =
          await _ds.profitLoss(from: from, to: to, branchId: branchId);
      return (FinancialReportsModel.profitLoss(row), null);
    } catch (e) {
      return (null, _mapError(e));
    }
  }

  @override
  Future<(BalanceSheet?, AccountingFailure?)> loadBalanceSheet({
    DateTime? asOf,
    String? branchId,
  }) async {
    try {
      final row = await _ds.balanceSheet(asOf: asOf, branchId: branchId);
      return (FinancialReportsModel.balanceSheet(row), null);
    } catch (e) {
      return (null, _mapError(e));
    }
  }

  @override
  Future<(AccountLedger?, AccountingFailure?)> loadCashBankBook({
    required String accountCode,
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final row = await _ds.cashBankBook(
          accountCode: accountCode, from: from, to: to);
      return (AccountLedgerModel.fromJson(row), null);
    } catch (e) {
      return (null, _mapError(e));
    }
  }

  @override
  Future<(List<FiscalPeriod>, AccountingFailure?)> loadFiscalPeriods() async {
    try {
      final rows = await _ds.loadFiscalPeriods();
      return (rows.map(FiscalPeriodModel.fromJson).toList(), null);
    } catch (e) {
      return (<FiscalPeriod>[], _mapError(e));
    }
  }

  @override
  Future<(bool, AccountingFailure?)> closeFiscalPeriod(String id) async {
    try {
      await _ds.closeFiscalPeriod(id);
      return (true, null);
    } catch (e) {
      return (false, _mapError(e));
    }
  }

  @override
  Future<(bool, AccountingFailure?)> reopenFiscalPeriod(String id) async {
    try {
      await _ds.reopenFiscalPeriod(id);
      return (true, null);
    } catch (e) {
      return (false, _mapError(e));
    }
  }

  @override
  Future<(List<BankReconciliation>, AccountingFailure?)>
  loadBankReconciliations(String bankAccountId) async {
    try {
      final rows = await _ds.loadBankReconciliations(bankAccountId);
      return (rows.map(BankReconciliationModel.fromJson).toList(), null);
    } catch (e) {
      return (<BankReconciliation>[], _mapError(e));
    }
  }

  @override
  Future<(ReconciliationResult?, AccountingFailure?)> createBankReconciliation({
    required String bankAccountId,
    required DateTime statementDate,
    required double statementBalance,
    String? notes,
  }) async {
    try {
      final row = await _ds.createBankReconciliation(
        bankAccountId: bankAccountId,
        statementDate: statementDate,
        statementBalance: statementBalance,
        notes: notes,
      );
      return (ReconciliationResultModel.fromJson(row), null);
    } catch (e) {
      return (null, _mapError(e));
    }
  }

  @override
  Future<(bool, AccountingFailure?)> completeBankReconciliation({
    required String reconciliationId,
    required double reconciledBalance,
    String? notes,
  }) async {
    try {
      await _ds.completeBankReconciliation(
        reconciliationId: reconciliationId,
        reconciledBalance: reconciledBalance,
        notes: notes,
      );
      return (true, null);
    } catch (e) {
      return (false, _mapError(e));
    }
  }
}
