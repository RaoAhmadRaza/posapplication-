import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/ai_recommendation.dart';
import '../../domain/entities/report_schedule.dart';
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

  @override
  Future<(List<ReportSchedule>, ReportingFailure?)> schedules() async {
    try {
      final rows = await _ds.listSchedules();
      return (rows.map(ReportingModels.schedule).toList(), null);
    } catch (e) {
      return (<ReportSchedule>[], _mapError(e));
    }
  }

  @override
  Future<ReportingFailure?> upsertSchedule({
    String? id,
    required String reportType,
    required String name,
    required String frequency,
    required Map<String, dynamic> filters,
    required List<String> recipients,
    required String format,
    required bool active,
  }) async {
    try {
      await _ds.upsertSchedule(
        id: id,
        reportType: reportType,
        name: name,
        frequency: frequency,
        filters: filters,
        recipients: recipients,
        format: format,
        active: active,
      );
      return null;
    } catch (e) {
      return _mapError(e);
    }
  }

  @override
  Future<(List<AiRecommendation>, ReportingFailure?)>
      pendingRecommendations() async {
    try {
      final rows = await _ds.pendingRecommendations();
      return (rows.map(ReportingModels.recommendation).toList(), null);
    } catch (e) {
      return (<AiRecommendation>[], _mapError(e));
    }
  }

  @override
  Future<ReportingFailure?> actOnRecommendation(String id, bool accept) async {
    try {
      await _ds.actOnRecommendation(id, accept);
      return null;
    } catch (e) {
      return _mapError(e);
    }
  }
}
