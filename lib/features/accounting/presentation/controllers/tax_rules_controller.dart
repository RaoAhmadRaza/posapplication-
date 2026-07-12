import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/tax_rule.dart';
import '../../domain/failures/accounting_failure.dart';
import '../../domain/usecases/create_tax_rule.dart';
import '../../domain/usecases/load_tax_rules.dart';
import '../../domain/usecases/update_tax_rule.dart';

final taxRulesProvider =
    AsyncNotifierProvider<TaxRulesController, List<TaxRule>>(
      TaxRulesController.new,
    );

class TaxRulesController extends AsyncNotifier<List<TaxRule>> {
  @override
  Future<List<TaxRule>> build() async {
    final (rules, failure) = await ref.read(loadTaxRulesUseCaseProvider).call();
    if (failure != null) throw failure;
    return rules;
  }

  void refresh() => ref.invalidateSelf();

  Future<AccountingFailure?> create({
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
  }) async {
    final (_, failure) = await ref
        .read(createTaxRuleUseCaseProvider)
        .call(
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
    if (failure != null) return failure;
    ref.invalidateSelf();
    return null;
  }

  Future<AccountingFailure?> edit(
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
  }) async {
    final (_, failure) = await ref
        .read(updateTaxRuleUseCaseProvider)
        .call(
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
    if (failure != null) return failure;
    ref.invalidateSelf();
    return null;
  }
}
