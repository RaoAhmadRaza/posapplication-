import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'core/error/auth_failure.dart';
import 'core/supabase.dart';
import 'features/auth/presentation/pages/splash_page.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/auth/presentation/pages/signup_page.dart';
import 'features/auth/presentation/pages/otp_page.dart';
import 'features/auth/presentation/pages/forgot_password_page.dart';
import 'features/auth/presentation/pages/reset_password_page.dart';
import 'features/auth/presentation/pages/home_page.dart';

class _GoRouterRefreshStream extends ChangeNotifier {
  _GoRouterRefreshStream() {
    supabase.auth.onAuthStateChange.listen((_) {
      notifyListeners();
    });
  }
}

String? _redirect(BuildContext context, GoRouterState state) {
  final loggedIn = supabase.auth.currentSession != null;
  final recovering = RecoveryState.instance.isRecovering;
  final loc = state.matchedLocation;
  const authRoutes = {'/login', '/signup', '/otp', '/forgot'};

  if (recovering) return loc == '/reset' ? null : '/reset';

  if (!loggedIn) return authRoutes.contains(loc) ? null : '/login';

  if (loc == '/splash' || authRoutes.contains(loc) || loc == '/reset') {
    return '/home';
  }

  return null;
}

final appRouter = GoRouter(
  initialLocation: '/splash',
  refreshListenable: Listenable.merge([
    _GoRouterRefreshStream(),
    RecoveryState.instance,
  ]),
  redirect: _redirect,
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashPage(),
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
      path: '/home',
      builder: (context, state) => const HomePage(),
    ),
  ],
);
