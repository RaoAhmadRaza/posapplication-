import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/journal_entry.dart';
import '../entities/journal_line.dart';
import '../failures/accounting_failure.dart';
import '../repositories/accounting_repository.dart';
import '../../data/repositories/accounting_repository_impl.dart';

class LoadJournalEntry {
  final AccountingRepository _repo;
  LoadJournalEntry(this._repo);

  Future<(JournalEntry?, List<JournalLine>, AccountingFailure?)> call(
    String id,
  ) {
    return _repo.loadJournalEntry(id);
  }
}

final loadJournalEntryUseCaseProvider = Provider<LoadJournalEntry>((ref) {
  return LoadJournalEntry(ref.read(accountingRepositoryProvider));
});
