import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/customer.dart';
import '../../domain/entities/customer_ledger.dart';
import '../../domain/entities/receivables_aging.dart';
import '../../domain/failures/customer_failure.dart';
import '../../domain/repositories/customers_repository.dart';
import '../datasources/customers_remote_datasource.dart';
import '../models/customer_model.dart';
import '../models/customer_ledger_model.dart';
import '../models/receivables_aging_model.dart';

final customersRepositoryProvider = Provider<CustomersRepository>((ref) {
  return CustomersRepositoryImpl(ref.read(customersRemoteDataSourceProvider));
});

class CustomersRepositoryImpl implements CustomersRepository {
  final CustomersRemoteDataSource _ds;

  CustomersRepositoryImpl(this._ds);

  CustomerFailure _mapError(Object e) {
    if (e is PostgrestException) {
      final code = e.code;
      if (code == '42501') return CustomerPermissionDeniedFailure();
      if (code == 'PGRST116' || code == 'P0002') {
        return CustomerNotFoundFailure();
      }
    }
    if (e is AuthException) return CustomerPermissionDeniedFailure();
    if (e is SocketException || e is TimeoutException) {
      return CustomerUnknownFailure(
          'Network error. Please check your connection.');
    }
    return CustomerUnknownFailure(e.toString());
  }

  @override
  Future<(List<Customer>, CustomerFailure?)> loadCustomers({
    String? query,
    CustomerStatus? status,
  }) async {
    try {
      final rows = await _ds.loadCustomers(
        query: query,
        status: status == null ? null : CustomerModel.statusToDb(status),
      );
      return (rows.map(CustomerModel.fromJson).toList(), null);
    } catch (e) {
      return (<Customer>[], _mapError(e));
    }
  }

  @override
  Future<(Customer?, CustomerFailure?)> loadCustomer(String id) async {
    try {
      final row = await _ds.loadCustomer(id);
      return (CustomerModel.fromJson(row), null);
    } catch (e) {
      return (null, _mapError(e));
    }
  }

  @override
  Future<(Customer?, CustomerFailure?)> createCustomer(
      Map<String, dynamic> data) async {
    try {
      final row = await _ds.insertCustomer(CustomerModel.toInsert(data));
      return (CustomerModel.fromJson(row), null);
    } catch (e) {
      return (null, _mapError(e));
    }
  }

  @override
  Future<(Customer?, CustomerFailure?)> updateCustomer(
      String id, Map<String, dynamic> data) async {
    try {
      final row = await _ds.updateCustomer(id, CustomerModel.toUpdate(data));
      return (CustomerModel.fromJson(row), null);
    } catch (e) {
      return (null, _mapError(e));
    }
  }

  @override
  Future<(bool, CustomerFailure?)> softDeleteCustomer(String id) async {
    try {
      await _ds.softDeleteCustomer(id);
      return (true, null);
    } catch (e) {
      return (false, _mapError(e));
    }
  }

  @override
  Future<(CustomerLedger?, CustomerFailure?)> loadCustomerLedger(
      String customerId) async {
    try {
      final row = await _ds.customerLedger(customerId);
      return (CustomerLedgerModel.fromJson(row), null);
    } catch (e) {
      return (null, _mapError(e));
    }
  }

  @override
  Future<(ReceivablesAging?, CustomerFailure?)> loadReceivablesAging() async {
    try {
      final row = await _ds.receivablesAging();
      return (ReceivablesAgingModel.fromJson(row), null);
    } catch (e) {
      return (null, _mapError(e));
    }
  }
}
