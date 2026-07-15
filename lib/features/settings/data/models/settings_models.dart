import '../../domain/entities/bank_account_ref.dart';
import '../../domain/entities/branch_config.dart';
import '../../domain/entities/number_series_info.dart';
import '../../domain/entities/payment_method_config.dart';
import '../../domain/entities/tenant_settings.dart';
import '../../domain/entities/ui_preferences.dart';

/// Map -> entity mappers for the settings feature. All rows come from the
/// single settings datasource; nothing maps Supabase types outside data/.
class SettingsModels {
  static TenantSettings tenant(Map<String, dynamic> row) => TenantSettings(
        tenantName: (row['name'] ?? '').toString(),
        json: (row['settings_json'] as Map?)?.cast<String, dynamic>() ??
            <String, dynamic>{},
      );

  static BranchConfig branch(Map<String, dynamic> row) => BranchConfig(
        id: row['id'] as String,
        name: (row['name'] ?? '').toString(),
        code: (row['code'] ?? '').toString(),
        city: row['city'] as String?,
        country: row['country'] as String?,
        currency: (row['currency'] ?? 'PKR').toString(),
        timezone: (row['timezone'] ?? 'Asia/Karachi').toString(),
        isActive: row['is_active'] as bool? ?? true,
        isMain: row['is_main'] as bool? ?? false,
      );

  static PaymentMethodConfig paymentMethod(Map<String, dynamic> row) =>
      PaymentMethodConfig(
        id: row['id'] as String,
        code: (row['code'] ?? '').toString(),
        name: (row['name'] ?? '').toString(),
        isActive: row['is_active'] as bool? ?? true,
        isSystem: row['is_system'] as bool? ?? false,
        requiresReference: row['requires_reference'] as bool? ?? false,
        sortOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
        bankAccountId: row['bank_account_id'] as String?,
      );

  static BankAccountRef bankAccount(Map<String, dynamic> row) => BankAccountRef(
        id: row['id'] as String,
        accountName: (row['account_name'] ?? '').toString(),
        bankName: (row['bank_name'] ?? '').toString(),
      );

  static NumberSeriesInfo numberSeries(Map<String, dynamic> row) =>
      NumberSeriesInfo(
        type: (row['type'] ?? '').toString(),
        prefix: (row['prefix'] ?? '').toString(),
        padding: (row['padding'] as num?)?.toInt() ?? 6,
        currentNumber: (row['current_number'] as num?)?.toInt() ?? 0,
        fiscalYearReset: row['fiscal_year_reset'] as bool? ?? false,
      );

  static UiPreferences uiPreferences(Map<String, dynamic>? row) {
    if (row == null) return UiPreferences.empty;
    return UiPreferences(
      theme: (row['theme'] ?? 'light').toString(),
      language: (row['language'] ?? 'en').toString(),
      defaultBranchId: row['default_branch_id'] as String?,
    );
  }
}
