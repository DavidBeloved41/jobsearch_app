import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../features/auth/screens/splash_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/signup_screen.dart';
import '../features/jobs/screens/home_screen.dart';

class AppRoutes {
  static const splash = '/';
  static const login = '/login';
  static const signup = '/signup';
  static const home = '/home';
}

// Auth state notifier that listens to Supabase auth changes
class AuthNotifier extends ChangeNotifier {
  AuthNotifier() {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      notifyListeners();
    });
  }
}

final _authNotifier = AuthNotifier();

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.splash,
  refreshListenable: _authNotifier,
  redirect: (context, state) {
  final session = Supabase.instance.client.auth.currentSession;
  final isLoggedIn = session != null;

  final isOnHome = state.matchedLocation == AppRoutes.home;
  final isOnSplash = state.matchedLocation == AppRoutes.splash;

  // If logged in and on splash, go to home
  if (isLoggedIn && isOnSplash) {
    return AppRoutes.home;
  }

  // If not logged in and trying to access home, go to login
  if (!isLoggedIn && isOnHome) {
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
      path: AppRoutes.login,
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: AppRoutes.signup,
      builder: (context, state) => const SignupScreen(),
    ),
    GoRoute(
      path: AppRoutes.home,
      builder: (context, state) => const HomeScreen(),
    ),
  ],
);