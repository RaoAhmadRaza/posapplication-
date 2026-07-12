import '../entities/account.dart';
import '../entities/account_ledger.dart';
import '../entities/accounting_results.dart';
import '../entities/bank_account.dart';
import '../entities/expense.dart';
import '../entities/expense_category.dart';
import '../entities/financial_reports.dart';
import '../entities/journal_entry.dart';
import '../entities/journal_line.dart';
import '../entities/tax_rule.dart';
import '../entities/voucher.dart';
import '../failures/accounting_failure.dart';

abstract class AccountingRepository {
  Future<(List<Account>, AccountingFailure?)> loadChartOfAccounts();

  Future<(AccountLedger?, AccountingFailure?)> loadAccountLedger({
    required String accountId,
    DateTime? from,
    DateTime? to,
  });

  Future<(PostJournalResult?, AccountingFailure?)> postJournal({
    required String branchId,
    required String description,
    required List<Map<String, dynamic>> lines,
    DateTime? date,
  });

  Future<(ReverseJournalResult?, AccountingFailure?)> reverseJournal({
    required String entryId,
    required String reason,
  });

  Future<(List<JournalEntry>, AccountingFailure?)> loadJournalEntries({
    int? limit,
  });

  Future<(JournalEntry?, List<JournalLine>, AccountingFailure?)>
  loadJournalEntry(String id);

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
  });

  Future<(List<Voucher>, AccountingFailure?)> loadVouchers({VoucherType? type});

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
  });

  Future<(List<Expense>, AccountingFailure?)> loadExpenses();

  Future<(List<ExpenseCategory>, AccountingFailure?)> loadExpenseCategories();

  Future<(ExpenseCategory?, AccountingFailure?)> createExpenseCategory({
    required String name,
    required String accountId,
    String? parentId,
    String? description,
  });

  Future<(List<BankAccount>, AccountingFailure?)> loadBankAccounts();

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
  });

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
  });

  Future<(List<TaxRule>, AccountingFailure?)> loadTaxRules();

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
  });

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
  });

  Future<(TrialBalance?, AccountingFailure?)> loadTrialBalance({
    DateTime? asOf,
    String? branchId,
  });
  Future<(ProfitLoss?, AccountingFailure?)> loadProfitLoss({
    required DateTime from,
    required DateTime to,
    String? branchId,
  });
  Future<(BalanceSheet?, AccountingFailure?)> loadBalanceSheet({
    DateTime? asOf,
    String? branchId,
  });
  Future<(AccountLedger?, AccountingFailure?)> loadCashBankBook({
    required String accountCode,
    required DateTime from,
    required DateTime to,
  });
}
