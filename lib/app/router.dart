import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/signup_screen.dart';
import '../features/auth/screens/reset_password_confirmation_screen.dart';
import '../features/auth/screens/splash_screen.dart';
import '../features/jobs/screens/home_screen.dart';
import '../features/employer/screens/post_job_screen.dart';
import '../features/employer/screens/my_jobs_screen.dart';

class AppRoutes {
  static const splash = '/splash';
  static const home = '/';
  static const login = '/login';
  static const signup = '/signup';
  static const resetPassword = '/reset-password';
}

class AuthNotifier extends ChangeNotifier {
  bool _isPasswordRecovery = false;
  bool get isPasswordRecovery => _isPasswordRecovery;

  AuthNotifier() {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      debugPrint('🔐 AuthNotifier event: $event');

      if (event == AuthChangeEvent.passwordRecovery) {
        debugPrint('🔐 PASSWORD RECOVERY EVENT DETECTED!');
        // FIX: User tapped the reset link — redirect to reset screen
        _isPasswordRecovery = true;
        notifyListeners();
      } else if (event == AuthChangeEvent.userUpdated) {
        debugPrint('🔐 User updated event');
        // Password updated successfully
        _isPasswordRecovery = false;
        notifyListeners();
      } else if (event == AuthChangeEvent.signedOut) {
        debugPrint('🔐 Signed out event');
        _isPasswordRecovery = false;
        notifyListeners();
      } else {
        debugPrint('🔐 Other auth event');
        notifyListeners();
      }
    });
  }

  void clearPasswordRecovery() {
    _isPasswordRecovery = false;
    notifyListeners();
  }

  void setPasswordRecoveryFromLink(Uri uri) {
    if (uri.path == AppRoutes.resetPassword ||
        uri.host == 'reset-password' ||
        uri.queryParameters['type'] == 'recovery' ||
        uri.path.contains('/auth/v1/verify')) {
      if (!_isPasswordRecovery) {
        _isPasswordRecovery = true;
        notifyListeners();
      }
    }
  }
}

final authNotifier = AuthNotifier();

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.splash,
  refreshListenable: authNotifier,
  redirect: (context, state) {
    final session = Supabase.instance.client.auth.currentSession;
    final isPasswordRecovery = authNotifier.isPasswordRecovery;
    final currentPath = state.uri.path;

    debugPrint(
      '🔍 GoRouter redirect: path=$currentPath recovery=$isPasswordRecovery session=${session != null}',
    );
    debugPrint('🔍 Full URI: ${state.uri}');

    // Priority 1: If password recovery event fired and we're not already there
    if (isPasswordRecovery && currentPath != AppRoutes.resetPassword) {
      debugPrint('✅ Redirecting to reset password screen');
      return AppRoutes.resetPassword;
    }

    // Splash handles its own navigation
    if (currentPath == AppRoutes.splash) {
      return null;
    }

    // Priority 2: If user has active session, go to home; otherwise stay on login/auth pages
    if (session != null &&
        (currentPath == AppRoutes.login || currentPath == AppRoutes.signup)) {
      return AppRoutes.home;
    }
    if (session == null && currentPath == AppRoutes.home) {
      return AppRoutes.login;
    }

    return null;
  },
  routes: [
    GoRoute(
      path: AppRoutes.splash,
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: AppRoutes.home,
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/employer/post-job',
      builder: (context, state) => const PostJobScreen(),
    ),
    GoRoute(
      path: '/employer/my-postings',
      builder: (context, state) => const MyJobsScreen(),
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
      path: AppRoutes.resetPassword,
      name: 'reset-password',
      builder: (context, state) => const ResetPasswordConfirmationScreen(),
    ),
  ],
);
