import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/customer.dart';
import '../../domain/entities/cashier_session.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/entities/sale_result.dart';
import '../../domain/entities/held_sale.dart';
import '../../domain/failures/sales_failure.dart';
import '../../domain/repositories/sales_repository.dart';
import '../datasources/sales_remote_datasource.dart';
import '../models/customer_model.dart';
import '../models/invoice_model.dart';
import '../models/sale_result_model.dart';
import '../models/held_sale_model.dart';
import '../models/cashier_session_model.dart';

final salesRepositoryProvider = Provider<SalesRepository>((ref) {
  return SalesRepositoryImpl(ref.read(salesRemoteDataSourceProvider));
});

class SalesRepositoryImpl implements SalesRepository {
  final SalesRemoteDataSource _ds;

  SalesRepositoryImpl(this._ds);

  SalesFailure _mapError(Object e) {
    if (e is PostgrestException) {
      final code = e.code;
      final msg = e.message;
      final lower = msg.toLowerCase();
      if (code == 'P0001') {
        if (lower.contains('insufficient_stock') || lower.contains('insufficient stock')) {
          return InsufficientStockFailure();
        }
      }
      if (lower.contains('err_insufficient_stock')) {
        return InsufficientStockFailure();
      }
      if (lower.contains('err_credit_requires_customer')) {
        return CreditRequiresCustomerFailure();
      }
      if (lower.contains('err_no_open_session')) {
        return NoOpenSessionFailure();
      }
      if (lower.contains('err_imei_not_available')) {
        return ImeiNotAvailableFailure();
      }
      if (lower.contains('err_session_already_open')) {
        return SessionAlreadyOpenFailure();
      }
      if (lower.contains('err_session_not_open')) {
        return SessionNotOpenFailure();
      }
      if (lower.contains('err_permission_denied')) {
        return PermissionDeniedFailure();
      }
      if (lower.contains('err_empty_cart')) {
        return EmptyCartFailure();
      }
      if (lower.contains('err_product_not_found')) {
        return ProductNotFoundFailure();
      }
      if (code == '42501') return PermissionDeniedFailure();
      if (code == 'PGRST116' || code == 'P0002') return CustomerNotFoundFailure();
    }
    if (e is AuthException) return PermissionDeniedFailure();
    if (e is SocketException || e is TimeoutException) {
      return UnknownFailure('Network error. Please check your connection.');
    }
    return UnknownFailure(e.toString());
  }

  @override
  Future<(CashierSession?, SalesFailure?)> openSession({
    required String branchId,
    double openingFloat = 0,
  }) async {
    try {
      final result = await _ds.openSession(
        branchId: branchId,
        openingFloat: openingFloat,
      );
      final sessionId = result['session_id'] as String;
      final openedAt = DateTime.tryParse(result['opened_at']?.toString() ?? '');
      final session = CashierSession(
        id: sessionId,
        tenantId: '',
        branchId: branchId,
        cashierId: '',
        openingFloat: openingFloat,
        totalSales: 0,
        totalReturns: 0,
        totalTransactions: 0,
        status: CashierSessionStatus.open,
        openedAt: openedAt ?? DateTime.now(),
      );
      return (session, null);
    } catch (e) {
      return (null, _mapError(e));
    }
  }

  @override
  Future<(Map<String, dynamic>?, SalesFailure?)> closeSession({
    required String sessionId,
    required double closingFloat,
    String? notes,
  }) async {
    try {
      final result = await _ds.closeSession(
        sessionId: sessionId,
        closingFloat: closingFloat,
        notes: notes,
      );
      return (result, null);
    } catch (e) {
      return (null, _mapError(e));
    }
  }

  @override
  Future<(SaleResult?, SalesFailure?)> createSale({
    required String branchId,
    String? customerId,
    required List<Map<String, dynamic>> items,
    required List<Map<String, dynamic>> payments,
    String? notes,
    String? sessionId,
  }) async {
    try {
      final result = await _ds.createSale(
        branchId: branchId,
        customerId: customerId,
        items: items,
        payments: payments,
        notes: notes,
        sessionId: sessionId,
      );
      return (SaleResultModel.fromJson(result), null);
    } catch (e) {
      return (null, _mapError(e));
    }
  }

  @override
  Future<(List<Invoice>, SalesFailure?)> loadInvoices({
    String? branchId,
    String? status,
    String? customerId,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final rows = await _ds.loadInvoices(
        branchId: branchId,
        status: status,
        customerId: customerId,
        limit: limit,
        offset: offset,
      );
      return (rows.map(InvoiceModel.fromJson).toList(), null);
    } catch (e) {
      return (<Invoice>[], _mapError(e));
    }
  }

  @override
  Future<(Map<String, dynamic>?, SalesFailure?)> loadInvoiceDetail(String id) async {
    try {
      final row = await _ds.loadInvoiceDetail(id);
      return (row, null);
    } catch (e) {
      return (null, _mapError(e));
    }
  }

  @override
  Future<(List<Customer>, SalesFailure?)> loadCustomers({String? query}) async {
    try {
      final rows = await _ds.loadCustomers(query: query);
      return (rows.map(CustomerModel.fromJson).toList(), null);
    } catch (e) {
      return (<Customer>[], _mapError(e));
    }
  }

  @override
  Future<(Customer?, SalesFailure?)> createCustomer(Map<String, dynamic> data) async {
    try {
      final row = await _ds.createCustomer(data);
      return (CustomerModel.fromJson(row), null);
    } catch (e) {
      return (null, _mapError(e));
    }
  }

  @override
  Future<(SaleResult?, SalesFailure?)> createSalesReturn({
    required String originalInvoiceId,
    required List<Map<String, dynamic>> items,
    required String reason,
    required List<Map<String, dynamic>> refunds,
  }) async {
    try {
      final result = await _ds.createSalesReturn(
        originalInvoiceId: originalInvoiceId,
        items: items,
        reason: reason,
        refunds: refunds,
      );
      return (SaleResultModel.fromJson(result), null);
    } catch (e) {
      return (null, _mapError(e));
    }
  }

  @override
  Future<(bool, SalesFailure?)> holdSale({
    required String branchId,
    String? sessionId,
    String? customerId,
    required Map<String, dynamic> cartJson,
    required String label,
  }) async {
    try {
      await _ds.holdSale(
        branchId: branchId,
        sessionId: sessionId,
        customerId: customerId,
        cartJson: cartJson,
        label: label,
      );
      return (true, null);
    } catch (e) {
      return (false, _mapError(e));
    }
  }

  @override
  Future<(List<HeldSale>, SalesFailure?)> loadHeldSales({String? branchId}) async {
    try {
      final rows = await _ds.loadHeldSales(branchId: branchId);
      return (rows.map(HeldSaleModel.fromJson).toList(), null);
    } catch (e) {
      return (<HeldSale>[], _mapError(e));
    }
  }

  @override
  Future<(bool, SalesFailure?)> deleteHeldSale(String id) async {
    try {
      await _ds.deleteHeldSale(id);
      return (true, null);
    } catch (e) {
      return (false, _mapError(e));
    }
  }

  @override
  Future<(bool, SalesFailure?)> voidInvoice({
    required String invoiceId,
    required String reason,
  }) async {
    try {
      await _ds.voidInvoice(invoiceId: invoiceId, reason: reason);
      return (true, null);
    } catch (e) {
      return (false, _mapError(e));
    }
  }

  @override
  Future<(CashierSession?, SalesFailure?)> loadOpenSession(String branchId) async {
    try {
      final row = await _ds.loadOpenSession(branchId);
      if (row.isEmpty) return (null, null);
      return (CashierSessionModel.fromJson(row), null);
    } catch (e) {
      return (null, _mapError(e));
    }
  }

  @override
  Future<(Map<String, dynamic>?, SalesFailure?)> loadSessionSales(
      String sessionId) async {
    try {
      final row = await _ds.loadSessionSales(sessionId);
      return (row, null);
    } catch (e) {
      return (null, _mapError(e));
    }
  }
}
