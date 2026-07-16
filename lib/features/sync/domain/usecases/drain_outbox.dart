import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../entities/outbox_entry.dart';
import '../entities/sync_exception.dart';
import '../failures/sync_failure.dart';
import '../repositories/sync_repository.dart';
import '../../data/repositories/sync_repository_impl.dart';

/// Drain the outbox oldest-first, serial. One repo call.
class DrainOutbox {
  DrainOutbox(this._repo);
  final SyncRepository _repo;
  Future<(DrainSummary, SyncFailure?)> call() => _repo.drainOutbox();
}

class LoadOutboxIntents {
  LoadOutboxIntents(this._repo);
  final SyncRepository _repo;
  Future<(List<OutboxEntry>, SyncFailure?)> call() => _repo.loadIntents();
}

class FindByRef {
  FindByRef(this._repo);
  final SyncRepository _repo;
  Future<(List<OutboxEntry>, SyncFailure?)> call(String q) => _repo.findByRef(q);
}

class LoadSyncExceptions {
  LoadSyncExceptions(this._repo);
  final SyncRepository _repo;
  Future<(List<SyncException>, SyncFailure?)> call() => _repo.loadOpenExceptions();
}

class ResolveSyncException {
  ResolveSyncException(this._repo);
  final SyncRepository _repo;
  Future<SyncFailure?> call(String id, String note) => _repo.resolveException(id, note);
}

final drainOutboxUseCaseProvider =
    Provider((ref) => DrainOutbox(ref.read(syncRepositoryProvider)));
final loadOutboxIntentsUseCaseProvider =
    Provider((ref) => LoadOutboxIntents(ref.read(syncRepositoryProvider)));
final findByRefUseCaseProvider =
    Provider((ref) => FindByRef(ref.read(syncRepositoryProvider)));
final loadSyncExceptionsUseCaseProvider =
    Provider((ref) => LoadSyncExceptions(ref.read(syncRepositoryProvider)));
final resolveSyncExceptionUseCaseProvider =
    Provider((ref) => ResolveSyncException(ref.read(syncRepositoryProvider)));
