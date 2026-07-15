class PaymentMethodConfig {
  final String id;
  final String code;
  final String name;
  final bool isActive;
  final bool isSystem;
  final bool requiresReference;
  final int sortOrder;
  final String? bankAccountId;

  /// GL account code where this method posts today (from resolve_payment_account).
  /// Null until resolved; '1000' = Cash fallback (unlinked).
  final String? resolvedAccountCode;

  const PaymentMethodConfig({
    required this.id,
    required this.code,
    required this.name,
    required this.isActive,
    required this.isSystem,
    required this.requiresReference,
    required this.sortOrder,
    required this.bankAccountId,
    this.resolvedAccountCode,
  });

  PaymentMethodConfig copyWith({String? resolvedAccountCode}) =>
      PaymentMethodConfig(
        id: id,
        code: code,
        name: name,
        isActive: isActive,
        isSystem: isSystem,
        requiresReference: requiresReference,
        sortOrder: sortOrder,
        bankAccountId: bankAccountId,
        resolvedAccountCode: resolvedAccountCode ?? this.resolvedAccountCode,
      );
}
