import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/settings_repository_impl.dart';
import '../entities/bank_account_ref.dart';
import '../entities/branch_config.dart';
import '../entities/number_series_info.dart';
import '../entities/payment_method_config.dart';
import '../entities/tenant_settings.dart';
import '../entities/ui_preferences.dart';
import '../failures/settings_failure.dart';
import '../repositories/settings_repository.dart';

// One thin use case per operation; all delegate to SettingsRepository.

class LoadTenantSettings {
  final SettingsRepository _r;
  LoadTenantSettings(this._r);
  Future<(TenantSettings?, SettingsFailure?)> call() => _r.loadTenantSettings();
}

class UpdateTenantSettings {
  final SettingsRepository _r;
  UpdateTenantSettings(this._r);
  Future<(Map<String, dynamic>?, SettingsFailure?)> call(
    Map<String, dynamic> patch,
  ) =>
      _r.updateTenantSettings(patch);
}

class LoadBranches {
  final SettingsRepository _r;
  LoadBranches(this._r);
  Future<(List<BranchConfig>, SettingsFailure?)> call() => _r.loadBranches();
}

class UpdateBranchSettings {
  final SettingsRepository _r;
  UpdateBranchSettings(this._r);
  Future<SettingsFailure?> call({
    required String branchId,
    String? name,
    String? city,
    String? country,
    String? currency,
    String? timezone,
    bool? isActive,
  }) =>
      _r.updateBranchSettings(
        branchId: branchId,
        name: name,
        city: city,
        country: country,
        currency: currency,
        timezone: timezone,
        isActive: isActive,
      );
}

class LoadPaymentMethods {
  final SettingsRepository _r;
  LoadPaymentMethods(this._r);
  Future<(List<PaymentMethodConfig>, SettingsFailure?)> call() =>
      _r.loadPaymentMethods();
}

class CreatePaymentMethod {
  final SettingsRepository _r;
  CreatePaymentMethod(this._r);
  Future<SettingsFailure?> call({
    required String code,
    required String name,
    required bool requiresReference,
    required int sortOrder,
  }) =>
      _r.createPaymentMethod(
        code: code,
        name: name,
        requiresReference: requiresReference,
        sortOrder: sortOrder,
      );
}

class UpdatePaymentMethod {
  final SettingsRepository _r;
  UpdatePaymentMethod(this._r);
  Future<SettingsFailure?> call(
    String id, {
    String? name,
    bool? isActive,
    bool? requiresReference,
    int? sortOrder,
    String? bankAccountId,
    bool clearBankAccount = false,
  }) =>
      _r.updatePaymentMethod(
        id,
        name: name,
        isActive: isActive,
        requiresReference: requiresReference,
        sortOrder: sortOrder,
        bankAccountId: bankAccountId,
        clearBankAccount: clearBankAccount,
      );
}

class DeletePaymentMethod {
  final SettingsRepository _r;
  DeletePaymentMethod(this._r);
  Future<SettingsFailure?> call(String id) => _r.deletePaymentMethod(id);
}

class LoadBankAccounts {
  final SettingsRepository _r;
  LoadBankAccounts(this._r);
  Future<(List<BankAccountRef>, SettingsFailure?)> call() =>
      _r.loadBankAccounts();
}

class LoadNumberSeries {
  final SettingsRepository _r;
  LoadNumberSeries(this._r);
  Future<(List<NumberSeriesInfo>, SettingsFailure?)> call() =>
      _r.loadNumberSeries();
}

class LoadUiPreferences {
  final SettingsRepository _r;
  LoadUiPreferences(this._r);
  Future<(UiPreferences, SettingsFailure?)> call() => _r.loadUiPreferences();
}

class SaveUiPreferences {
  final SettingsRepository _r;
  SaveUiPreferences(this._r);
  Future<SettingsFailure?> call({
    String? theme,
    String? language,
    String? defaultBranchId,
  }) =>
      _r.saveUiPreferences(
        theme: theme,
        language: language,
        defaultBranchId: defaultBranchId,
      );
}

// Providers
SettingsRepository _repo(Ref ref) => ref.read(settingsRepositoryProvider);

final loadTenantSettingsUseCaseProvider =
    Provider((ref) => LoadTenantSettings(_repo(ref)));
final updateTenantSettingsUseCaseProvider =
    Provider((ref) => UpdateTenantSettings(_repo(ref)));
final loadBranchesUseCaseProvider =
    Provider((ref) => LoadBranches(_repo(ref)));
final updateBranchSettingsUseCaseProvider =
    Provider((ref) => UpdateBranchSettings(_repo(ref)));
final loadPaymentMethodsUseCaseProvider =
    Provider((ref) => LoadPaymentMethods(_repo(ref)));
final createPaymentMethodUseCaseProvider =
    Provider((ref) => CreatePaymentMethod(_repo(ref)));
final updatePaymentMethodUseCaseProvider =
    Provider((ref) => UpdatePaymentMethod(_repo(ref)));
final deletePaymentMethodUseCaseProvider =
    Provider((ref) => DeletePaymentMethod(_repo(ref)));
final loadBankAccountsUseCaseProvider =
    Provider((ref) => LoadBankAccounts(_repo(ref)));
final loadNumberSeriesUseCaseProvider =
    Provider((ref) => LoadNumberSeries(_repo(ref)));
final loadUiPreferencesUseCaseProvider =
    Provider((ref) => LoadUiPreferences(_repo(ref)));
final saveUiPreferencesUseCaseProvider =
    Provider((ref) => SaveUiPreferences(_repo(ref)));
