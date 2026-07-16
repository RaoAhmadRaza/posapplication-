import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../failures/sync_failure.dart';
import '../repositories/sync_repository.dart';
import '../../data/repositories/sync_repository_impl.dart';

/// Pull the Class A delta and refresh the local cache (watermark-driven).
class PullReference {
  PullReference(this._repo);
  final SyncRepository _repo;
  Future<SyncFailure?> call() => _repo.pullReference();
}

final pullReferenceUseCaseProvider = Provider<PullReference>(
  (ref) => PullReference(ref.read(syncRepositoryProvider)),
);
