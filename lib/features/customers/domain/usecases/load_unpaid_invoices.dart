import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/customer_invoice.dart';
import '../failures/customer_failure.dart';
import '../repositories/customers_repository.dart';
import '../../data/repositories/customers_repository_impl.dart';

class LoadUnpaidInvoices {
  final CustomersRepository _repo;
  LoadUnpaidInvoices(this._repo);

  Future<(List<CustomerInvoice>, CustomerFailure?)> call(String customerId) {
    return _repo.loadUnpaidInvoices(customerId);
  }
}

final loadUnpaidInvoicesUseCaseProvider = Provider<LoadUnpaidInvoices>((ref) {
  return LoadUnpaidInvoices(ref.read(customersRepositoryProvider));
});
