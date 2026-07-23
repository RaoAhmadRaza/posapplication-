import '../../../../core/design/widgets/app_pill.dart';
import '../../domain/entities/purchase_order.dart';
import '../../domain/entities/purchase_invoice.dart';
import '../../domain/entities/purchase_return.dart';

/// Shared status → pill mappings, labels and small formatters for the
/// purchasing module. Mirrors the design's `PO_ST` / `INV_ST` / `RET_ST`
/// tables so every list row, detail header and card reads the same. Kept UI-free
/// of business logic — pure presentation lookups.

(AppPillTone, String) poStatusPill(PurchaseOrderStatus s) => switch (s) {
      PurchaseOrderStatus.draft => (AppPillTone.neutral, 'Draft'),
      PurchaseOrderStatus.submitted => (AppPillTone.warning, 'Submitted'),
      PurchaseOrderStatus.approved => (AppPillTone.lumen, 'Approved'),
      PurchaseOrderStatus.partiallyReceived =>
        (AppPillTone.transit, 'Partially received'),
      PurchaseOrderStatus.received => (AppPillTone.success, 'Received'),
      PurchaseOrderStatus.invoiced => (AppPillTone.transit, 'Invoiced'),
      PurchaseOrderStatus.closed => (AppPillTone.neutral, 'Closed'),
      PurchaseOrderStatus.cancelled => (AppPillTone.danger, 'Cancelled'),
    };

(AppPillTone, String) invoiceStatusPill(PurchaseInvoiceStatus s) => switch (s) {
      PurchaseInvoiceStatus.draft => (AppPillTone.neutral, 'Draft'),
      PurchaseInvoiceStatus.pending => (AppPillTone.warning, 'Pending'),
      PurchaseInvoiceStatus.approved => (AppPillTone.lumen, 'Approved'),
      PurchaseInvoiceStatus.paid => (AppPillTone.success, 'Paid'),
      PurchaseInvoiceStatus.void_ => (AppPillTone.danger, 'Void'),
    };

(AppPillTone, String) returnStatusPill(PurchaseReturnStatus s) => switch (s) {
      PurchaseReturnStatus.draft => (AppPillTone.neutral, 'Draft'),
      PurchaseReturnStatus.confirmed => (AppPillTone.success, 'Confirmed'),
      PurchaseReturnStatus.cancelled => (AppPillTone.danger, 'Cancelled'),
    };

/// ISO short date the design shows everywhere (e.g. `2026-07-21`).
String ymd(DateTime d) => d.toLocal().toIso8601String().substring(0, 10);
