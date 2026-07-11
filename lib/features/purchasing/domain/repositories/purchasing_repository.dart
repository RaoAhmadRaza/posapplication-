import '../entities/purchase_order.dart';
import '../entities/purchase_order_item.dart';
import '../entities/grn.dart';
import '../entities/purchase_invoice.dart';
import '../entities/supplier_payment.dart';
import '../entities/purchase_return.dart';
import '../entities/purchase_return_item.dart';
import '../entities/purchase_results.dart';
import '../failures/purchase_failure.dart';

abstract class PurchasingRepository {
  Future<(List<PurchaseOrder>, PurchaseFailure?)> loadPurchaseOrders({
    PurchaseOrderStatus? status,
  });
  Future<(PurchaseOrder?, List<PurchaseOrderItem>, PurchaseFailure?)>
      loadPurchaseOrder(String id);
  Future<(PoCreateResult?, PurchaseFailure?)> createPurchaseOrder(
      Map<String, dynamic> data);
  Future<(PoCreateResult?, PurchaseFailure?)> updatePurchaseOrder(
      String id, Map<String, dynamic> data);
  Future<(PoStatusResult?, PurchaseFailure?)> submitPurchaseOrder(String id);
  Future<(PoStatusResult?, PurchaseFailure?)> approvePurchaseOrder(String id);
  Future<(PoStatusResult?, PurchaseFailure?)> cancelPurchaseOrder(
      String id, String? reason);
  Future<(List<Grn>, PurchaseFailure?)> loadGrns(String poId);
  Future<(ReceiveResult?, PurchaseFailure?)> receiveGoods({
    required String poId,
    String? notes,
    required List<Map<String, dynamic>> items,
  });
  Future<(List<PurchaseInvoice>, PurchaseFailure?)> loadPurchaseInvoices({
    PurchaseInvoiceStatus? status,
    String? poId,
  });
  Future<(InvoiceCreateResult?, PurchaseFailure?)> createPurchaseInvoice({
    required String poId,
    String? grnId,
    String? supplierInvoiceNumber,
    required double amount,
    required double taxAmount,
    DateTime? dueDate,
    String? notes,
  });
  Future<(List<SupplierPayment>, PurchaseFailure?)> loadSupplierPayments({
    String? supplierId,
    String? invoiceId,
  });
  Future<(PaymentResult?, PurchaseFailure?)> recordSupplierPayment({
    required String supplierId,
    String? invoiceId,
    required String method,
    required double amount,
    String? reference,
    String? notes,
  });
  Future<(List<PurchaseReturn>, PurchaseFailure?)> loadPurchaseReturns({
    PurchaseReturnStatus? status,
    String? supplierId,
    String? poId,
  });
  Future<(PurchaseReturn?, List<PurchaseReturnItem>, PurchaseFailure?)>
      loadPurchaseReturn(String id);

  /// Already-returned qty per po_item across CONFIRMED returns of a PO,
  /// keyed by po_item_id. Bounds the editable return qty in the form.
  Future<(Map<String, double>, PurchaseFailure?)> loadReturnedQtysForPo(
      String poId);
  Future<(ReturnCreateResult?, PurchaseFailure?)> createPurchaseReturn({
    required String branchId,
    required String poId,
    String? grnId,
    String? invoiceId,
    required String reason,
    String? notes,
    required List<Map<String, dynamic>> items,
  });
}
