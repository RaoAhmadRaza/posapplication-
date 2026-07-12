import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/voucher.dart';
import '../../domain/failures/accounting_failure.dart';
import '../../domain/usecases/create_voucher.dart';
import '../../domain/usecases/load_vouchers.dart';

final vouchersProvider =
    AsyncNotifierProvider<VouchersController, List<Voucher>>(
      VouchersController.new,
    );

class VouchersController extends AsyncNotifier<List<Voucher>> {
  VoucherType? _type;

  VoucherType? get typeFilter => _type;

  @override
  Future<List<Voucher>> build() async {
    final (vouchers, failure) = await ref
        .read(loadVouchersUseCaseProvider)
        .call(type: _type);
    if (failure != null) throw failure;
    return vouchers;
  }

  Future<void> setType(VoucherType? type) async {
    _type = type;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final (vouchers, failure) = await ref
          .read(loadVouchersUseCaseProvider)
          .call(type: _type);
      if (failure != null) throw failure;
      return vouchers;
    });
  }

  void refresh() => ref.invalidateSelf();
}

final voucherControllerProvider = NotifierProvider<VoucherController, void>(
  VoucherController.new,
);

class VoucherController extends Notifier<void> {
  @override
  void build() {}

  Future<AccountingFailure?> createVoucher({
    required String branchId,
    required VoucherType type,
    required double amount,
    EntityType? partyType,
    String? partyId,
    String? bankAccountId,
    String? paymentMethod,
    String? reference,
    required String description,
    required List<Map<String, dynamic>> lines,
    DateTime? date,
  }) async {
    final (_, failure) = await ref
        .read(createVoucherUseCaseProvider)
        .call(
          branchId: branchId,
          type: type,
          amount: amount,
          partyType: partyType,
          partyId: partyId,
          bankAccountId: bankAccountId,
          paymentMethod: paymentMethod,
          reference: reference,
          description: description,
          lines: lines,
          date: date,
        );
    if (failure != null) return failure;
    ref.invalidate(vouchersProvider);
    return null;
  }
}
