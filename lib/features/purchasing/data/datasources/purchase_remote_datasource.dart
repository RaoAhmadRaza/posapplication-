import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/supabase.dart';

final purchaseRemoteDataSourceProvider =
    Provider<PurchaseRemoteDataSource>((ref) {
  return PurchaseRemoteDataSource(supabase);
});

class PurchaseRemoteDataSource {
  final SupabaseClient _client;

  PurchaseRemoteDataSource(this._client);

  // All mutations run through RPCs that set tenant/audit ids server-side, so
  // this datasource needs no tenant_id caching or _userId helper.

  static const _poCols = 'id, tenant_id, branch_id, supplier_id, po_number,'
      ' status, order_date, expected_date, currency, exchange_rate, subtotal,'
      ' tax_total, discount_total, freight_charges, insurance_charges,'
      ' custom_duty, landed_cost, grand_total, notes, approved_at, created_at';

  static const _poItemCols = 'id, po_id, product_id, variant_id, qty_ordered,'
      ' qty_received, unit_cost, unit_cost_base, tax_pct, discount_pct,'
      ' line_total, landed_cost_allocated';

  static const _grnCols = 'id, tenant_id, po_id, grn_number, warehouse_id,'
      ' received_by, received_at, notes';

  static const _invoiceCols = 'id, tenant_id, po_id, grn_id, supplier_id,'
      ' supplier_invoice_number, amount, tax_amount, total_amount,'
      ' paid_amount, balance, status, due_date, notes, created_at';

  static const _paymentCols = 'id, tenant_id, supplier_id, invoice_id, method,'
      ' amount, reference, voucher_number, notes, paid_at';

  Future<List<Map<String, dynamic>>> loadPurchaseOrders({
    String? status,
  }) async {
    var q = _client
        .from('purchase_orders')
        .select(_poCols)
        .isFilter('deleted_at', null);
    if (status != null) {
      q = q.eq('status', status);
    }
    return q.order('created_at', ascending: false);
  }

  Future<Map<String, dynamic>> loadPurchaseOrder(String id) async {
    return _client
        .from('purchase_orders')
        .select(_poCols)
        .eq('id', id)
        .single();
  }

  Future<List<Map<String, dynamic>>> loadPurchaseOrderItems(String poId) async {
    return _client
        .from('purchase_order_items')
        .select(_poItemCols)
        .eq('po_id', poId)
        .order('created_at');
  }

  Future<Map<String, dynamic>> createPurchaseOrder(
      Map<String, dynamic> data) async {
    final result = await _client.rpc('create_purchase_order', params: {
      'p_branch_id': data['p_branch_id'],
      'p_supplier_id': data['p_supplier_id'],
      'p_order_date': data['p_order_date'],
      'p_expected_date': data['p_expected_date'],
      'p_currency': data['p_currency'],
      'p_exchange_rate': data['p_exchange_rate'],
      'p_freight': data['p_freight'],
      'p_insurance': data['p_insurance'],
      'p_custom_duty': data['p_custom_duty'],
      'p_discount_total': data['p_discount_total'],
      'p_notes': data['p_notes'],
      'p_items': data['p_items'],
    });
    return result as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updatePurchaseOrder(
      String id, Map<String, dynamic> data) async {
    final result = await _client.rpc('update_purchase_order', params: {
      'p_po_id': id,
      'p_supplier_id': data['p_supplier_id'],
      'p_expected_date': data['p_expected_date'],
      'p_currency': data['p_currency'],
      'p_exchange_rate': data['p_exchange_rate'],
      'p_freight': data['p_freight'],
      'p_insurance': data['p_insurance'],
      'p_custom_duty': data['p_custom_duty'],
      'p_discount_total': data['p_discount_total'],
      'p_notes': data['p_notes'],
      'p_items': data['p_items'],
    });
    return result as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> submitPurchaseOrder(String id) async {
    final result =
        await _client.rpc('submit_purchase_order', params: {'p_po_id': id});
    return result as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> approvePurchaseOrder(String id) async {
    final result =
        await _client.rpc('approve_purchase_order', params: {'p_po_id': id});
    return result as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> cancelPurchaseOrder(
      String id, String? reason) async {
    final result = await _client.rpc('cancel_purchase_order',
        params: {'p_po_id': id, 'p_reason': reason});
    return result as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> loadGrns(String poId) async {
    return _client
        .from('grns')
        .select(_grnCols)
        .eq('po_id', poId)
        .order('created_at');
  }

  Future<Map<String, dynamic>> receiveGoods({
    required String poId,
    String? notes,
    required List<Map<String, dynamic>> items,
  }) async {
    final result = await _client.rpc('receive_goods', params: {
      'p_po_id': poId,
      'p_notes': notes,
      'p_items': items,
    });
    return result as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> loadPurchaseInvoices({
    String? status,
    String? poId,
  }) async {
    var q = _client
        .from('purchase_invoices')
        .select(_invoiceCols)
        .isFilter('deleted_at', null);
    if (status != null) {
      q = q.eq('status', status);
    }
    if (poId != null) {
      q = q.eq('po_id', poId);
    }
    return q.order('created_at', ascending: false);
  }

  Future<Map<String, dynamic>> createPurchaseInvoice({
    required String poId,
    String? grnId,
    String? supplierInvoiceNumber,
    required double amount,
    required double taxAmount,
    DateTime? dueDate,
    String? notes,
  }) async {
    final result = await _client.rpc('create_purchase_invoice', params: {
      'p_po_id': poId,
      'p_grn_id': grnId,
      'p_supplier_invoice_number': supplierInvoiceNumber,
      'p_amount': amount,
      'p_tax_amount': taxAmount,
      'p_due_date': dueDate?.toIso8601String().substring(0, 10),
      'p_notes': notes,
    });
    return result as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> loadSupplierPayments({
    String? supplierId,
    String? invoiceId,
  }) async {
    var q = _client.from('supplier_payments').select(_paymentCols);
    if (supplierId != null) {
      q = q.eq('supplier_id', supplierId);
    }
    if (invoiceId != null) {
      q = q.eq('invoice_id', invoiceId);
    }
    return q.order('paid_at', ascending: false);
  }

  Future<Map<String, dynamic>> recordSupplierPayment({
    required String supplierId,
    String? invoiceId,
    required String method,
    required double amount,
    String? reference,
    String? notes,
  }) async {
    final result = await _client.rpc('record_supplier_payment', params: {
      'p_supplier_id': supplierId,
      'p_invoice_id': invoiceId,
      'p_method': method,
      'p_amount': amount,
      'p_reference': reference,
      'p_bank_account_id': null,
      'p_notes': notes,
    });
    return result as Map<String, dynamic>;
  }
}
