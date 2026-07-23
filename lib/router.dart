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
import 'features/dashboard/presentation/pages/dashboard_page.dart';
import 'features/dashboard/presentation/pages/drilldown_page.dart';
import 'features/dashboard/domain/entities/drilldown.dart';
import 'features/reporting/presentation/pages/reports_hub_page.dart';
import 'features/reporting/presentation/pages/inventory_reporting_page.dart';
import 'features/reporting/presentation/pages/product_performance_page.dart';
import 'features/reporting/presentation/pages/customer_reporting_page.dart';
import 'features/reporting/presentation/pages/supplier_reporting_page.dart';
import 'features/reporting/presentation/pages/trend_analysis_page.dart';
import 'features/reporting/presentation/pages/scheduled_reports_page.dart';
import 'features/reporting/presentation/pages/smart_insights_page.dart';
import 'features/reporting/presentation/pages/forecasting_page.dart';
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
import 'features/hr/domain/entities/employee.dart';
import 'features/hr/presentation/pages/employees_page.dart';
import 'features/hr/presentation/pages/employee_form_page.dart';
import 'features/hr/presentation/pages/employee_profile_page.dart';
import 'features/hr/presentation/pages/shifts_page.dart';
import 'features/hr/presentation/pages/attendance_grid_page.dart';
import 'features/hr/presentation/pages/leaves_page.dart';
import 'features/hr/presentation/pages/clock_in_out_page.dart';
import 'features/hr/presentation/pages/payroll_runs_page.dart';
import 'features/hr/presentation/pages/payroll_run_detail_page.dart';
import 'features/sync/presentation/pages/sync_exception_centre_page.dart';
import 'features/approvals/presentation/pages/pending_approvals_page.dart';
import 'features/approvals/presentation/pages/approval_detail_page.dart';
import 'features/approvals/presentation/pages/approval_history_page.dart';
import 'features/approvals/presentation/pages/approval_workflows_page.dart';
import 'features/staff/presentation/pages/staff_invites_page.dart';
import 'features/staff/presentation/pages/staff_invite_create_page.dart';
import 'features/staff/presentation/pages/invite_qr_page.dart';
import 'features/staff/presentation/pages/roles_page.dart';
import 'features/staff/presentation/pages/role_form_page.dart';
import 'features/staff/presentation/pages/user_role_page.dart';
import 'features/staff/presentation/pages/join_scan_page.dart';
import 'features/staff/presentation/pages/join_redeem_page.dart';
import 'features/staff/domain/entities/staff_entities.dart';
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
import 'features/notifications/presentation/pages/notification_settings_page.dart';
import 'features/notifications/presentation/pages/templates_admin_page.dart';
import 'features/notifications/presentation/pages/bulk_communication_page.dart';
import 'features/notifications/presentation/pages/communication_logs_page.dart';
import 'core/widgets/permission_gate.dart';
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
import 'features/settings/presentation/pages/settings_hub_page.dart';
import 'features/settings/presentation/pages/business_settings_page.dart';
import 'features/settings/presentation/pages/branches_page.dart';
import 'features/settings/presentation/pages/payment_methods_page.dart';
import 'features/settings/presentation/pages/number_series_page.dart';
import 'features/settings/presentation/pages/preferences_page.dart';

class _GoRouterRefreshStream extends ChangeNotifier {
  String? _lastUid;

  _GoRouterRefreshStream() {
    _lastUid = supabase.auth.currentUser?.id;
    supabase.auth.onAuthStateChange.listen((event) {
      final newUid = event.session?.user.id;
      final eventName = event.event.name;
      if (newUid != _lastUid || eventName == 'SIGNED_OUT') {
        debugPrint('[AUTH-LIFECYCLE] user changed: $_lastUid -> $newUid ($eventName)');
        _lastUid = newUid;
        // A password-recovery OTP verification signs the user in transiently —
        // that session is a legitimate step of the recovery flow, NOT a
        // cross-user login. Resetting user-scoped state here would wipe
        // RecoveryState.codeVerified and drop the user onto /dashboard instead
        // of /reset. Skip the reset while a recovery is in progress.
        if (!RecoveryState.instance.isRecovering) {
          debugPrint('[AUTH-LIFECYCLE] resetting user-scoped state');
          BranchRouterState.instance.reset();
          resetUserScopedState();
        }
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

  // Brand splash on cold start — hold on /splash until it has shown once, then
  // fall through to the normal gates. A live recovery deep-link skips it.
  if (!SplashState.instance.shown && recovery == RecoveryStage.none) {
    return loc == '/splash' ? null : '/splash';
  }

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
    const authRoutes = {'/login', '/signup', '/otp', '/forgot', '/join/scan', '/join/redeem'};
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

/// Cross-fade page for screens that share persistent chrome. The auth hero
/// screens all draw the same left branding panel and the sales screens all draw
/// the same rail and header, so fading (instead of the default slide) keeps that
/// chrome reading as static while only the changing pane cross-fades.
CustomTransitionPage<void> _fadePage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        child: child,
      );
    },
    child: child,
  );
}

final appRouter = GoRouter(
  initialLocation: '/splash',
  refreshListenable: Listenable.merge([
    _GoRouterRefreshStream(),
    RecoveryState.instance,
    BranchRouterState.instance,
    SplashState.instance,
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
      pageBuilder: (context, state) =>
          _fadePage(state, const EnvironmentCheckScreen()),
    ),
    GoRoute(
      path: '/login',
      pageBuilder: (context, state) => _fadePage(state, const LoginPage()),
    ),
    GoRoute(
      path: '/signup',
      pageBuilder: (context, state) =>
          _fadePage(state, const SignupPage()),
    ),
    GoRoute(
      path: '/otp',
      pageBuilder: (context, state) {
        // Degrade gracefully if reached without the expected payload
        // (deep-link / malformed push) instead of throwing on the cast.
        final extra = state.extra;
        if (extra is! Map || extra['email'] is! String) {
          return _fadePage(state, const LoginPage());
        }
        return _fadePage(
          state,
          OtpPage(
            email: extra['email'] as String,
            isRecovery: extra['isRecovery'] as bool? ?? false,
          ),
        );
      },
    ),
    GoRoute(
      path: '/forgot',
      pageBuilder: (context, state) =>
          _fadePage(state, const ForgotPasswordPage()),
    ),
    GoRoute(
      path: '/reset',
      pageBuilder: (context, state) =>
          _fadePage(state, const ResetPasswordPage()),
    ),
    GoRoute(
      path: '/branch-select',
      pageBuilder: (context, state) =>
          _fadePage(state, const BranchSelectPage()),
    ),
    GoRoute(
      path: '/workspace-init',
      pageBuilder: (context, state) =>
          _fadePage(state, const WorkspaceInitScreen()),
    ),
    GoRoute(
      path: '/pin-lock',
      pageBuilder: (context, state) =>
          _fadePage(state, const PinLockScreen()),
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
      pageBuilder: (context, state) =>
          _fadePage(state, const MfaChallengeScreen()),
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
      path: '/notifications',
      builder: (context, state) => const NotificationsPage(),
    ),
    GoRoute(
      path: '/notifications/settings',
      builder: (context, state) => const NotificationSettingsPage(),
    ),
    GoRoute(
      path: '/notifications/templates',
      builder: (context, state) => const PermissionGate(
        module: 'notifications',
        action: 'update',
        fallback: _NoAccessScaffold(),
        child: TemplatesAdminPage(),
      ),
    ),
    GoRoute(
      path: '/notifications/bulk',
      builder: (context, state) => const PermissionGate(
        module: 'notifications',
        action: 'create',
        fallback: _NoAccessScaffold(),
        child: BulkCommunicationPage(),
      ),
    ),
    GoRoute(
      path: '/notifications/logs',
      builder: (context, state) => const PermissionGate(
        module: 'notifications',
        action: 'read',
        fallback: _NoAccessScaffold(),
        child: CommunicationLogsPage(),
      ),
    ),
    // Legacy entry — kept working, redirects to the canonical route.
    GoRoute(
      path: '/inventory/notifications',
      redirect: (context, state) => '/notifications',
    ),
    // Customers (CRM) moved INSIDE the nav shell as its own branch — see the
    // StatefulShellBranch below. /customers*, /receivables now carry the rail.
    // HR moved INSIDE the nav shell as its own branch (index 10) — see the
    // StatefulShellBranch below. All /hr* routes now carry the rail.
    GoRoute(
      path: '/sync/exceptions',
      builder: (context, state) => const SyncExceptionCentrePage(),
    ),
    GoRoute(
      path: '/staff',
      builder: (context, state) => const StaffInvitesPage(),
    ),
    GoRoute(
      path: '/staff/invite',
      builder: (context, state) {
        final m = state.extra as Map<String, dynamic>?;
        return StaffInviteCreatePage(
          employeeId: m?['employeeId'] as String?,
          prefillName: m?['name'] as String?,
          prefillEmail: m?['email'] as String?,
        );
      },
    ),
    GoRoute(
      path: '/staff/invite/:id/qr',
      builder: (context, state) => InviteQrPage(
        inviteId: state.pathParameters['id']!,
        invite: state.extra as CreatedInvite?,
      ),
    ),
    GoRoute(
      path: '/settings/roles',
      builder: (context, state) => const RolesPage(),
    ),
    GoRoute(
      path: '/settings/roles/new',
      builder: (context, state) => const RoleFormPage(),
    ),
    GoRoute(
      path: '/settings/roles/:id',
      builder: (context, state) =>
          RoleFormPage(role: state.extra as TenantRole?),
    ),
    GoRoute(
      path: '/settings/users/:id/role',
      builder: (context, state) =>
          UserRolePage(userId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/join/scan',
      builder: (context, state) => const JoinScanPage(),
    ),
    GoRoute(
      path: '/join/redeem',
      builder: (context, state) {
        final args = state.extra as ({String token, InviteValidation validation});
        return JoinRedeemPage(token: args.token, validation: args.validation);
      },
    ),
    GoRoute(
      path: '/dashboard/drilldown',
      builder: (context, state) {
        final nav = state.extra as ({DrilldownArgs args, String title});
        return DrilldownPage(args: nav.args, title: nav.title);
      },
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
    // Leaf detail page reached from several branches (sales history, dashboard
    // recent-sale + drilldown, repair). Kept top-level, NOT inside the shell:
    // go_router cannot `push` a StatefulShellRoute descendant from a page above
    // the shell (e.g. the drilldown) without duplicating the shell page key
    // ('!keyReservation.contains(key)' assertion). A root page pushes cleanly
    // from anywhere and pops back to its origin.
    GoRoute(
      path: '/sales/invoice/:invoiceId',
      pageBuilder: (context, state) {
        final id = state.pathParameters['invoiceId']!;
        // Same cross-fade as the rest of sales; state.pageKey is what the
        // default page would have used, so the key reservation above is
        // unaffected.
        return _fadePage(state, InvoiceDetailPage(invoiceId: id));
      },
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
            // Suppliers lives INSIDE the purchasing branch so it keeps the
            // rail/bottom bar, as the design draws it. Same chrome on every
            // one of these, so they cross-fade rather than slide.
            GoRoute(
              path: '/suppliers',
              pageBuilder: (context, state) =>
                  _fadePage(state, const SuppliersPage()),
            ),
            GoRoute(
              path: '/suppliers/create',
              pageBuilder: (context, state) =>
                  _fadePage(state, const SupplierFormPage()),
            ),
            GoRoute(
              path: '/suppliers/:supplierId',
              pageBuilder: (context, state) {
                final id = state.pathParameters['supplierId']!;
                return _fadePage(state, SupplierDetailPage(supplierId: id));
              },
            ),
            GoRoute(
              path: '/suppliers/:supplierId/edit',
              pageBuilder: (context, state) {
                final id = state.pathParameters['supplierId']!;
                return _fadePage(state, SupplierFormPage(supplierId: id));
              },
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/sales',
              redirect: (context, state) => '/sales/pos',
            ),
            // Every sales screen keeps the same rail and header, so these all
            // cross-fade rather than slide — otherwise the static chrome
            // appears to travel with the pane that is actually changing.
            GoRoute(
              path: '/sales/pos',
              pageBuilder: (context, state) =>
                  _fadePage(state, const PosTerminalPage()),
            ),
            GoRoute(
              path: '/sales/open',
              pageBuilder: (context, state) =>
                  _fadePage(state, const OpenSessionPage()),
            ),
            GoRoute(
              path: '/sales/session/close',
              pageBuilder: (context, state) =>
                  _fadePage(state, const CloseSessionPage()),
            ),
            GoRoute(
              path: '/sales/payment',
              pageBuilder: (context, state) {
                final extra = state.extra as Map<String, dynamic>;
                return _fadePage(
                  state,
                  PaymentSheet(
                    branchId: extra['branchId'] as String,
                    sessionId: extra['sessionId'] as String?,
                  ),
                );
              },
            ),
            GoRoute(
              path: '/sales/success',
              pageBuilder: (context, state) =>
                  _fadePage(state, const SaleSuccessPage()),
            ),
            GoRoute(
              path: '/sales/receipt',
              pageBuilder: (context, state) {
                final invoiceId = state.extra as String;
                return _fadePage(state, ReceiptPage(invoiceId: invoiceId));
              },
            ),
            GoRoute(
              path: '/sales/history',
              pageBuilder: (context, state) =>
                  _fadePage(state, const SalesHistoryPage()),
            ),
            GoRoute(
              path: '/sales/return',
              pageBuilder: (context, state) =>
                  _fadePage(state, const SalesReturnPage()),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              builder: (context, state) => const SettingsHubPage(),
            ),
            // The settings detail screens live INSIDE the branch so they keep
            // the rail/bottom bar, as the design draws them. Same chrome on
            // every one of them, so they cross-fade rather than slide.
            GoRoute(
              path: '/settings/profile',
              pageBuilder: (context, state) =>
                  _fadePage(state, const SettingsPage()),
            ),
            GoRoute(
              path: '/settings/business',
              pageBuilder: (context, state) =>
                  _fadePage(state, const BusinessSettingsPage()),
            ),
            GoRoute(
              path: '/settings/branches',
              pageBuilder: (context, state) =>
                  _fadePage(state, const BranchesPage()),
            ),
            GoRoute(
              path: '/settings/payment-methods',
              pageBuilder: (context, state) =>
                  _fadePage(state, const PaymentMethodsPage()),
            ),
            GoRoute(
              path: '/settings/number-series',
              pageBuilder: (context, state) =>
                  _fadePage(state, const NumberSeriesPage()),
            ),
            GoRoute(
              path: '/settings/preferences',
              pageBuilder: (context, state) =>
                  _fadePage(state, const PreferencesPage()),
            ),
            GoRoute(
              path: '/settings/import-migration',
              pageBuilder: (context, state) =>
                  _fadePage(state, const MigrationImportPage()),
            ),
          ],
        ),
        // Repair is appended last so the branch indices above never shift.
        // Every repair screen keeps the same rail and header, so these
        // cross-fade rather than slide, exactly like the sales branch.
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/repair',
              pageBuilder: (context, state) =>
                  _fadePage(state, const RepairKanbanPage()),
            ),
            GoRoute(
              path: '/repair/intake',
              pageBuilder: (context, state) =>
                  _fadePage(state, const RepairIntakePage()),
            ),
            GoRoute(
              path: '/repair/workload',
              pageBuilder: (context, state) =>
                  _fadePage(state, const TechnicianWorkloadPage()),
            ),
            GoRoute(
              path: '/repair/history',
              pageBuilder: (context, state) =>
                  _fadePage(state, const RepairHistoryPage()),
            ),
            // Declared last so the three literal sub-paths above keep winning.
            GoRoute(
              path: '/repair/:repairId',
              pageBuilder: (context, state) => _fadePage(
                state,
                RepairDetailPage(repairId: state.pathParameters['repairId']!),
              ),
            ),
          ],
        ),
        // Customers (CRM) — appended LAST as branch index 6 so branches 0–5
        // never shift. Same rail/header on every screen, so they cross-fade.
        // /customers/create is declared before /customers/:customerId so the
        // literal path keeps winning; edit/collect are pushed from the detail.
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/customers',
              pageBuilder: (context, state) =>
                  _fadePage(state, const CustomersPage()),
            ),
            GoRoute(
              path: '/customers/create',
              pageBuilder: (context, state) =>
                  _fadePage(state, const CustomerFormPage()),
            ),
            GoRoute(
              path: '/receivables',
              pageBuilder: (context, state) =>
                  _fadePage(state, const ReceivablesAgingPage()),
            ),
            GoRoute(
              path: '/customers/:customerId',
              pageBuilder: (context, state) => _fadePage(
                state,
                CustomerDetailPage(
                  customerId: state.pathParameters['customerId']!,
                ),
              ),
            ),
            GoRoute(
              path: '/customers/:customerId/edit',
              pageBuilder: (context, state) => _fadePage(
                state,
                CustomerFormPage(
                  customerId: state.pathParameters['customerId']!,
                ),
              ),
            ),
            GoRoute(
              path: '/customers/:customerId/collect',
              pageBuilder: (context, state) {
                final extra = state.extra as Map<String, dynamic>?;
                return _fadePage(
                  state,
                  CustomerPaymentPage(
                    customerId: state.pathParameters['customerId']!,
                    customerName: extra?['customerName'] as String?,
                  ),
                );
              },
            ),
          ],
        ),
        // Reporting lives INSIDE its own branch (index 7) so it carries the
        // nav rail/bottom bar, per the design. The hub is the branch root; the
        // 8 sub-reports are pushed on top of it and pop back via their
        // AppDetailScaffold back button. Same chrome, so they cross-fade.
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/reports',
              pageBuilder: (context, state) =>
                  _fadePage(state, const ReportsHubPage()),
            ),
            GoRoute(
              path: '/reports/inventory',
              pageBuilder: (context, state) =>
                  _fadePage(state, const InventoryReportingPage()),
            ),
            GoRoute(
              path: '/reports/products',
              pageBuilder: (context, state) =>
                  _fadePage(state, const ProductPerformancePage()),
            ),
            GoRoute(
              path: '/reports/customers',
              pageBuilder: (context, state) =>
                  _fadePage(state, const CustomerReportingPage()),
            ),
            GoRoute(
              path: '/reports/suppliers',
              pageBuilder: (context, state) =>
                  _fadePage(state, const SupplierReportingPage()),
            ),
            GoRoute(
              path: '/reports/trends',
              pageBuilder: (context, state) =>
                  _fadePage(state, const TrendAnalysisPage()),
            ),
            GoRoute(
              path: '/reports/schedules',
              pageBuilder: (context, state) =>
                  _fadePage(state, const ScheduledReportsPage()),
            ),
            GoRoute(
              path: '/reports/insights',
              pageBuilder: (context, state) =>
                  _fadePage(state, const SmartInsightsPage()),
            ),
            GoRoute(
              path: '/reports/forecast',
              pageBuilder: (context, state) =>
                  _fadePage(state, const ForecastingPage()),
            ),
          ],
        ),
        // Accounting lives INSIDE its own branch (index 8, appended after
        // reporting=7 so no earlier index shifts) so it carries the nav rail /
        // bottom bar, per the design. The hub is the branch root; the 18
        // sub-pages are pushed on top and pop back via their AppDetailScaffold
        // back button. Same chrome, so they cross-fade.
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/accounting',
              pageBuilder: (context, state) =>
                  _fadePage(state, const AccountingHubPage()),
            ),
            GoRoute(
              path: '/accounting/accounts',
              pageBuilder: (context, state) =>
                  _fadePage(state, const ChartOfAccountsPage()),
            ),
            GoRoute(
              path: '/accounting/accounts/:id/ledger',
              pageBuilder: (context, state) => _fadePage(
                  state, AccountLedgerPage(accountId: state.pathParameters['id']!)),
            ),
            GoRoute(
              path: '/accounting/journal',
              pageBuilder: (context, state) =>
                  _fadePage(state, const JournalEntriesPage()),
            ),
            GoRoute(
              path: '/accounting/journal/:id',
              pageBuilder: (context, state) => _fadePage(state,
                  JournalEntryDetailPage(entryId: state.pathParameters['id']!)),
            ),
            GoRoute(
              path: '/accounting/vouchers',
              pageBuilder: (context, state) =>
                  _fadePage(state, const ManualVoucherPage()),
            ),
            GoRoute(
              path: '/accounting/vouchers/create',
              pageBuilder: (context, state) =>
                  _fadePage(state, const ManualVoucherPage()),
            ),
            GoRoute(
              path: '/accounting/expenses',
              pageBuilder: (context, state) =>
                  _fadePage(state, const ExpensesPage()),
            ),
            GoRoute(
              path: '/accounting/expenses/create',
              pageBuilder: (context, state) =>
                  _fadePage(state, const ExpenseFormPage()),
            ),
            GoRoute(
              path: '/accounting/expense-categories',
              pageBuilder: (context, state) =>
                  _fadePage(state, const ExpenseCategoriesPage()),
            ),
            GoRoute(
              path: '/accounting/banks',
              pageBuilder: (context, state) =>
                  _fadePage(state, const BankAccountsPage()),
            ),
            GoRoute(
              path: '/accounting/banks/create',
              pageBuilder: (context, state) =>
                  _fadePage(state, const BankAccountFormPage()),
            ),
            GoRoute(
              path: '/accounting/banks/:id/edit',
              pageBuilder: (context, state) => _fadePage(state,
                  BankAccountFormPage(bankAccountId: state.pathParameters['id']!)),
            ),
            GoRoute(
              path: '/accounting/banks/:id/reconcile',
              pageBuilder: (context, state) => _fadePage(
                  state,
                  BankReconciliationPage(
                      bankAccountId: state.pathParameters['id']!)),
            ),
            GoRoute(
              path: '/accounting/periods',
              pageBuilder: (context, state) =>
                  _fadePage(state, const FiscalPeriodsPage()),
            ),
            GoRoute(
              path: '/accounting/tax-rules',
              pageBuilder: (context, state) =>
                  _fadePage(state, const TaxRulesPage()),
            ),
            GoRoute(
              path: '/accounting/tax-rules/create',
              pageBuilder: (context, state) =>
                  _fadePage(state, const TaxRuleFormPage()),
            ),
            GoRoute(
              path: '/accounting/tax-rules/:id/edit',
              pageBuilder: (context, state) => _fadePage(
                  state, TaxRuleFormPage(taxRuleId: state.pathParameters['id']!)),
            ),
            GoRoute(
              path: '/accounting/reports/trial-balance',
              pageBuilder: (context, state) =>
                  _fadePage(state, const TrialBalancePage()),
            ),
            GoRoute(
              path: '/accounting/reports/profit-loss',
              pageBuilder: (context, state) =>
                  _fadePage(state, const ProfitLossPage()),
            ),
            GoRoute(
              path: '/accounting/reports/balance-sheet',
              pageBuilder: (context, state) =>
                  _fadePage(state, const BalanceSheetPage()),
            ),
            GoRoute(
              path: '/accounting/reports/cash-bank-book',
              pageBuilder: (context, state) =>
                  _fadePage(state, const CashBankBookPage()),
            ),
          ],
        ),

        // ── Approvals (branch 9) ── promoted from top-level routes so the rail
        // carries an Approvals tab. Pending hub is the branch root (no back);
        // history/workflows/detail are pushed on top and pop back via their
        // AppDetailScaffold back button. Same chrome, so they cross-fade.
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/approvals',
              pageBuilder: (context, state) =>
                  _fadePage(state, const PendingApprovalsPage()),
            ),
            GoRoute(
              path: '/approvals/history',
              pageBuilder: (context, state) =>
                  _fadePage(state, const ApprovalHistoryPage()),
            ),
            GoRoute(
              path: '/approvals/workflows',
              pageBuilder: (context, state) =>
                  _fadePage(state, const ApprovalWorkflowsPage()),
            ),
            GoRoute(
              path: '/approvals/:id',
              pageBuilder: (context, state) => _fadePage(
                  state,
                  ApprovalDetailPage(requestId: state.pathParameters['id']!)),
            ),
          ],
        ),
        // HR (branch index 10). Employees / Attendance / Leaves / Payroll are
        // the rail destinations; Shifts, Clock and the employee/payroll detail
        // screens are push drill-downs within the branch. Order keeps
        // /hr/employees/new before /hr/employees/:id and /hr/payroll/:id after
        // /hr/payroll so neither is swallowed.
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/hr',
              pageBuilder: (context, state) =>
                  _fadePage(state, const EmployeesPage()),
            ),
            GoRoute(
              path: '/hr/attendance',
              pageBuilder: (context, state) =>
                  _fadePage(state, const AttendanceGridPage()),
            ),
            GoRoute(
              path: '/hr/leaves',
              pageBuilder: (context, state) =>
                  _fadePage(state, const LeavesPage()),
            ),
            GoRoute(
              path: '/hr/payroll',
              pageBuilder: (context, state) =>
                  _fadePage(state, const PayrollRunsPage()),
            ),
            GoRoute(
              path: '/hr/payroll/:id',
              pageBuilder: (context, state) => _fadePage(
                  state,
                  PayrollRunDetailPage(runId: state.pathParameters['id']!)),
            ),
            GoRoute(
              path: '/hr/shifts',
              pageBuilder: (context, state) =>
                  _fadePage(state, const ShiftsPage()),
            ),
            GoRoute(
              path: '/hr/clock',
              pageBuilder: (context, state) =>
                  _fadePage(state, const ClockInOutPage()),
            ),
            GoRoute(
              path: '/hr/employees/new',
              pageBuilder: (context, state) =>
                  _fadePage(state, const EmployeeFormPage()),
            ),
            GoRoute(
              path: '/hr/employees/:id/edit',
              pageBuilder: (context, state) => _fadePage(
                  state, EmployeeFormPage(employee: state.extra as Employee?)),
            ),
            GoRoute(
              path: '/hr/employees/:id',
              pageBuilder: (context, state) => _fadePage(state,
                  EmployeeProfilePage(employeeId: state.pathParameters['id']!)),
            ),
          ],
        ),
      ],
    ),
  ],
);

class _NoAccessScaffold extends StatelessWidget {
  const _NoAccessScaffold();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('No access')),
    );
  }
}
