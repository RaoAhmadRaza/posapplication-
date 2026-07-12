import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/voucher.dart';
import '../failures/accounting_failure.dart';
import '../repositories/accounting_repository.dart';
import '../../data/repositories/accounting_repository_impl.dart';

class LoadVouchers {
  final AccountingRepository _repo;
  LoadVouchers(this._repo);

  Future<(List<Voucher>, AccountingFailure?)> call({VoucherType? type}) {
    return _repo.loadVouchers(type: type);
  }
}

final loadVouchersUseCaseProvider = Provider<LoadVouchers>((ref) {
  return LoadVouchers(ref.read(accountingRepositoryProvider));
});
