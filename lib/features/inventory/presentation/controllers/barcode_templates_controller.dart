import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/barcode_template.dart';
import '../../domain/failures/inventory_failure.dart';
import '../../domain/usecases/load_barcode_templates.dart';
import '../../domain/usecases/save_barcode_template.dart';

final barcodeTemplatesProvider =
    AsyncNotifierProvider<BarcodeTemplatesController, List<BarcodeTemplate>>(
  BarcodeTemplatesController.new,
);

class BarcodeTemplatesController extends AsyncNotifier<List<BarcodeTemplate>> {
  @override
  Future<List<BarcodeTemplate>> build() async {
    final (templates, failure) =
        await ref.read(loadBarcodeTemplatesUseCaseProvider).call();
    if (failure != null) throw failure;
    return templates;
  }

  void refresh() => ref.invalidateSelf();

  Future<InventoryFailure?> save({
    required Map<String, dynamic> data,
    String? id,
  }) async {
    final (_, failure) = await ref
        .read(saveBarcodeTemplateUseCaseProvider)
        .call(data: data, id: id);
    if (failure != null) return failure;
    ref.invalidateSelf();
    return null;
  }
}
