import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/journal_entry.dart';
import '../failures/accounting_failure.dart';
import '../repositories/accounting_repository.dart';
import '../../data/repositories/accounting_repository_impl.dart';

class LoadJournalEntries {
  final AccountingRepository _repo;
  LoadJournalEntries(this._repo);

  Future<(List<JournalEntry>, AccountingFailure?)> call({int? limit}) {
    return _repo.loadJournalEntries(limit: limit);
  }
}

final loadJournalEntriesUseCaseProvider = Provider<LoadJournalEntries>((ref) {
  return LoadJournalEntries(ref.read(accountingRepositoryProvider));
});
