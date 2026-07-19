import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/bank_account_ref.dart';
import '../../domain/entities/branch_config.dart';
import '../../domain/entities/number_series_info.dart';
import '../../domain/entities/payment_method_config.dart';
import '../../domain/entities/tenant_settings.dart';
import '../../domain/entities/ui_preferences.dart';
import '../../domain/failures/settings_failure.dart';
import '../../domain/repositories/settings_repository.dart';
import '../datasources/settings_remote_datasource.dart';
import '../models/settings_models.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepositoryImpl(ref.read(settingsRemoteDataSourceProvider));
});

class SettingsRepositoryImpl implements SettingsRepository {
  final SettingsRemoteDataSource _ds;
  SettingsRepositoryImpl(this._ds);

  SettingsFailure _mapError(Object e) {
    if (e is PostgrestException) {
      final code = e.code ?? '';
      if (code == '42501' || e.message.contains('ERR_PERMISSION_DENIED')) {
        return SettingsPermissionFailure();
      }
      if (e.message.contains('ERR_BRANCH_NOT_FOUND') ||
          e.message.contains('ERR_NOT_FOUND')) {
        return SettingsNotFoundFailure();
      }
      return SettingsLoadFailure();
    }
    if (e is AuthException || e is SocketException || e is TimeoutException) {
      return SettingsLoadFailure();
    }
    return SettingsUnknownFailure(e.toString());
  }

  @override
  Future<(TenantSettings?, SettingsFailure?)> loadTenantSettings() async {
    try {
      return (SettingsModels.tenant(await _ds.loadTenantSettings()), null);
    } catch (e) {
      return (null, _mapError(e));
    }
  }

  @override
  Future<(Map<String, dynamic>?, SettingsFailure?)> updateTenantSettings(
    Map<String, dynamic> patch,
  ) async {
    try {
      return (await _ds.updateTenantSettings(patch), null);
    } catch (e) {
      return (null, _mapError(e));
    }
  }

  @override
  Future<(List<BranchConfig>, SettingsFailure?)> loadBranches() async {
    try {
      final rows = await _ds.loadBranches();
      return (rows.map(SettingsModels.branch).toList(), null);
    } catch (e) {
      return (<BranchConfig>[], _mapError(e));
    }
  }

  @override
  Future<SettingsFailure?> updateBranchSettings({
    required String branchId,
    String? name,
    String? city,
    String? country,
    String? currency,
    String? timezone,
    bool? isActive,
  }) async {
    try {
      await _ds.updateBranchSettings(
        branchId: branchId,
        name: name,
        city: city,
        country: country,
        currency: currency,
        timezone: timezone,
        isActive: isActive,
      );
      return null;
    } catch (e) {
      return _mapError(e);
    }
  }

  @override
  Future<SettingsFailure?> createBranch({
    required String name,
    String? city,
    String? country,
    String? currency,
    String? timezone,
  }) async {
    try {
      await _ds.createBranch(
        name: name,
        city: city,
        country: country,
        currency: currency,
        timezone: timezone,
      );
      return null;
    } catch (e) {
      return _mapError(e);
    }
  }

  @override
  Future<(List<PaymentMethodConfig>, SettingsFailure?)>
      loadPaymentMethods() async {
    try {
      final rows = await _ds.loadPaymentMethods();
      final methods = rows.map(SettingsModels.paymentMethod).toList();
      // Populate each method's resolved GL account so the UI shows where it posts.
      final resolved = <PaymentMethodConfig>[];
      for (final m in methods) {
        final code = await _ds.resolvePaymentAccount(
          method: m.code,
          bankAccountId: m.bankAccountId,
        );
        resolved.add(m.copyWith(resolvedAccountCode: code));
      }
      return (resolved, null);
    } catch (e) {
      return (<PaymentMethodConfig>[], _mapError(e));
    }
  }

  @override
  Future<SettingsFailure?> createPaymentMethod({
    required String code,
    required String name,
    required bool requiresReference,
    required int sortOrder,
  }) async {
    try {
      await _ds.createPaymentMethod({
        'code': code,
        'name': name,
        'requires_reference': requiresReference,
        'sort_order': sortOrder,
      });
      return null;
    } catch (e) {
      return _mapError(e);
    }
  }

  @override
  Future<SettingsFailure?> updatePaymentMethod(
    String id, {
    String? name,
    bool? isActive,
    bool? requiresReference,
    int? sortOrder,
    String? bankAccountId,
    bool clearBankAccount = false,
  }) async {
    try {
      final data = <String, dynamic>{
        'name': ?name,
        'is_active': ?isActive,
        'requires_reference': ?requiresReference,
        'sort_order': ?sortOrder,
        if (clearBankAccount) 'bank_account_id': null
        else 'bank_account_id': ?bankAccountId,
      };
      if (data.isNotEmpty) await _ds.updatePaymentMethod(id, data);
      return null;
    } catch (e) {
      return _mapError(e);
    }
  }

  @override
  Future<SettingsFailure?> deletePaymentMethod(String id) async {
    try {
      await _ds.softDeletePaymentMethod(id);
      return null;
    } catch (e) {
      return _mapError(e);
    }
  }

  @override
  Future<(List<BankAccountRef>, SettingsFailure?)> loadBankAccounts() async {
    try {
      final rows = await _ds.loadBankAccounts();
      return (rows.map(SettingsModels.bankAccount).toList(), null);
    } catch (e) {
      return (<BankAccountRef>[], _mapError(e));
    }
  }

  @override
  Future<(List<NumberSeriesInfo>, SettingsFailure?)> loadNumberSeries() async {
    try {
      final rows = await _ds.loadNumberSeries();
      return (rows.map(SettingsModels.numberSeries).toList(), null);
    } catch (e) {
      return (<NumberSeriesInfo>[], _mapError(e));
    }
  }

  @override
  Future<(UiPreferences, SettingsFailure?)> loadUiPreferences() async {
    try {
      return (SettingsModels.uiPreferences(await _ds.loadUiPreferences()), null);
    } catch (e) {
      return (UiPreferences.empty, _mapError(e));
    }
  }

  @override
  Future<SettingsFailure?> saveUiPreferences({
    String? theme,
    String? language,
    String? defaultBranchId,
  }) async {
    try {
      await _ds.upsertUiPreferences(
        theme: theme,
        language: language,
        defaultBranchId: defaultBranchId,
      );
      return null;
    } catch (e) {
      return _mapError(e);
    }
  }
}
