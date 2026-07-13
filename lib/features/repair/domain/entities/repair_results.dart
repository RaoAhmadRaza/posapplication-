// Typed results from the mutating RPCs (each returns a single jsonb Map).

class RepairCreateResult {
  final String repairId;
  final String jobNumber;
  const RepairCreateResult({required this.repairId, required this.jobNumber});
}

class RepairPartResult {
  final String repairPartId;
  final double unitCost;
  final double totalCost;
  const RepairPartResult({
    required this.repairPartId,
    required this.unitCost,
    required this.totalCost,
  });
}

class RepairCloseResult {
  final String repairId;
  final String invoiceId;
  final String invoiceNumber;
  final double grandTotal;
  const RepairCloseResult({
    required this.repairId,
    required this.invoiceId,
    required this.invoiceNumber,
    required this.grandTotal,
  });
}

/// One failed job from a bulk status change (job id + server error message).
class RepairBulkFailure {
  final String repairId;
  final String error;
  const RepairBulkFailure({required this.repairId, required this.error});
}

/// Result of bulk_change_repair_status: how many succeeded + the per-job failures.
class RepairBulkStatusResult {
  final int succeeded;
  final List<RepairBulkFailure> failed;
  const RepairBulkStatusResult({required this.succeeded, required this.failed});
}

/// A tenant user eligible to be assigned as technician (id + display name).
class Technician {
  final String id;
  final String name;
  const Technician({required this.id, required this.name});
}
