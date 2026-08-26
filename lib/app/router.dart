import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/auth_controller.dart';
import '../features/auth/screens/email_verification_screen.dart';
import '../features/auth/screens/forgot_password_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/reset_password_confirmation_screen.dart';
import '../features/auth/screens/signup_screen.dart';
import '../features/admin/screens/admin_dashboard_screen.dart';
import '../features/auth/screens/splash_screen.dart';
import '../features/employer/screens/employer_dashboard_screen.dart';
import '../features/employer/screens/employer_company_profile_screen.dart';
import '../features/jobs/screens/home_screen.dart';
import '../features/profile/screens/settings_screen.dart';

class AppRoutes {
  static const splash = '/splash';
  static const home = '/';
  static const login = '/login';
  static const signup = '/signup';
  static const forgotPassword = '/forgot-password';
  static const emailVerification = '/verify-email';
  static const employerDashboard = '/employer/dashboard';
  static const employerCompanyProfile = '/employer/company-profile';
  static const employerSettings = '/employer/settings';
  static const adminDashboard = '/admin/dashboard';
  static const resetPassword = '/reset-password';
}

late final GoRouter appRouter;

GoRouter createRouter({String initialLocation = AppRoutes.login}) {
  return GoRouter(
    initialLocation: initialLocation,
    refreshListenable: authNotifier,
    redirect: (BuildContext context, GoRouterState state) {
      // Wait for auth initialization
      if (!authNotifier.initialized) {
        debugPrint('Router: Auth not initialized yet, no redirect');
        return null;
      }

      final isAuth = authNotifier.isAuthenticated;
      final currentLocation = state.uri.path;
      final isResetRoute = currentLocation == AppRoutes.resetPassword;

      debugPrint(
        'Router redirect: isAuth=$isAuth, location=$currentLocation, '
        'isEmployer=${authNotifier.isEmployer}, '
        'isJobSeeker=${authNotifier.isJobSeeker}, '
        'isAdmin=${authNotifier.isAdmin}',
      );

      // Public auth routes (accessible only when NOT authenticated)
      final unauthPublicRoutes = [
        AppRoutes.login,
        AppRoutes.signup,
        AppRoutes.forgotPassword,
        AppRoutes.emailVerification,
      ];

      // UNAUTHENTICATED USER
      if (!isAuth) {
        // Allow public auth routes
        if (unauthPublicRoutes.contains(currentLocation)) {
          debugPrint('Router: Unauthenticated on public route, no redirect');
          return null;
        }
        // Allow password reset
        if (isResetRoute) {
          debugPrint('Router: Unauthenticated on reset route, no redirect');
          return null;
        }
        // Redirect to login for any other route
        debugPrint(
          'Router: Unauthenticated on private route, redirecting to login',
        );
        return AppRoutes.login;
      }

      // AUTHENTICATED USER
      // Allow authenticated users to remain on the login or signup pages
      // so launching the app or tapping "Sign up" doesn't silently
      // redirect to dashboards. Users should explicitly authenticate
      // before being taken to their dashboard.
      if (currentLocation == AppRoutes.login ||
          currentLocation == AppRoutes.signup) {
        debugPrint(
          'Router: Authenticated but on login/signup route — allowing access',
        );
        return null;
      }

      // Redirect other public auth routes (signup, forgot, verify)
      if (unauthPublicRoutes.contains(currentLocation)) {
        final destination = authNotifier.isEmployer
            ? AppRoutes.employerDashboard
            : authNotifier.isAdmin
            ? AppRoutes.adminDashboard
            : AppRoutes.home;
        debugPrint(
          'Router: Authenticated on public route, redirecting to $destination',
        );
        return destination;
      }

      // Only enforce dashboard redirects if role is known
      if (authNotifier.roleKnown) {
        // Enforce employer dashboard
        if (authNotifier.isEmployer) {
          if (currentLocation != AppRoutes.employerDashboard &&
              currentLocation != AppRoutes.employerCompanyProfile &&
              currentLocation != AppRoutes.employerSettings &&
              !isResetRoute) {
            debugPrint(
              'Router: Employer not on employer dashboard, redirecting',
            );
            return AppRoutes.employerDashboard;
          }
        }

        // Enforce job seeker home
        if (authNotifier.isJobSeeker) {
          if (currentLocation != AppRoutes.home && !isResetRoute) {
            debugPrint('Router: Job seeker not on home, redirecting');
            return AppRoutes.home;
          }
        }

        if (authNotifier.isAdmin) {
          if (currentLocation != AppRoutes.adminDashboard && !isResetRoute) {
            debugPrint('Router: Admin not on admin dashboard, redirecting');
            return AppRoutes.adminDashboard;
          }
        }
      } else {
        // Role is unknown — do not auto-redirect to dashboards. Let the
        // app surface login/signup/profile completion flows.
        debugPrint('Router: role unknown, skipping dashboard redirects');
      }

      debugPrint('Router: No redirect needed');
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.signup,
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.emailVerification,
        builder: (context, state) => const EmailVerificationScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.employerDashboard,
        builder: (context, state) => const EmployerDashboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.employerCompanyProfile,
        builder: (context, state) => const EmployerCompanyProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.employerSettings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminDashboard,
        builder: (context, state) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.resetPassword,
        name: 'reset-password',
        builder: (context, state) {
          return const ResetPasswordConfirmationScreen();
        },
      ),
    ],
  );
}
