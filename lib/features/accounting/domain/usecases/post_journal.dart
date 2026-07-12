import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/accounting_results.dart';
import '../failures/accounting_failure.dart';
import '../repositories/accounting_repository.dart';
import '../../data/repositories/accounting_repository_impl.dart';

class PostJournal {
  final AccountingRepository _repo;
  PostJournal(this._repo);

  Future<(PostJournalResult?, AccountingFailure?)> call({
    required String branchId,
    required String description,
    required List<Map<String, dynamic>> lines,
    DateTime? date,
  }) {
    return _repo.postJournal(
      branchId: branchId,
      description: description,
      lines: lines,
      date: date,
    );
  }
}

final postJournalUseCaseProvider = Provider<PostJournal>((ref) {
  return PostJournal(ref.read(accountingRepositoryProvider));
});
