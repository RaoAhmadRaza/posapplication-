import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/controllers/branch_controller.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/usecases/load_invoices.dart';
import '../../domain/usecases/load_invoice_detail.dart';
import '../../domain/usecases/create_sales_return.dart';
import '../../domain/usecases/void_invoice.dart';
import '../../domain/entities/sale_result.dart';
import '../../domain/failures/sales_failure.dart';

final invoicesProvider =
    AsyncNotifierProvider<InvoicesController, List<Invoice>>(
  InvoicesController.new,
);

class InvoicesController extends AsyncNotifier<List<Invoice>> {
  @override
  Future<List<Invoice>> build() async {
    final branch = ref.read(currentBranchProvider);
    final (invoices, failure) = await ref
        .read(loadInvoicesUseCaseProvider)
        .call(branchId: branch?.id);
    if (failure != null) throw failure;
    return invoices;
  }

  Future<void> load({
    String? branchId,
    String? status,
    String? customerId,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final (invoices, failure) = await ref.read(loadInvoicesUseCaseProvider).call(
            branchId: branchId,
            status: status,
            customerId: customerId,
          );
      if (failure != null) throw failure;
      return invoices;
    });
  }

  Future<Map<String, dynamic>?> loadDetail(String id) async {
    final (detail, failure) =
        await ref.read(loadInvoiceDetailUseCaseProvider).call(id);
    if (failure != null) return null;
    return detail;
  }

  Future<(SaleResult?, SalesFailure?)> doReturn({
    required String originalInvoiceId,
    required List<Map<String, dynamic>> items,
    required String reason,
    required List<Map<String, dynamic>> refunds,
  }) async {
    final result = await ref.read(createSalesReturnUseCaseProvider).call(
          originalInvoiceId: originalInvoiceId,
          items: items,
          reason: reason,
          refunds: refunds,
        );
    if (result.$2 == null) ref.invalidateSelf();
    return result;
  }

  Future<SalesFailure?> voidInvoice({
    required String invoiceId,
    required String reason,
  }) async {
    final (_, failure) = await ref.read(voidInvoiceUseCaseProvider).call(
          invoiceId: invoiceId,
          reason: reason,
        );
    if (failure != null) return failure;
    ref.invalidateSelf();
    return null;
  }
}
