import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/accounting_results.dart';
import '../failures/accounting_failure.dart';
import '../repositories/accounting_repository.dart';
import '../../data/repositories/accounting_repository_impl.dart';

class ReverseJournal {
  final AccountingRepository _repo;
  ReverseJournal(this._repo);

  Future<(ReverseJournalResult?, AccountingFailure?)> call({
    required String entryId,
    required String reason,
  }) {
    return _repo.reverseJournal(entryId: entryId, reason: reason);
  }
}

final reverseJournalUseCaseProvider = Provider<ReverseJournal>((ref) {
  return ReverseJournal(ref.read(accountingRepositoryProvider));
});
