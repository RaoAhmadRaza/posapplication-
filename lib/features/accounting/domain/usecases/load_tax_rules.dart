import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/tax_rule.dart';
import '../failures/accounting_failure.dart';
import '../repositories/accounting_repository.dart';
import '../../data/repositories/accounting_repository_impl.dart';

class LoadTaxRules {
  final AccountingRepository _repo;
  LoadTaxRules(this._repo);

  Future<(List<TaxRule>, AccountingFailure?)> call() {
    return _repo.loadTaxRules();
  }
}

final loadTaxRulesUseCaseProvider = Provider<LoadTaxRules>((ref) {
  return LoadTaxRules(ref.read(accountingRepositoryProvider));
});
