import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/resolved_tax_rate.dart';
import '../failures/accounting_failure.dart';
import '../repositories/accounting_repository.dart';
import '../../data/repositories/accounting_repository_impl.dart';

/// Resolves the applicable tax rate at data-entry time (product default / POS line
/// default): product override wins, else the tenant's is_default rule, else 0.
class ResolveTaxRate {
  final AccountingRepository _repo;
  ResolveTaxRate(this._repo);

  Future<(ResolvedTaxRate?, AccountingFailure?)> call({String? productId}) {
    return _repo.resolveTaxRate(productId);
  }
}

final resolveTaxRateUseCaseProvider = Provider<ResolveTaxRate>((ref) {
  return ResolveTaxRate(ref.read(accountingRepositoryProvider));
});
