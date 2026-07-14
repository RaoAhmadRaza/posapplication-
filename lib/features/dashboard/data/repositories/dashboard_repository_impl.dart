import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/dashboard_summary.dart';
import '../../domain/entities/drilldown.dart';
import '../../domain/failures/dashboard_failure.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../datasources/dashboard_remote_datasource.dart';
import '../models/dashboard_summary_model.dart';
import '../models/drilldown_model.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepositoryImpl(ref.read(dashboardRemoteDataSourceProvider));
});

class DashboardRepositoryImpl implements DashboardRepository {
  final DashboardRemoteDataSource _ds;

  DashboardRepositoryImpl(this._ds);

  DashboardFailure _mapError(Object e) {
    if (e is PostgrestException || e is AuthException) {
      return DashboardLoadFailure();
    }
    if (e is SocketException || e is TimeoutException) {
      return DashboardLoadFailure();
    }
    return DashboardUnknownFailure(e.toString());
  }

  @override
  Future<(DashboardSummary, DashboardFailure?)> loadSummary({
    String? branchId,
    String? from,
    String? to,
  }) async {
    try {
      final row = await _ds.loadSummary(
        branchId: branchId,
        from: from,
        to: to,
      );
      return (DashboardSummaryModel.fromJson(row), null);
    } catch (e) {
      return (const DashboardSummary(
        todaySales: 0,
        todayTxns: 0,
        todayProfit: 0,
        receivables: 0,
        stockValue: 0,
        lowStockCount: 0,
        recentSales: [],
        salesTrend: [],
        paymentBreakdown: {},
        payablesTotal: 0,
        cashBalance: 0,
        bankBalance: 0,
        plSnapshot: 0,
      ), _mapError(e));
    }
  }

  @override
  Future<(List<DrilldownRow>, DashboardFailure?)> loadDrilldown(
    DrilldownArgs args,
  ) async {
    try {
      final rows = await _ds.drilldown(
        DrilldownModel.rpcName(args.type),
        DrilldownModel.params(args),
      );
      final mapped =
          rows.map((r) => DrilldownModel.row(args.type, r)).toList();
      return (mapped, null);
    } catch (e) {
      return (<DrilldownRow>[], _mapError(e));
    }
  }
}
