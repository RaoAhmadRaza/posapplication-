import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/supplier.dart';
import '../../domain/entities/supplier_ledger.dart';
import '../../domain/entities/payables_aging.dart';
import '../../domain/failures/supplier_failure.dart';
import '../../domain/repositories/suppliers_repository.dart';
import '../datasources/suppliers_remote_datasource.dart';
import '../models/supplier_model.dart';
import '../models/supplier_ledger_model.dart';
import '../models/payables_aging_model.dart';

final suppliersRepositoryProvider = Provider<SuppliersRepository>((ref) {
  return SuppliersRepositoryImpl(ref.read(suppliersRemoteDataSourceProvider));
});

class SuppliersRepositoryImpl implements SuppliersRepository {
  final SuppliersRemoteDataSource _ds;

  SuppliersRepositoryImpl(this._ds);

  SupplierFailure _mapError(Object e) {
    if (e is PostgrestException) {
      final code = e.code;
      if (code == '42501') return SupplierPermissionDeniedFailure();
      if (code == 'PGRST116' || code == 'P0002') {
        return SupplierNotFoundFailure();
      }
    }
    if (e is AuthException) return SupplierPermissionDeniedFailure();
    if (e is SocketException || e is TimeoutException) {
      return SupplierUnknownFailure(
          'Network error. Please check your connection.');
    }
    return SupplierUnknownFailure(e.toString());
  }

  @override
  Future<(List<Supplier>, SupplierFailure?)> loadSuppliers({
    String? query,
    SupplierStatus? status,
  }) async {
    try {
      final rows = await _ds.loadSuppliers(
        query: query,
        status: status == null ? null : SupplierModel.statusToDb(status),
      );
      return (rows.map(SupplierModel.fromJson).toList(), null);
    } catch (e) {
      return (<Supplier>[], _mapError(e));
    }
  }

  @override
  Future<(Supplier?, SupplierFailure?)> loadSupplier(String id) async {
    try {
      final row = await _ds.loadSupplier(id);
      return (SupplierModel.fromJson(row), null);
    } catch (e) {
      return (null, _mapError(e));
    }
  }

  @override
  Future<(Supplier?, SupplierFailure?)> createSupplier(
      Map<String, dynamic> data) async {
    try {
      final row = await _ds.insertSupplier(SupplierModel.toInsert(data));
      return (SupplierModel.fromJson(row), null);
    } catch (e) {
      return (null, _mapError(e));
    }
  }

  @override
  Future<(Supplier?, SupplierFailure?)> updateSupplier(
      String id, Map<String, dynamic> data) async {
    try {
      final row = await _ds.updateSupplier(id, SupplierModel.toUpdate(data));
      return (SupplierModel.fromJson(row), null);
    } catch (e) {
      return (null, _mapError(e));
    }
  }

  @override
  Future<(bool, SupplierFailure?)> softDeleteSupplier(String id) async {
    try {
      await _ds.softDeleteSupplier(id);
      return (true, null);
    } catch (e) {
      return (false, _mapError(e));
    }
  }

  @override
  Future<(SupplierLedger?, SupplierFailure?)> loadSupplierLedger(
      String supplierId) async {
    try {
      final row = await _ds.supplierLedger(supplierId);
      return (SupplierLedgerModel.fromJson(row), null);
    } catch (e) {
      return (null, _mapError(e));
    }
  }

  @override
  Future<(PayablesAging?, SupplierFailure?)> loadPayablesAging() async {
    try {
      final row = await _ds.payablesAging();
      return (PayablesAgingModel.fromJson(row), null);
    } catch (e) {
      return (null, _mapError(e));
    }
  }
}
