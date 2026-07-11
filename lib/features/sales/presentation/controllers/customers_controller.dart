import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/customer.dart';
import '../../domain/failures/sales_failure.dart';
import '../../domain/usecases/load_customers.dart';
import '../../domain/usecases/create_customer.dart';

final customersProvider =
    AsyncNotifierProvider<CustomersController, List<Customer>>(
  CustomersController.new,
);

class CustomersController extends AsyncNotifier<List<Customer>> {
  @override
  Future<List<Customer>> build() async {
    final (customers, failure) =
        await ref.read(loadCustomersUseCaseProvider).call();
    if (failure != null) throw failure;
    return customers;
  }

  Future<void> search(String q) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final (customers, failure) =
          await ref.read(loadCustomersUseCaseProvider).call(query: q);
      if (failure != null) throw failure;
      return customers;
    });
  }

  Future<SalesFailure?> create(Map<String, dynamic> data) async {
    final (_, failure) =
        await ref.read(createCustomerUseCaseProvider).call(data);
    if (failure != null) return failure;
    ref.invalidateSelf();
    return null;
  }
}
