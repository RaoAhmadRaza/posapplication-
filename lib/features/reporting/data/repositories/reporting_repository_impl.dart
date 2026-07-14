import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/reporting.dart';
import '../../domain/failures/reporting_failure.dart';
import '../../domain/repositories/reporting_repository.dart';
import '../datasources/reporting_remote_datasource.dart';
import '../models/reporting_models.dart';

final reportingRepositoryProvider = Provider<ReportingRepository>((ref) {
  return ReportingRepositoryImpl(ref.read(reportingRemoteDataSourceProvider));
});

class ReportingRepositoryImpl implements ReportingRepository {
  final ReportingRemoteDataSource _ds;
  ReportingRepositoryImpl(this._ds);

  ReportingFailure _mapError(Object e) {
    if (e is PostgrestException ||
        e is AuthException ||
        e is SocketException ||
        e is TimeoutException) {
      return ReportingLoadFailure();
    }
    return ReportingUnknownFailure(e.toString());
  }

  @override
  Future<(List<InventoryValuationRow>, ReportingFailure?)>
      inventoryValuation() async {
    try {
      final rows = await _ds.inventoryValuation();
      return (rows.map(ReportingModels.inventory).toList(), null);
    } catch (e) {
      return (<InventoryValuationRow>[], _mapError(e));
    }
  }

  @override
  Future<(List<ProductPerformanceRow>, ReportingFailure?)>
      productPerformance() async {
    try {
      final rows = await _ds.productPerformance();
      return (rows.map(ReportingModels.product).toList(), null);
    } catch (e) {
      return (<ProductPerformanceRow>[], _mapError(e));
    }
  }

  @override
  Future<(List<AgingRow>, ReportingFailure?)> customerAging() async {
    try {
      final rows = await _ds.customerAging();
      return (
        rows.map((r) => ReportingModels.aging(r, customer: true)).toList(),
        null
      );
    } catch (e) {
      return (<AgingRow>[], _mapError(e));
    }
  }

  @override
  Future<(List<AgingRow>, ReportingFailure?)> supplierAging() async {
    try {
      final rows = await _ds.supplierAging();
      return (
        rows.map((r) => ReportingModels.aging(r, customer: false)).toList(),
        null
      );
    } catch (e) {
      return (<AgingRow>[], _mapError(e));
    }
  }

  @override
  Future<(List<DailySalesRow>, ReportingFailure?)> dailySales({
    String? from,
    String? to,
  }) async {
    try {
      final rows = await _ds.dailySales(from: from, to: to);
      return (rows.map(ReportingModels.daily).toList(), null);
    } catch (e) {
      return (<DailySalesRow>[], _mapError(e));
    }
  }
}
