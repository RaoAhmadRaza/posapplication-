import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/supabase.dart';

final accountingRemoteDataSourceProvider = Provider<AccountingRemoteDataSource>(
  (ref) {
    return AccountingRemoteDataSource(supabase);
  },
);

class AccountingRemoteDataSource {
  final SupabaseClient _client;

  AccountingRemoteDataSource(this._client);

  // RPC mutations set tenant/audit ids server-side. Direct-CRUD tables
  // (tax_rules / expense_categories / bank_accounts) stamp tenant_id here.
  String? _cachedTenantId;

  Future<String> _tenantId() async {
    if (_cachedTenantId != null) return _cachedTenantId!;
    final data = await _client.from('users').select('tenant_id').single();
    _cachedTenantId = data['tenant_id'] as String;
    return _cachedTenantId!;
  }

  static const _accountCols =
      'id, tenant_id, code, name, type, parent_id,'
      ' description, is_system, is_active, branch_id, opening_balance,'
      ' current_balance, created_at';

  static const _journalCols =
      'id, tenant_id, entry_number, reference_id,'
      ' reference_type, description, period_id, branch_id, is_reversing,'
      ' reversed_entry_id, posted_by, correlation_id, created_at';

  static const _lineCols =
      'id, journal_entry_id, account_id, debit, credit,'
      ' narration, branch_id, created_at';

  static const _voucherCols =
      'id, tenant_id, voucher_number, type,'
      ' journal_entry_id, amount, party_type, party_id, bank_account_id,'
      ' payment_method, reference, description, approved_by, approved_at,'
      ' created_at';

  static const _expenseCols =
      'id, tenant_id, branch_id, category_id,'
      ' expense_number, amount, tax_amount, expense_date, payment_method,'
      ' bank_account_id, reference, description, journal_entry_id, created_at';

  static const _categoryCols =
      'id, tenant_id, name, account_id, parent_id,'
      ' description, is_active, created_at';

  static const _bankCols =
      'id, tenant_id, branch_id, account_name, bank_name,'
      ' account_number, iban, swift_code, currency, opening_balance,'
      ' current_balance, chart_account_id, is_active, created_at';

  static const _taxCols =
      'id, tenant_id, name, code, rate, mode, is_default,'
      ' applies_to, description, is_active, effective_from, effective_until,'
      ' created_at';

  // --- Chart of accounts ---------------------------------------------------

  Future<List<Map<String, dynamic>>> loadChartOfAccounts() async {
    return _client
        .from('accounts')
        .select(_accountCols)
        .isFilter('deleted_at', null)
        .eq('is_active', true)
        .order('code');
  }

  Future<Map<String, dynamic>> accountLedger({
    required String accountId,
    DateTime? from,
    DateTime? to,
  }) async {
    final result = await _client.rpc(
      'account_ledger',
      params: {
        'p_account_id': accountId,
        'p_from': from?.toIso8601String().substring(0, 10),
        'p_to': to?.toIso8601String().substring(0, 10),
      },
    );
    return result as Map<String, dynamic>;
  }

  // --- Journals ------------------------------------------------------------

  Future<Map<String, dynamic>> postJournal({
    required String branchId,
    String? referenceType,
    String? referenceId,
    required String description,
    required List<Map<String, dynamic>> lines,
    DateTime? date,
    String? correlationId,
    bool gate = true,
  }) async {
    final result = await _client.rpc(
      'post_journal',
      params: {
        'p_branch_id': branchId,
        'p_reference_type': referenceType,
        'p_reference_id': referenceId,
        'p_description': description,
        'p_lines': lines,
        'p_date': date?.toIso8601String().substring(0, 10),
        'p_correlation_id': correlationId,
        'p_gate': gate,
      },
    );
    return result as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> reverseJournal({
    required String entryId,
    required String reason,
  }) async {
    final result = await _client.rpc(
      'reverse_journal',
      params: {'p_entry_id': entryId, 'p_reason': reason},
    );
    return result as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> loadJournalEntries({int? limit}) async {
    var q = _client
        .from('journal_entries')
        .select(_journalCols)
        .order('created_at', ascending: false);
    if (limit != null) q = q.limit(limit);
    return q;
  }

  Future<Map<String, dynamic>> loadJournalEntry(String id) async {
    return _client
        .from('journal_entries')
        .select(_journalCols)
        .eq('id', id)
        .single();
  }

  Future<List<Map<String, dynamic>>> loadJournalLines(String entryId) async {
    return _client
        .from('journal_lines')
        .select(_lineCols)
        .eq('journal_entry_id', entryId)
        .order('created_at');
  }

  // --- Vouchers ------------------------------------------------------------

  Future<Map<String, dynamic>> createVoucher({
    required String branchId,
    required String type,
    required double amount,
    String? partyType,
    String? partyId,
    String? bankAccountId,
    String? paymentMethod,
    String? reference,
    required String description,
    required List<Map<String, dynamic>> lines,
    DateTime? date,
  }) async {
    final result = await _client.rpc(
      'create_voucher',
      params: {
        'p_branch_id': branchId,
        'p_type': type,
        'p_amount': amount,
        'p_party_type': partyType,
        'p_party_id': partyId,
        'p_bank_account_id': bankAccountId,
        'p_payment_method': paymentMethod,
        'p_reference': reference,
        'p_description': description,
        'p_lines': lines,
        'p_date': date?.toIso8601String().substring(0, 10),
      },
    );
    return result as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> loadVouchers({String? type}) async {
    var q = _client
        .from('vouchers')
        .select(_voucherCols)
        .isFilter('deleted_at', null);
    if (type != null) q = q.eq('type', type);
    return q.order('created_at', ascending: false);
  }

  // --- Expenses ------------------------------------------------------------

  Future<Map<String, dynamic>> createExpense({
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
    final result = await _client.rpc(
      'create_expense',
      params: {
        'p_branch_id': branchId,
        'p_category_id': categoryId,
        'p_amount': amount,
        'p_tax_amount': taxAmount,
        'p_expense_date': expenseDate.toIso8601String().substring(0, 10),
        'p_payment_method': paymentMethod,
        'p_bank_account_id': bankAccountId,
        'p_reference': reference,
        'p_description': description,
      },
    );
    return result as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> loadExpenses() async {
    return _client
        .from('expenses')
        .select(_expenseCols)
        .isFilter('deleted_at', null)
        .order('expense_date', ascending: false);
  }

  // --- Expense categories (client CRUD) ------------------------------------

  Future<List<Map<String, dynamic>>> loadExpenseCategories() async {
    return _client
        .from('expense_categories')
        .select(_categoryCols)
        .isFilter('deleted_at', null)
        .order('name');
  }

  Future<Map<String, dynamic>> insertExpenseCategory(
    Map<String, dynamic> data,
  ) async {
    final payload = {...data, 'tenant_id': await _tenantId()};
    final list = await _client
        .from('expense_categories')
        .insert(payload)
        .select(_categoryCols);
    return list.first;
  }

  // --- Bank accounts (client CRUD) -----------------------------------------

  Future<List<Map<String, dynamic>>> loadBankAccounts() async {
    return _client
        .from('bank_accounts')
        .select(_bankCols)
        .isFilter('deleted_at', null)
        .order('account_name');
  }

  Future<Map<String, dynamic>> insertBankAccount(
    Map<String, dynamic> data,
  ) async {
    final payload = {...data, 'tenant_id': await _tenantId()};
    final list = await _client
        .from('bank_accounts')
        .insert(payload)
        .select(_bankCols);
    return list.first;
  }

  Future<Map<String, dynamic>> updateBankAccount(
    String id,
    Map<String, dynamic> data,
  ) async {
    final list = await _client
        .from('bank_accounts')
        .update(data)
        .eq('id', id)
        .select(_bankCols);
    return list.first;
  }

  // --- Tax rules (client CRUD) ---------------------------------------------

  Future<List<Map<String, dynamic>>> loadTaxRules() async {
    return _client
        .from('tax_rules')
        .select(_taxCols)
        .isFilter('deleted_at', null)
        .order('name');
  }

  Future<Map<String, dynamic>> insertTaxRule(Map<String, dynamic> data) async {
    final payload = {...data, 'tenant_id': await _tenantId()};
    final list = await _client
        .from('tax_rules')
        .insert(payload)
        .select(_taxCols);
    return list.first;
  }

  Future<Map<String, dynamic>> updateTaxRule(
    String id,
    Map<String, dynamic> data,
  ) async {
    final list = await _client
        .from('tax_rules')
        .update(data)
        .eq('id', id)
        .select(_taxCols);
    return list.first;
  }

  String _day(DateTime d) => d.toIso8601String().substring(0, 10);

  Future<Map<String, dynamic>> trialBalance({
    DateTime? asOf,
    String? branchId,
  }) async {
    final result = await _client.rpc('trial_balance', params: {
      if (asOf != null) 'p_as_of': _day(asOf),
      'p_branch_id': branchId,
    });
    return result as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> profitLoss({
    required DateTime from,
    required DateTime to,
    String? branchId,
  }) async {
    final result = await _client.rpc('profit_loss', params: {
      'p_from': _day(from),
      'p_to': _day(to),
      'p_branch_id': branchId,
    });
    return result as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> balanceSheet({
    DateTime? asOf,
    String? branchId,
  }) async {
    final result = await _client.rpc('balance_sheet', params: {
      if (asOf != null) 'p_as_of': _day(asOf),
      'p_branch_id': branchId,
    });
    return result as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> cashBankBook({
    required String accountCode,
    required DateTime from,
    required DateTime to,
  }) async {
    final result = await _client.rpc('cash_bank_book', params: {
      'p_account_code': accountCode,
      'p_from': _day(from),
      'p_to': _day(to),
    });
    return result as Map<String, dynamic>;
  }
}
