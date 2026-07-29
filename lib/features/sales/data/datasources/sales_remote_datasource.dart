import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/supabase.dart';

final salesRemoteDataSourceProvider = Provider<SalesRemoteDataSource>((ref) {
  return SalesRemoteDataSource(supabase);
});

class SalesRemoteDataSource {
  final SupabaseClient _client;

  SalesRemoteDataSource(this._client);

  String? _cachedTenantId;

  Future<String> _tenantId() async {
    if (_cachedTenantId != null) return _cachedTenantId!;
    final data = await _client.from('users').select('tenant_id').single();
    _cachedTenantId = data['tenant_id'] as String;
    return _cachedTenantId!;
  }

  String? get _userId => _client.auth.currentUser?.id;

  static const _invoiceCols = 'id, tenant_id, branch_id, invoice_number, customer_id,'
      ' cashier_id, session_id, status, sale_type, subtotal, discount_total, tax_total,'
      ' grand_total, paid_amount, balance, change_amount, notes, created_at';

  static const _invoiceItemCols = 'id, invoice_id, product_id, variant_id, imei_id,'
      ' description, qty, unit_price, cost_price, discount_pct, discount_amount,'
      ' tax_pct, tax_amount, line_total, profit, created_at';

  static const _paymentCols = 'id, tenant_id, invoice_id, method, amount,'
      ' reference, bank_account_id, notes, created_at';

  static const _customerCols = 'id, tenant_id, name, phone, phone_secondary, email,'
      ' address_line1, address_line2, city, state, postal_code, country,'
      ' tax_number, group_id, credit_limit, credit_terms, loyalty_points,'
      ' opening_balance, status, tags, notes, created_at';

  static const _sessionCols = 'id, tenant_id, branch_id, cashier_id, device_id,'
      ' opening_float, closing_float, expected_float, cash_variance, total_sales,'
      ' total_returns, total_transactions, status, opened_at, closed_at, closed_by, notes';

  Future<Map<String, dynamic>> openSession({
    required String branchId,
    double openingFloat = 0,
  }) async {
    final result = await _client.rpc('open_cashier_session', params: {
      'p_branch_id': branchId,
      'p_opening_float': openingFloat,
    });
    return result as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> closeSession({
    required String sessionId,
    required double closingFloat,
    String? notes,
  }) async {
    final result = await _client.rpc('close_cashier_session', params: {
      'p_session_id': sessionId,
      'p_closing_float': closingFloat,
      'p_notes': notes,
    });
    return result as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createSale({
    required String branchId,
    String? customerId,
    required List<Map<String, dynamic>> items,
    required List<Map<String, dynamic>> payments,
    String? notes,
    String? sessionId,
  }) async {
    final result = await _client.rpc('create_sale', params: {
      'p_branch_id': branchId,
      'p_customer_id': customerId,
      'p_items': items,
      'p_payments': payments,
      'p_notes': notes,
      'p_session_id': sessionId,
    });
    return result as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> loadInvoices({
    String? branchId,
    String? status,
    String? customerId,
    String? search,
    int limit = 50,
    int offset = 0,
  }) async {
    var query = _client
        .from('invoices')
        .select(_invoiceCols);
    if (branchId != null) query = query.eq('branch_id', branchId);
    if (status != null) query = query.eq('status', status);
    if (customerId != null) query = query.eq('customer_id', customerId);
    final term = search?.trim();
    if (term != null && term.isNotEmpty) {
      query = query.ilike('invoice_number', '%$term%');
    }
    return query.order('created_at', ascending: false).limit(limit).range(offset, offset + limit - 1);
  }

  Future<Map<String, dynamic>> loadInvoiceDetail(String id) async {
    final list = await _client
        .from('invoices')
        // products(name)/customers(name) embedded: invoice_items.description is
        // written only when the caller passes one, so the receipt has no other
        // source for the product name.
        .select('$_invoiceCols, customers(name),'
            ' invoice_items($_invoiceItemCols, products(name)),'
            ' payments($_paymentCols)')
        .eq('id', id);
    if (list.isEmpty) throw PostgrestException(message: 'Invoice not found', code: 'PGRST116');
    return list.first;
  }

  Future<Map<String, dynamic>> loadOpenSession(String branchId) async {
    final session = await _client
        .from('cashier_sessions')
        .select(_sessionCols)
        .eq('branch_id', branchId)
        .eq('cashier_id', _userId!)
        .eq('status', 'OPEN')
        .order('opened_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return session ?? {};
  }

  Future<List<Map<String, dynamic>>> loadCustomers({String? query}) async {
    var q = _client
        .from('customers')
        .select(_customerCols);
    if (query != null && query.isNotEmpty) {
      q = q.or('name.ilike.*$query*,phone.ilike.*$query*');
    }
    return q.order('name').limit(50);
  }

  Future<Map<String, dynamic>> createCustomer(Map<String, dynamic> data) async {
    final payload = {
      ...data,
      'tenant_id': await _tenantId(),
      'created_by': _userId,
      'updated_by': _userId,
    };
    final list = await _client.from('customers').insert(payload).select();
    return list.first;
  }

  Future<Map<String, dynamic>> createSalesReturn({
    required String originalInvoiceId,
    required List<Map<String, dynamic>> items,
    required String reason,
    required List<Map<String, dynamic>> refunds,
  }) async {
    final result = await _client.rpc('create_sales_return', params: {
      'p_original_invoice_id': originalInvoiceId,
      'p_items': items,
      'p_reason': reason,
      'p_refund': refunds,
    });
    return result as Map<String, dynamic>;
  }

  static const _heldSaleCols = 'id, tenant_id, branch_id, session_id, customer_id,'
      ' cart_json, label, created_at';

  Future<Map<String, dynamic>> holdSale({
    required String branchId,
    String? sessionId,
    String? customerId,
    required Map<String, dynamic> cartJson,
    required String label,
  }) async {
    final payload = {
      'branch_id': branchId,
      'session_id': ?sessionId,
      'customer_id': ?customerId,
      'cart_json': cartJson,
      'label': label,
      'created_by': _userId,
    };
    final list = await _client.from('held_sales').insert(payload).select();
    return list.first;
  }

  Future<List<Map<String, dynamic>>> loadHeldSales({String? branchId}) async {
    var query = _client.from('held_sales').select(_heldSaleCols);
    if (branchId != null) query = query.eq('branch_id', branchId);
    return query.order('created_at', ascending: false);
  }

  Future<void> deleteHeldSale(String id) async {
    await _client.from('held_sales').delete().eq('id', id);
  }

  Future<void> voidInvoice({required String invoiceId, required String reason}) async {
    await _client.rpc('void_invoice', params: {
      'p_invoice_id': invoiceId,
      'p_reason': reason,
    });
  }

  Future<Map<String, dynamic>> loadSessionSales(String sessionId) async {
    final result = await _client
        .from('invoices')
        .select('grand_total')
        .eq('session_id', sessionId);
    final total = result.fold<num>(0, (s, r) => s + ((r['grand_total'] as num?) ?? 0));
    final count = result.length;
    // Cash-only, mirrors close_cashier_session's expected_float calc so the
    // live tile matches what closing will actually compute.
    final cashResult = await _client
        .from('payments')
        .select('amount, invoices!inner(session_id)')
        .eq('method', 'CASH')
        .eq('invoices.session_id', sessionId);
    final cash = cashResult.fold<num>(0, (s, r) => s + ((r['amount'] as num?) ?? 0));
    return {
      'total_sales': total.toDouble(),
      'total_transactions': count,
      'total_cash': cash.toDouble(),
    };
  }
}
