import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/mfa_repository_impl.dart';
import '../repositories/mfa_repository.dart';

class NeedsAal2 {
  final MfaRepository _repo;
  NeedsAal2(this._repo);

  bool call() => _repo.needsAal2();
}

final needsAal2UseCaseProvider = Provider<NeedsAal2>((ref) {
  return NeedsAal2(ref.read(mfaRepositoryProvider));
});
