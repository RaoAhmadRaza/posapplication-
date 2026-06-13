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
import 'features/inventory/presentation/pages/products_page.dart';
import 'features/inventory/presentation/pages/product_form_page.dart';
import 'features/inventory/presentation/pages/barcode_templates_page.dart';
import 'features/inventory/presentation/pages/barcode_template_form_page.dart';
import 'features/inventory/presentation/pages/warehouses_page.dart';
import 'features/inventory/presentation/pages/warehouse_form_page.dart';
import 'features/inventory/presentation/pages/stock_levels_page.dart';
import 'features/inventory/presentation/pages/product_stock_detail_page.dart';
import 'features/inventory/presentation/pages/stock_movement_form_page.dart';
import 'features/auth/presentation/pages/sale_page.dart';
import 'features/auth/presentation/pages/settings_page.dart';

class _GoRouterRefreshStream extends ChangeNotifier {
  _GoRouterRefreshStream() {
    supabase.auth.onAuthStateChange.listen((_) {
      notifyListeners();
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
              path: '/sale',
              builder: (context, state) => const SalePage(),
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
