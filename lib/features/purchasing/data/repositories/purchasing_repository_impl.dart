import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/purchase_order.dart';
import '../../domain/entities/purchase_order_item.dart';
import '../../domain/entities/grn.dart';
import '../../domain/entities/purchase_invoice.dart';
import '../../domain/entities/supplier_payment.dart';
import '../../domain/entities/purchase_results.dart';
import '../../domain/failures/purchase_failure.dart';
import '../../domain/repositories/purchasing_repository.dart';
import '../datasources/purchase_remote_datasource.dart';
import '../models/purchase_order_model.dart';
import '../models/purchase_order_item_model.dart';
import '../models/grn_model.dart';
import '../models/purchase_invoice_model.dart';
import '../models/supplier_payment_model.dart';
import '../models/purchase_result_models.dart';

final purchasingRepositoryProvider = Provider<PurchasingRepository>((ref) {
  return PurchasingRepositoryImpl(ref.read(purchaseRemoteDataSourceProvider));
});

class PurchasingRepositoryImpl implements PurchasingRepository {
  final PurchaseRemoteDataSource _ds;

  PurchasingRepositoryImpl(this._ds);

  PurchaseFailure _mapError(Object e) {
    if (e is PostgrestException) {
      final msg = e.message.toLowerCase();
      final code = e.code;
      if (msg.contains('err_permission_denied') || code == '42501') {
        return PurchasePermissionDeniedFailure();
      }
      if (msg.contains('err_bad_transition')) {
        return PurchaseBadTransitionFailure();
      }
      if (msg.contains('err_over_receipt')) {
        return PurchaseOverReceiptFailure();
      }
      if (msg.contains('err_overpayment')) return PurchaseOverpaymentFailure();
      if (msg.contains('err_grn_mismatch')) return PurchaseGrnMismatchFailure();
      if (msg.contains('_not_found') ||
          code == 'PGRST116' ||
          code == 'P0002') {
        return PurchaseNotFoundFailure();
      }
    }
    if (e is AuthException) return PurchasePermissionDeniedFailure();
    if (e is SocketException || e is TimeoutException) {
      return PurchaseUnknownFailure(
          'Network error. Please check your connection.');
    }
    return PurchaseUnknownFailure(e.toString());
  }

  @override
  Future<(List<PurchaseOrder>, PurchaseFailure?)> loadPurchaseOrders({
    PurchaseOrderStatus? status,
  }) async {
    try {
      final rows = await _ds.loadPurchaseOrders(
        status: status == null ? null : PurchaseOrderModel.statusToDb(status),
      );
      return (rows.map(PurchaseOrderModel.fromJson).toList(), null);
    } catch (e) {
      return (<PurchaseOrder>[], _mapError(e));
    }
  }

  @override
  Future<(PurchaseOrder?, List<PurchaseOrderItem>, PurchaseFailure?)>
      loadPurchaseOrder(String id) async {
    try {
      final poRow = await _ds.loadPurchaseOrder(id);
      final itemRows = await _ds.loadPurchaseOrderItems(id);
      return (
        PurchaseOrderModel.fromJson(poRow),
        itemRows.map(PurchaseOrderItemModel.fromJson).toList(),
        null,
      );
    } catch (e) {
      return (null, <PurchaseOrderItem>[], _mapError(e));
    }
  }

  @override
  Future<(PoCreateResult?, PurchaseFailure?)> createPurchaseOrder(
      Map<String, dynamic> data) async {
    try {
      final row = await _ds.createPurchaseOrder(data);
      return (PoCreateResultModel.fromJson(row), null);
    } catch (e) {
      return (null, _mapError(e));
    }
  }

  @override
  Future<(PoCreateResult?, PurchaseFailure?)> updatePurchaseOrder(
      String id, Map<String, dynamic> data) async {
    try {
      final row = await _ds.updatePurchaseOrder(id, data);
      return (PoCreateResultModel.fromJson(row), null);
    } catch (e) {
      return (null, _mapError(e));
    }
  }

  @override
  Future<(PoStatusResult?, PurchaseFailure?)> submitPurchaseOrder(
      String id) async {
    try {
      final row = await _ds.submitPurchaseOrder(id);
      return (PoStatusResultModel.fromJson(row), null);
    } catch (e) {
      return (null, _mapError(e));
    }
  }

  @override
  Future<(PoStatusResult?, PurchaseFailure?)> approvePurchaseOrder(
      String id) async {
    try {
      final row = await _ds.approvePurchaseOrder(id);
      return (PoStatusResultModel.fromJson(row), null);
    } catch (e) {
      return (null, _mapError(e));
    }
  }

  @override
  Future<(PoStatusResult?, PurchaseFailure?)> cancelPurchaseOrder(
      String id, String? reason) async {
    try {
      final row = await _ds.cancelPurchaseOrder(id, reason);
      return (PoStatusResultModel.fromJson(row), null);
    } catch (e) {
      return (null, _mapError(e));
    }
  }

  @override
  Future<(List<Grn>, PurchaseFailure?)> loadGrns(String poId) async {
    try {
      final rows = await _ds.loadGrns(poId);
      return (rows.map(GrnModel.fromJson).toList(), null);
    } catch (e) {
      return (<Grn>[], _mapError(e));
    }
  }

  @override
  Future<(ReceiveResult?, PurchaseFailure?)> receiveGoods({
    required String poId,
    String? notes,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      final row =
          await _ds.receiveGoods(poId: poId, notes: notes, items: items);
      return (ReceiveResultModel.fromJson(row), null);
    } catch (e) {
      return (null, _mapError(e));
    }
  }

  @override
  Future<(List<PurchaseInvoice>, PurchaseFailure?)> loadPurchaseInvoices({
    PurchaseInvoiceStatus? status,
    String? poId,
  }) async {
    try {
      final rows = await _ds.loadPurchaseInvoices(
        status:
            status == null ? null : PurchaseInvoiceModel.statusToDb(status),
        poId: poId,
      );
      return (rows.map(PurchaseInvoiceModel.fromJson).toList(), null);
    } catch (e) {
      return (<PurchaseInvoice>[], _mapError(e));
    }
  }

  @override
  Future<(InvoiceCreateResult?, PurchaseFailure?)> createPurchaseInvoice({
    required String poId,
    String? grnId,
    String? supplierInvoiceNumber,
    required double amount,
    required double taxAmount,
    DateTime? dueDate,
    String? notes,
  }) async {
    try {
      final row = await _ds.createPurchaseInvoice(
        poId: poId,
        grnId: grnId,
        supplierInvoiceNumber: supplierInvoiceNumber,
        amount: amount,
        taxAmount: taxAmount,
        dueDate: dueDate,
        notes: notes,
      );
      return (InvoiceCreateResultModel.fromJson(row), null);
    } catch (e) {
      return (null, _mapError(e));
    }
  }

  @override
  Future<(List<SupplierPayment>, PurchaseFailure?)> loadSupplierPayments({
    String? supplierId,
    String? invoiceId,
  }) async {
    try {
      final rows = await _ds.loadSupplierPayments(
        supplierId: supplierId,
        invoiceId: invoiceId,
      );
      return (rows.map(SupplierPaymentModel.fromJson).toList(), null);
    } catch (e) {
      return (<SupplierPayment>[], _mapError(e));
    }
  }

  @override
  Future<(PaymentResult?, PurchaseFailure?)> recordSupplierPayment({
    required String supplierId,
    String? invoiceId,
    required String method,
    required double amount,
    String? reference,
    String? notes,
  }) async {
    try {
      final row = await _ds.recordSupplierPayment(
        supplierId: supplierId,
        invoiceId: invoiceId,
        method: method,
        amount: amount,
        reference: reference,
        notes: notes,
      );
      return (PaymentResultModel.fromJson(row), null);
    } catch (e) {
      return (null, _mapError(e));
    }
  }
}
