import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/journal_entry.dart';
import '../../domain/entities/journal_line.dart';
import '../../domain/failures/accounting_failure.dart';
import '../../domain/usecases/load_journal_entries.dart';
import '../../domain/usecases/load_journal_entry.dart';
import '../../domain/usecases/post_journal.dart';
import '../../domain/usecases/reverse_journal.dart';

final journalEntriesProvider =
    AsyncNotifierProvider<JournalEntriesController, List<JournalEntry>>(
      JournalEntriesController.new,
    );

class JournalEntriesController extends AsyncNotifier<List<JournalEntry>> {
  int? _limit;

  @override
  Future<List<JournalEntry>> build() async {
    final (entries, failure) = await ref
        .read(loadJournalEntriesUseCaseProvider)
        .call(limit: _limit);
    if (failure != null) throw failure;
    return entries;
  }

  Future<void> setLimit(int? limit) async {
    _limit = limit;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final (entries, failure) = await ref
          .read(loadJournalEntriesUseCaseProvider)
          .call(limit: _limit);
      if (failure != null) throw failure;
      return entries;
    });
  }

  void refresh() => ref.invalidateSelf();
}

/// Journal entry header + its lines for the detail view.
final journalEntryDetailProvider = FutureProvider.autoDispose
    .family<(JournalEntry?, List<JournalLine>), String>((ref, id) async {
      final (entry, lines, failure) = await ref
          .read(loadJournalEntryUseCaseProvider)
          .call(id);
      if (failure != null) throw failure;
      return (entry, lines);
    });

final journalControllerProvider = NotifierProvider<JournalController, void>(
  JournalController.new,
);

class JournalController extends Notifier<void> {
  @override
  void build() {}

  Future<AccountingFailure?> postJournal({
    required String branchId,
    required String description,
    required List<Map<String, dynamic>> lines,
    DateTime? date,
  }) async {
    final (_, failure) = await ref
        .read(postJournalUseCaseProvider)
        .call(
          branchId: branchId,
          description: description,
          lines: lines,
          date: date,
        );
    if (failure != null) return failure;
    ref.invalidate(journalEntriesProvider);
    return null;
  }

  Future<AccountingFailure?> reverseJournal({
    required String entryId,
    required String reason,
  }) async {
    final (_, failure) = await ref
        .read(reverseJournalUseCaseProvider)
        .call(entryId: entryId, reason: reason);
    if (failure != null) return failure;
    ref.invalidate(journalEntriesProvider);
    ref.invalidate(journalEntryDetailProvider(entryId));
    return null;
  }
}
