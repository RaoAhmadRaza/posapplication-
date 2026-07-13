import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../failures/repair_failure.dart';
import '../repositories/repair_repository.dart';
import '../../data/repositories/repair_repository_impl.dart';

class UploadRepairSignature {
  final RepairRepository _repo;
  UploadRepairSignature(this._repo);

  Future<(String?, RepairFailure?)> call(String repairId, Uint8List bytes) {
    return _repo.uploadSignature(repairId, bytes);
  }
}

class RepairSignatureUrl {
  final RepairRepository _repo;
  RepairSignatureUrl(this._repo);

  Future<(String?, RepairFailure?)> call(String path) {
    return _repo.signatureSignedUrl(path);
  }
}

final uploadRepairSignatureUseCaseProvider =
    Provider<UploadRepairSignature>((ref) {
  return UploadRepairSignature(ref.read(repairRepositoryProvider));
});

final repairSignatureUrlUseCaseProvider = Provider<RepairSignatureUrl>((ref) {
  return RepairSignatureUrl(ref.read(repairRepositoryProvider));
});
