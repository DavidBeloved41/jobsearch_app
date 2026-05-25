import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../app/router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/biometric_service.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final session = Supabase.instance.client.auth.currentSession;

    if (session != null) {
      // Already logged in — go straight home
      GoRouter.of(context).go(AppRoutes.home);
      return;
    }

    // No active session — check if biometric login is enabled
    final biometricEnabled = await BiometricService.isBiometricEnabled();
    final biometricAvailable = await BiometricService.isAvailable();

    if (biometricEnabled && biometricAvailable) {
      // Auto-prompt biometrics
      final authenticated = await BiometricService.authenticate(
        reason: 'Sign in to SmartJob',
      );

      if (!mounted) return;

      if (authenticated) {
        // Retrieve stored credentials and sign in
        final credentials = await BiometricService.getCredentials();
        final email = credentials['email'];
        final password = credentials['password'];

        if (email != null && password != null) {
          try {
            await Supabase.instance.client.auth.signInWithPassword(
              email: email,
              password: password,
            );
            if (mounted) GoRouter.of(context).go(AppRoutes.home);
            return;
          } catch (e) {
            // Credentials may be stale — fall through to login screen
            await BiometricService.disableBiometric();
          }
        }
      }
    }

    // Fall through to login screen
    if (mounted) GoRouter.of(context).go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.work_rounded,
                size: 60,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'SmartJob',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Find your dream job',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}