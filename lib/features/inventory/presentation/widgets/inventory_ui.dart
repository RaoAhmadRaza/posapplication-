import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/design/widgets/app_pill.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/stock_transfer_status.dart';
import '../../domain/entities/stock_count_status.dart';
import '../../domain/entities/imei_status.dart';
import '../../domain/entities/adjustment_reason.dart';

/// Shared status -> pill mappings, labels, icons and small formatters for the
/// inventory module. Mirrors the design's `stockStatus` and per-list status
/// tables so every row, card and detail header reads the same. Pure
/// presentation lookups — no business logic, no widgets with state.

/// Stock status for a product row/detail, matching the design's `stockStatus`:
/// service -> neutral "Service"; 0 -> danger; at/under reorder -> warning
/// "Low · N"; otherwise success "In stock · N". A non-service product with an
/// unknown (null) on-hand is shown neutrally rather than claiming a number.
(AppPillTone, String) stockStatusPill(
  double? qtyOnHand,
  int reorderPoint,
  ProductType type,
) {
  if (type == ProductType.service) return (AppPillTone.neutral, 'Service');
  if (qtyOnHand == null) return (AppPillTone.neutral, 'Not tracked');
  final qty = qtyOnHand;
  final n = qtyLabel(qty);
  if (qty <= 0) return (AppPillTone.danger, 'Out of stock');
  if (qty <= reorderPoint) return (AppPillTone.warning, 'Low · $n');
  return (AppPillTone.success, 'In stock · $n');
}

/// Whole quantities render without a decimal; fractional keep up to 2 places.
String qtyLabel(double q) =>
    q == q.roundToDouble() ? q.toInt().toString() : q.toStringAsFixed(2);

String productTypeLabel(ProductType t) => switch (t) {
      ProductType.standard => 'Standard',
      ProductType.serialized => 'Serialized',
      ProductType.service => 'Service',
      ProductType.composite => 'Composite',
    };

(AppPillTone, String) productStatusPill(ProductStatus s) => switch (s) {
      ProductStatus.active => (AppPillTone.success, 'Active'),
      ProductStatus.inactive => (AppPillTone.neutral, 'Inactive'),
      ProductStatus.discontinued => (AppPillTone.danger, 'Discontinued'),
    };

/// Adjustment posted/pending pill. `posted` wins; otherwise it is awaiting
/// approval.
(AppPillTone, String) adjustmentStatusPill({required bool posted}) => posted
    ? (AppPillTone.success, 'Posted')
    : (AppPillTone.warning, 'Pending');

String adjustmentReasonLabel(AdjustmentReason r) => switch (r) {
      AdjustmentReason.damage => 'Damage',
      AdjustmentReason.theft => 'Theft',
      AdjustmentReason.expired => 'Expired',
      AdjustmentReason.recount => 'Recount',
      AdjustmentReason.openingBalance => 'Opening balance',
      AdjustmentReason.writeOff => 'Write-off',
      AdjustmentReason.other => 'Other',
    };

(AppPillTone, String) transferStatusPill(StockTransferStatus s) => switch (s) {
      StockTransferStatus.draft => (AppPillTone.neutral, 'Draft'),
      StockTransferStatus.inTransit => (AppPillTone.transit, 'In transit'),
      StockTransferStatus.partiallyReceived =>
        (AppPillTone.transit, 'Partially received'),
      StockTransferStatus.received => (AppPillTone.success, 'Received'),
      StockTransferStatus.cancelled => (AppPillTone.danger, 'Cancelled'),
    };

(AppPillTone, String) countStatusPill(StockCountStatus s) => switch (s) {
      StockCountStatus.draft => (AppPillTone.lumen, 'Draft'),
      StockCountStatus.inProgress => (AppPillTone.lumen, 'In progress'),
      StockCountStatus.completed => (AppPillTone.success, 'Completed'),
      StockCountStatus.cancelled => (AppPillTone.danger, 'Cancelled'),
    };

(AppPillTone, String) imeiStatusPill(ImeiStatus s) => switch (s) {
      ImeiStatus.available => (AppPillTone.success, 'In stock'),
      ImeiStatus.sold => (AppPillTone.neutral, 'Sold'),
      ImeiStatus.returned => (AppPillTone.warning, 'Returned'),
      ImeiStatus.transferred => (AppPillTone.transit, 'Transferred'),
      ImeiStatus.scrapped => (AppPillTone.danger, 'Scrapped'),
      ImeiStatus.reserved => (AppPillTone.warning, 'Reserved'),
      ImeiStatus.inTransit => (AppPillTone.transit, 'In transit'),
    };

/// The design maps a bespoke icon per category, but the backend Category has no
/// icon field — so every catalog thumbnail uses one generic mark rather than a
/// fabricated per-name mapping.
const IconData kInvItemIcon = LucideIcons.package;

/// ISO short date the design shows everywhere (e.g. `2026-07-21`).
String ymd(DateTime d) => d.toLocal().toIso8601String().substring(0, 10);
