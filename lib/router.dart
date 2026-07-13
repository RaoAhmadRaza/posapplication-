import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'core/error/auth_failure.dart';
import 'core/state/app_flow_state.dart';
import 'core/supabase.dart';
import 'core/widgets/bottom_nav_shell.dart';
import 'features/auth/presentation/controllers/branch_controller.dart';
import 'features/auth/presentation/pages/splash_page.dart';
import 'features/auth/presentation/pages/environment_check_screen.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/auth/presentation/pages/signup_page.dart';
import 'features/auth/presentation/pages/otp_page.dart';
import 'features/auth/presentation/pages/forgot_password_page.dart';
import 'features/auth/presentation/pages/reset_password_page.dart';
import 'features/auth/presentation/pages/branch_select_page.dart';
import 'features/auth/presentation/pages/workspace_init_screen.dart';
import 'features/auth/presentation/pages/pin_lock_screen.dart';
import 'features/auth/presentation/pages/pin_setup_screen.dart';
import 'features/auth/presentation/pages/devices_screen.dart';
import 'features/auth/presentation/pages/security_logs_screen.dart';
import 'features/auth/presentation/pages/sessions_screen.dart';
import 'features/auth/presentation/pages/mfa_challenge_screen.dart';
import 'features/auth/presentation/pages/mfa_enroll_screen.dart';
import 'features/auth/presentation/pages/dashboard_page.dart';
import 'features/inventory/presentation/pages/inventory_hub_page.dart';
import 'features/inventory/presentation/pages/categories_page.dart';
import 'features/inventory/presentation/pages/category_form_page.dart';
import 'features/inventory/presentation/pages/brands_page.dart';
import 'features/inventory/presentation/pages/brand_form_page.dart';
import 'features/suppliers/presentation/pages/suppliers_page.dart';
import 'features/suppliers/presentation/pages/supplier_form_page.dart';
import 'features/suppliers/presentation/pages/supplier_detail_page.dart';
import 'features/customers/presentation/pages/customers_page.dart';
import 'features/customers/presentation/pages/customer_form_page.dart';
import 'features/customers/presentation/pages/customer_detail_page.dart';
import 'features/customers/presentation/pages/customer_payment_page.dart';
import 'features/customers/presentation/pages/receivables_aging_page.dart';
import 'features/accounting/presentation/pages/accounting_hub_page.dart';
import 'features/accounting/presentation/pages/chart_of_accounts_page.dart';
import 'features/accounting/presentation/pages/account_ledger_page.dart';
import 'features/accounting/presentation/pages/journal_entries_page.dart';
import 'features/accounting/presentation/pages/journal_entry_detail_page.dart';
import 'features/accounting/presentation/pages/manual_voucher_page.dart';
import 'features/accounting/presentation/pages/expenses_page.dart';
import 'features/accounting/presentation/pages/expense_form_page.dart';
import 'features/accounting/presentation/pages/expense_categories_page.dart';
import 'features/accounting/presentation/pages/bank_accounts_page.dart';
import 'features/accounting/presentation/pages/bank_account_form_page.dart';
import 'features/accounting/presentation/pages/tax_rules_page.dart';
import 'features/accounting/presentation/pages/tax_rule_form_page.dart';
import 'features/accounting/presentation/pages/trial_balance_page.dart';
import 'features/accounting/presentation/pages/profit_loss_page.dart';
import 'features/accounting/presentation/pages/balance_sheet_page.dart';
import 'features/accounting/presentation/pages/cash_bank_book_page.dart';
import 'features/accounting/presentation/pages/fiscal_periods_page.dart';
import 'features/accounting/presentation/pages/bank_reconciliation_page.dart';
import 'features/purchasing/presentation/pages/purchase_hub_page.dart';
import 'features/purchasing/presentation/pages/purchase_orders_page.dart';
import 'features/purchasing/presentation/pages/purchase_order_form_page.dart';
import 'features/purchasing/presentation/pages/purchase_order_detail_page.dart';
import 'features/purchasing/presentation/pages/grn_receive_page.dart';
import 'features/purchasing/presentation/pages/purchase_invoice_match_page.dart';
import 'features/purchasing/presentation/pages/purchase_invoices_page.dart';
import 'features/purchasing/presentation/pages/purchase_invoice_detail_page.dart';
import 'features/purchasing/presentation/pages/supplier_payment_page.dart';
import 'features/purchasing/presentation/pages/reorder_suggestions_page.dart';
import 'features/purchasing/presentation/pages/purchase_returns_page.dart';
import 'features/purchasing/presentation/pages/purchase_return_detail_page.dart';
import 'features/purchasing/presentation/pages/purchase_return_form_page.dart';
import 'features/repair/presentation/pages/repair_kanban_page.dart';
import 'features/repair/presentation/pages/repair_intake_page.dart';
import 'features/repair/presentation/pages/repair_detail_page.dart';
import 'features/repair/presentation/pages/repair_history_page.dart';
import 'features/repair/presentation/pages/technician_workload_page.dart';
import 'features/inventory/presentation/pages/products_page.dart';
import 'features/inventory/presentation/pages/product_form_page.dart';
import 'features/inventory/presentation/pages/barcode_templates_page.dart';
import 'features/inventory/presentation/pages/barcode_template_form_page.dart';
import 'features/inventory/presentation/pages/warehouses_page.dart';
import 'features/inventory/presentation/pages/warehouse_form_page.dart';
import 'features/inventory/presentation/pages/stock_levels_page.dart';
import 'features/inventory/presentation/pages/product_stock_detail_page.dart';
import 'features/inventory/presentation/pages/stock_movement_form_page.dart';
import 'features/inventory/presentation/pages/adjustments_page.dart';
import 'features/inventory/presentation/pages/adjustment_form_page.dart';
import 'features/inventory/presentation/pages/transfers_page.dart';
import 'features/inventory/presentation/pages/transfer_form_page.dart';
import 'features/inventory/presentation/pages/transfer_receive_page.dart';
import 'features/inventory/presentation/pages/counts_page.dart';
import 'features/inventory/presentation/pages/count_session_page.dart';
import 'features/inventory/presentation/pages/imei_lookup_page.dart';
import 'features/inventory/presentation/pages/label_print_page.dart';
import 'features/inventory/presentation/pages/import_products_page.dart';
import 'features/migration_import/presentation/pages/migration_import_page.dart';
import 'features/notifications/presentation/pages/notifications_page.dart';
import 'features/sales/presentation/pages/pos_terminal_page.dart';
import 'features/sales/presentation/pages/open_session_page.dart';
import 'features/sales/presentation/pages/close_session_page.dart';
import 'features/sales/presentation/pages/payment_sheet.dart';
import 'features/sales/presentation/pages/sale_success_page.dart';
import 'features/sales/presentation/pages/receipt_page.dart';
import 'features/sales/presentation/pages/sales_history_page.dart';
import 'features/sales/presentation/pages/invoice_detail_page.dart';
import 'features/sales/presentation/pages/sales_return_page.dart';
import 'features/auth/presentation/pages/settings_page.dart';

class _GoRouterRefreshStream extends ChangeNotifier {
  String? _lastUid;

  _GoRouterRefreshStream() {
    _lastUid = supabase.auth.currentUser?.id;
    supabase.auth.onAuthStateChange.listen((event) {
      final newUid = event.session?.user.id;
      final eventName = event.event.name;
      if (newUid != _lastUid || eventName == 'SIGNED_OUT') {
        debugPrint('[AUTH-LIFECYCLE] user changed: $_lastUid -> $newUid ($eventName), resetting state');
        _lastUid = newUid;
        BranchRouterState.instance.reset();
        resetUserScopedState();
        Future.microtask(() => notifyListeners());
      } else {
        notifyListeners();
      }
    });
  }
}

String? _redirect(BuildContext context, GoRouterState state) {
  final loc = state.matchedLocation;
  final loggedIn = supabase.auth.currentSession != null;
  final recovery = RecoveryState.instance.stage;

  if (recovery == RecoveryStage.codeVerified) {
    return loc == '/reset' ? null : '/reset';
  }
  if (recovery == RecoveryStage.awaitingCode) {
    return loc == '/otp' ? null : '/otp';
  }

  if (!EnvCheckState.instance.passed) {
    return loc == '/env-check' ? null : '/env-check';
  }

  if (!loggedIn) {
    const authRoutes = {'/login', '/signup', '/otp', '/forgot'};
    return authRoutes.contains(loc) ? null : '/login';
  }

  if (PinLockState.instance.locked) {
    return loc == '/pin-lock' ? null : '/pin-lock';
  }

  if (BranchRouterState.instance.needsSelection) {
    return loc == '/branch-select' ? null : '/branch-select';
  }

  if (!WorkspaceInitState.instance.completed && !MfaState.instance.needsMfa) {
    return loc == '/workspace-init' ? null : '/workspace-init';
  }

  if (MfaState.instance.needsMfa) {
    return loc == '/mfa-challenge' ? null : '/mfa-challenge';
  }

  const waitingRoutes = {
    '/splash', '/env-check', '/login', '/signup', '/otp', '/forgot', '/reset',
    '/branch-select', '/workspace-init', '/pin-lock', '/mfa-challenge',
    '/home',
  };
  if (waitingRoutes.contains(loc)) return '/dashboard';

  return null;
}

final appRouter = GoRouter(
  initialLocation: '/splash',
  refreshListenable: Listenable.merge([
    _GoRouterRefreshStream(),
    RecoveryState.instance,
    BranchRouterState.instance,
    EnvCheckState.instance,
    WorkspaceInitState.instance,
    PinLockState.instance,
    MfaState.instance,
  ]),
  redirect: _redirect,
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashPage(),
    ),
    GoRoute(
      path: '/env-check',
      builder: (context, state) => const EnvironmentCheckScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: '/signup',
      builder: (context, state) => const SignupPage(),
    ),
    GoRoute(
      path: '/otp',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return OtpPage(
          email: extra['email'] as String,
          isRecovery: extra['isRecovery'] as bool,
        );
      },
    ),
    GoRoute(
      path: '/forgot',
      builder: (context, state) => const ForgotPasswordPage(),
    ),
    GoRoute(
      path: '/reset',
      builder: (context, state) => const ResetPasswordPage(),
    ),
    GoRoute(
      path: '/branch-select',
      builder: (context, state) => const BranchSelectPage(),
    ),
    GoRoute(
      path: '/workspace-init',
      builder: (context, state) => const WorkspaceInitScreen(),
    ),
    GoRoute(
      path: '/pin-lock',
      builder: (context, state) => const PinLockScreen(),
    ),
    GoRoute(
      path: '/pin-setup',
      builder: (context, state) => const PinSetupScreen(),
    ),
    GoRoute(
      path: '/devices',
      builder: (context, state) => const DevicesScreen(),
    ),
    GoRoute(
      path: '/security-logs',
      builder: (context, state) => const SecurityLogsScreen(),
    ),
    GoRoute(
      path: '/sessions',
      builder: (context, state) => const SessionsScreen(),
    ),
    GoRoute(
      path: '/mfa-challenge',
      builder: (context, state) => const MfaChallengeScreen(),
    ),
    GoRoute(
      path: '/mfa-enroll',
      builder: (context, state) => const MfaEnrollScreen(),
    ),
    GoRoute(
      path: '/home',
      redirect: (context, state) => '/dashboard',
    ),
    GoRoute(
      path: '/inventory/categories',
      builder: (context, state) => const CategoriesPage(),
    ),
    GoRoute(
      path: '/inventory/categories/create',
      builder: (context, state) => const CategoryFormPage(),
    ),
    GoRoute(
      path: '/inventory/categories/:categoryId',
      builder: (context, state) {
        final id = state.pathParameters['categoryId'];
        return CategoryFormPage(categoryId: id);
      },
    ),
    GoRoute(
      path: '/inventory/brands',
      builder: (context, state) => const BrandsPage(),
    ),
    GoRoute(
      path: '/inventory/brands/create',
      builder: (context, state) => const BrandFormPage(),
    ),
    GoRoute(
      path: '/inventory/brands/:brandId',
      builder: (context, state) {
        final id = state.pathParameters['brandId'];
        return BrandFormPage(brandId: id);
      },
    ),
    GoRoute(
      path: '/inventory/products',
      builder: (context, state) => const ProductsPage(),
    ),
    GoRoute(
      path: '/inventory/products/create',
      builder: (context, state) => const ProductFormPage(),
    ),
    GoRoute(
      path: '/inventory/products/:productId',
      builder: (context, state) {
        final id = state.pathParameters['productId']!;
        return ProductFormPage(productId: id);
      },
    ),
    GoRoute(
      path: '/inventory/barcode-templates',
      builder: (context, state) => const BarcodeTemplatesPage(),
    ),
    GoRoute(
      path: '/inventory/barcode-templates/create',
      builder: (context, state) => const BarcodeTemplateFormPage(),
    ),
    GoRoute(
      path: '/inventory/barcode-templates/:templateId',
      builder: (context, state) {
        final id = state.pathParameters['templateId'];
        return BarcodeTemplateFormPage(templateId: id);
      },
    ),
    GoRoute(
      path: '/inventory/warehouses',
      builder: (context, state) => const WarehousesPage(),
    ),
    GoRoute(
      path: '/inventory/warehouses/create',
      builder: (context, state) => const WarehouseFormPage(),
    ),
    GoRoute(
      path: '/inventory/warehouses/:warehouseId',
      builder: (context, state) {
        final id = state.pathParameters['warehouseId'];
        return WarehouseFormPage(warehouseId: id);
      },
    ),
    GoRoute(
      path: '/inventory/stock',
      builder: (context, state) => const StockLevelsPage(),
    ),
    GoRoute(
      path: '/inventory/stock/movement',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return StockMovementFormPage(productId: extra?['productId'] as String?);
      },
    ),
    GoRoute(
      path: '/inventory/stock/:productId',
      builder: (context, state) {
        final id = state.pathParameters['productId']!;
        return ProductStockDetailPage(productId: id);
      },
    ),
    GoRoute(
      path: '/inventory/adjustments',
      builder: (context, state) => const AdjustmentsPage(),
    ),
    GoRoute(
      path: '/inventory/adjustments/create',
      builder: (context, state) => const AdjustmentFormPage(),
    ),
    GoRoute(
      path: '/inventory/transfers',
      builder: (context, state) => const TransfersPage(),
    ),
    GoRoute(
      path: '/inventory/transfers/create',
      builder: (context, state) => const TransferFormPage(),
    ),
    GoRoute(
      path: '/inventory/transfers/:transferId/receive',
      builder: (context, state) {
        final id = state.pathParameters['transferId']!;
        return TransferReceivePage(transferId: id);
      },
    ),
    GoRoute(
      path: '/inventory/counts',
      builder: (context, state) => const CountsPage(),
    ),
    GoRoute(
      path: '/inventory/counts/:countId',
      builder: (context, state) {
        final id = state.pathParameters['countId']!;
        return CountSessionPage(countId: id);
      },
    ),
    GoRoute(
      path: '/inventory/imei',
      builder: (context, state) => const ImeiLookupPage(),
    ),
    GoRoute(
      path: '/inventory/labels',
      builder: (context, state) {
        final ids = state.extra as List<String>;
        return LabelPrintPage(productIds: ids);
      },
    ),
    GoRoute(
      path: '/inventory/import',
      builder: (context, state) => const ImportProductsPage(),
    ),
    GoRoute(
      path: '/inventory/import-migration',
      builder: (context, state) => const MigrationImportPage(),
    ),
    GoRoute(
      path: '/inventory/notifications',
      builder: (context, state) => const NotificationsPage(),
    ),
    GoRoute(
      path: '/suppliers',
      builder: (context, state) => const SuppliersPage(),
    ),
    GoRoute(
      path: '/suppliers/create',
      builder: (context, state) => const SupplierFormPage(),
    ),
    GoRoute(
      path: '/suppliers/:supplierId',
      builder: (context, state) {
        final id = state.pathParameters['supplierId']!;
        return SupplierDetailPage(supplierId: id);
      },
    ),
    GoRoute(
      path: '/suppliers/:supplierId/edit',
      builder: (context, state) {
        final id = state.pathParameters['supplierId']!;
        return SupplierFormPage(supplierId: id);
      },
    ),
    GoRoute(
      path: '/customers',
      builder: (context, state) => const CustomersPage(),
    ),
    GoRoute(
      path: '/customers/create',
      builder: (context, state) => const CustomerFormPage(),
    ),
    GoRoute(
      path: '/receivables',
      builder: (context, state) => const ReceivablesAgingPage(),
    ),
    GoRoute(
      path: '/customers/:customerId',
      builder: (context, state) =>
          CustomerDetailPage(customerId: state.pathParameters['customerId']!),
    ),
    GoRoute(
      path: '/customers/:customerId/edit',
      builder: (context, state) =>
          CustomerFormPage(customerId: state.pathParameters['customerId']!),
    ),
    GoRoute(
      path: '/customers/:customerId/collect',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return CustomerPaymentPage(
          customerId: state.pathParameters['customerId']!,
          customerName: extra?['customerName'] as String?,
        );
      },
    ),
    GoRoute(
      path: '/repair',
      builder: (context, state) => const RepairKanbanPage(),
    ),
    GoRoute(
      path: '/repair/intake',
      builder: (context, state) => const RepairIntakePage(),
    ),
    GoRoute(
      path: '/repair/workload',
      builder: (context, state) => const TechnicianWorkloadPage(),
    ),
    GoRoute(
      path: '/repair/history',
      builder: (context, state) => const RepairHistoryPage(),
    ),
    GoRoute(
      path: '/repair/:repairId',
      builder: (context, state) =>
          RepairDetailPage(repairId: state.pathParameters['repairId']!),
    ),
    GoRoute(
      path: '/accounting',
      builder: (context, state) => const AccountingHubPage(),
    ),
    GoRoute(
      path: '/accounting/accounts',
      builder: (context, state) => const ChartOfAccountsPage(),
    ),
    GoRoute(
      path: '/accounting/accounts/:id/ledger',
      builder: (context, state) =>
          AccountLedgerPage(accountId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/accounting/journal',
      builder: (context, state) => const JournalEntriesPage(),
    ),
    GoRoute(
      path: '/accounting/journal/:id',
      builder: (context, state) =>
          JournalEntryDetailPage(entryId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/accounting/vouchers',
      builder: (context, state) => const ManualVoucherPage(),
    ),
    GoRoute(
      path: '/accounting/vouchers/create',
      builder: (context, state) => const ManualVoucherPage(),
    ),
    GoRoute(
      path: '/accounting/expenses',
      builder: (context, state) => const ExpensesPage(),
    ),
    GoRoute(
      path: '/accounting/expenses/create',
      builder: (context, state) => const ExpenseFormPage(),
    ),
    GoRoute(
      path: '/accounting/expense-categories',
      builder: (context, state) => const ExpenseCategoriesPage(),
    ),
    GoRoute(
      path: '/accounting/banks',
      builder: (context, state) => const BankAccountsPage(),
    ),
    GoRoute(
      path: '/accounting/banks/create',
      builder: (context, state) => const BankAccountFormPage(),
    ),
    GoRoute(
      path: '/accounting/banks/:id/edit',
      builder: (context, state) =>
          BankAccountFormPage(bankAccountId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/accounting/banks/:id/reconcile',
      builder: (context, state) =>
          BankReconciliationPage(bankAccountId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/accounting/periods',
      builder: (context, state) => const FiscalPeriodsPage(),
    ),
    GoRoute(
      path: '/accounting/tax-rules',
      builder: (context, state) => const TaxRulesPage(),
    ),
    GoRoute(
      path: '/accounting/tax-rules/create',
      builder: (context, state) => const TaxRuleFormPage(),
    ),
    GoRoute(
      path: '/accounting/tax-rules/:id/edit',
      builder: (context, state) =>
          TaxRuleFormPage(taxRuleId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/accounting/reports/trial-balance',
      builder: (context, state) => const TrialBalancePage(),
    ),
    GoRoute(
      path: '/accounting/reports/profit-loss',
      builder: (context, state) => const ProfitLossPage(),
    ),
    GoRoute(
      path: '/accounting/reports/balance-sheet',
      builder: (context, state) => const BalanceSheetPage(),
    ),
    GoRoute(
      path: '/accounting/reports/cash-bank-book',
      builder: (context, state) => const CashBankBookPage(),
    ),
    GoRoute(
      path: '/purchasing/orders',
      builder: (context, state) => const PurchaseOrdersPage(),
    ),
    GoRoute(
      path: '/purchasing/orders/create',
      builder: (context, state) {
        final lines = state.extra
            as List<({String productId, String name, double unitCost})>?;
        return PurchaseOrderFormPage(initialLines: lines);
      },
    ),
    GoRoute(
      path: '/purchasing/orders/:id/edit',
      builder: (context, state) =>
          PurchaseOrderFormPage(poId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/purchasing/orders/:id/receive',
      builder: (context, state) =>
          GrnReceivePage(poId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/purchasing/orders/:id/invoice',
      builder: (context, state) =>
          PurchaseInvoiceMatchPage(poId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/purchasing/orders/:id',
      builder: (context, state) =>
          PurchaseOrderDetailPage(poId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/purchasing/invoices',
      builder: (context, state) => const PurchaseInvoicesPage(),
    ),
    GoRoute(
      path: '/purchasing/invoices/:id',
      builder: (context, state) =>
          PurchaseInvoiceDetailPage(invoiceId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/purchasing/payments/create',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final balance = extra?['balance'];
        return SupplierPaymentPage(
          supplierId: extra?['supplierId'] as String?,
          invoiceId: extra?['invoiceId'] as String?,
          presetAmount: balance is num ? balance.toDouble() : null,
        );
      },
    ),
    GoRoute(
      path: '/purchasing/reorder',
      builder: (context, state) => const ReorderSuggestionsPage(),
    ),
    GoRoute(
      path: '/purchasing/returns',
      builder: (context, state) => const PurchaseReturnsPage(),
    ),
    GoRoute(
      path: '/purchasing/returns/create',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return PurchaseReturnFormPage(
          poId: extra?['poId'] as String,
          grnId: extra?['grnId'] as String?,
          invoiceId: extra?['invoiceId'] as String?,
        );
      },
    ),
    GoRoute(
      path: '/purchasing/returns/:id',
      builder: (context, state) =>
          PurchaseReturnDetailPage(returnId: state.pathParameters['id']!),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          BottomNavShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/dashboard',
              builder: (context, state) => const DashboardPage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/inventory',
              builder: (context, state) => const InventoryHubPage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/purchasing',
              builder: (context, state) => const PurchaseHubPage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/sales',
              redirect: (context, state) => '/sales/pos',
            ),
            GoRoute(
              path: '/sales/pos',
              builder: (context, state) => const PosTerminalPage(),
            ),
            GoRoute(
              path: '/sales/open',
              builder: (context, state) => const OpenSessionPage(),
            ),
            GoRoute(
              path: '/sales/session/close',
              builder: (context, state) => const CloseSessionPage(),
            ),
            GoRoute(
              path: '/sales/payment',
              builder: (context, state) {
                final extra = state.extra as Map<String, dynamic>;
                return PaymentSheet(
                  branchId: extra['branchId'] as String,
                  sessionId: extra['sessionId'] as String?,
                );
              },
            ),
            GoRoute(
              path: '/sales/success',
              builder: (context, state) => const SaleSuccessPage(),
            ),
            GoRoute(
              path: '/sales/receipt',
              builder: (context, state) {
                final invoiceId = state.extra as String;
                return ReceiptPage(invoiceId: invoiceId);
              },
            ),
            GoRoute(
              path: '/sales/history',
              builder: (context, state) => const SalesHistoryPage(),
            ),
            GoRoute(
              path: '/sales/invoice/:invoiceId',
              builder: (context, state) {
                final id = state.pathParameters['invoiceId']!;
                return InvoiceDetailPage(invoiceId: id);
              },
            ),
            GoRoute(
              path: '/sales/return',
              builder: (context, state) => const SalesReturnPage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              builder: (context, state) => const SettingsPage(),
            ),
          ],
        ),
      ],
    ),
  ],
);
