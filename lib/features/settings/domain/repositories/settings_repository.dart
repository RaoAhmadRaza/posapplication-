import '../entities/bank_account_ref.dart';
import '../entities/branch_config.dart';
import '../entities/number_series_info.dart';
import '../entities/payment_method_config.dart';
import '../entities/tenant_settings.dart';
import '../entities/ui_preferences.dart';
import '../failures/settings_failure.dart';

abstract class SettingsRepository {
  Future<(TenantSettings?, SettingsFailure?)> loadTenantSettings();
  Future<(Map<String, dynamic>?, SettingsFailure?)> updateTenantSettings(
    Map<String, dynamic> patch,
  );

  Future<(List<BranchConfig>, SettingsFailure?)> loadBranches();
  Future<SettingsFailure?> updateBranchSettings({
    required String branchId,
    String? name,
    String? city,
    String? country,
    String? currency,
    String? timezone,
    bool? isActive,
  });

  /// Payment methods, each with its resolved GL account code populated.
  Future<(List<PaymentMethodConfig>, SettingsFailure?)> loadPaymentMethods();
  Future<SettingsFailure?> createPaymentMethod({
    required String code,
    required String name,
    required bool requiresReference,
    required int sortOrder,
  });
  Future<SettingsFailure?> updatePaymentMethod(
    String id, {
    String? name,
    bool? isActive,
    bool? requiresReference,
    int? sortOrder,
    String? bankAccountId,
    bool clearBankAccount = false,
  });
  Future<SettingsFailure?> deletePaymentMethod(String id);

  Future<(List<BankAccountRef>, SettingsFailure?)> loadBankAccounts();

  Future<(List<NumberSeriesInfo>, SettingsFailure?)> loadNumberSeries();

  Future<(UiPreferences, SettingsFailure?)> loadUiPreferences();
  Future<SettingsFailure?> saveUiPreferences({
    String? theme,
    String? language,
    String? defaultBranchId,
  });
}
