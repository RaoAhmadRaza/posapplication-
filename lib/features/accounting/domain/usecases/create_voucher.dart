import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/accounting_results.dart';
import '../entities/voucher.dart';
import '../failures/accounting_failure.dart';
import '../repositories/accounting_repository.dart';
import '../../data/repositories/accounting_repository_impl.dart';

class CreateVoucher {
  final AccountingRepository _repo;
  CreateVoucher(this._repo);

  Future<(VoucherResult?, AccountingFailure?)> call({
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
  }) {
    return _repo.createVoucher(
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
  }
}

final createVoucherUseCaseProvider = Provider<CreateVoucher>((ref) {
  return CreateVoucher(ref.read(accountingRepositoryProvider));
});
