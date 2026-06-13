class Warehouse {
  final String id;
  final String tenantId;
  final String branchId;
  final String name;
  final String code;
  final String? address;
  final String? capacityNotes;
  final bool isActive;
  final bool isDefault;

  const Warehouse({
    required this.id,
    required this.tenantId,
    required this.branchId,
    required this.name,
    required this.code,
    this.address,
    this.capacityNotes,
    required this.isActive,
    required this.isDefault,
  });
}
