import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/tax_rule.dart';
import '../failures/accounting_failure.dart';
import '../repositories/accounting_repository.dart';
import '../../data/repositories/accounting_repository_impl.dart';

class UpdateTaxRule {
  final AccountingRepository _repo;
  UpdateTaxRule(this._repo);

  Future<(TaxRule?, AccountingFailure?)> call(
    String id, {
    required String name,
    required String code,
    required double rate,
    required TaxMode mode,
    required bool isDefault,
    required String appliesTo,
    String? description,
    required bool isActive,
    DateTime? effectiveFrom,
    DateTime? effectiveUntil,
  }) {
    return _repo.updateTaxRule(
      id,
      name: name,
      code: code,
      rate: rate,
      mode: mode,
      isDefault: isDefault,
      appliesTo: appliesTo,
      description: description,
      isActive: isActive,
      effectiveFrom: effectiveFrom,
      effectiveUntil: effectiveUntil,
    );
  }
}

final updateTaxRuleUseCaseProvider = Provider<UpdateTaxRule>((ref) {
  return UpdateTaxRule(ref.read(accountingRepositoryProvider));
});
