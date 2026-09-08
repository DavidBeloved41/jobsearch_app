import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../app/router.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/biometric_service.dart';
import '../widgets/auth_brand_header.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;
  String _biometricLabel = 'Biometrics';

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkBiometrics() async {
    final available = await BiometricService.isAvailable();
    final enabled = await BiometricService.isBiometricEnabled();
    final credentials = await BiometricService.getCredentials();
    final hasSavedCredentials =
        credentials['email'] != null && credentials['password'] != null;
    final label = await BiometricService.getBiometricLabel();
    if (mounted) {
      setState(() {
        _biometricAvailable = available;
        _biometricEnabled = enabled && hasSavedCredentials;
        _biometricLabel = label;
      });
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final authResponse = await Supabase.instance.client.auth
          .signInWithPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );

      final currentUser = authResponse.user;
      if (currentUser == null ||
          !SupabaseService.isEmailConfirmed(currentUser)) {
        await Supabase.instance.client.auth.signOut();
        if (mounted) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Please verify your email before logging in.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      if (mounted) {
        await _navigateAfterLogin(
          passwordForBiometric: _passwordController.text.trim(),
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(_friendlyLoginError(e)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginWithBiometric() async {
    setState(() => _isLoading = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final authenticated = await BiometricService.authenticate(
        reason: 'Sign in to SmartJob',
      );

      if (!authenticated) {
        setState(() => _isLoading = false);
        return;
      }

      final credentials = await BiometricService.getCredentials();
      final email = credentials['email'];
      final password = credentials['password'];

      if (email == null || password == null) {
        await BiometricService.disableBiometric();
        if (mounted) {
          setState(() {
            _biometricEnabled = false;
            _isLoading = false;
          });
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Please sign in with your password first'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      final authResponse = await Supabase.instance.client.auth
          .signInWithPassword(email: email, password: password);

      if (!SupabaseService.isEmailConfirmed(authResponse.user)) {
        await Supabase.instance.client.auth.signOut();
        if (mounted) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Please verify your email before logging in.'),
              backgroundColor: AppColors.error,
            ),
          );
          setState(() => _biometricEnabled = false);
        }
        return;
      }

      if (mounted) await _navigateAfterLogin();
    } on AuthException catch (e) {
      await BiometricService.disableBiometric();
      setState(() {
        _biometricEnabled = false;
        _isLoading = false;
      });
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(_friendlyLoginError(e)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AuthBrandHeader(
                        title: 'Welcome back',
                        subtitle: 'Sign in to continue your job search.',
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          hintText: 'Enter your email',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!value.contains('@')) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          hintText: 'Enter your password',
                          prefixIcon: const Icon(Icons.lock_outlined),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
                          }
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => GoRouter.of(
                            context,
                          ).push(AppRoutes.forgotPassword),
                          child: const Text('Forgot password?'),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => GoRouter.of(
                            context,
                          ).push(AppRoutes.emailVerification),
                          child: const Text('Resend verification email'),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _login,
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text('Sign in'),
                      ),
                      const SizedBox(height: 16),
                      if (_biometricAvailable && _biometricEnabled) ...[
                        OutlinedButton.icon(
                          onPressed: _isLoading ? null : _loginWithBiometric,
                          icon: Icon(
                            _biometricLabel == 'Face ID'
                                ? Icons.face_outlined
                                : Icons.fingerprint,
                            color: colorScheme.primary,
                          ),
                          label: Text(
                            'Sign in with $_biometricLabel',
                            style: TextStyle(color: colorScheme.primary),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: colorScheme.primary),
                            minimumSize: const Size(double.infinity, 52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Don't have an account? ",
                            style: TextStyle(color: AppColors.textSec(context)),
                          ),
                          TextButton(
                            onPressed: () =>
                                GoRouter.of(context).push(AppRoutes.signup),
                            child: const Text('Sign up'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _friendlyLoginError(AuthException error) {
    final message = error.message.toLowerCase();
    if (message.contains('email not confirmed') ||
        message.contains('not confirmed')) {
      return 'Please verify your email before logging in.';
    }
    if (message.contains('invalid login') ||
        message.contains('invalid credentials')) {
      return 'Email or password is incorrect.';
    }
    if (message.contains('network') || message.contains('connection')) {
      return 'Network error. Check your connection and try again.';
    }
    return 'Unable to sign in. Please try again.';
  }

  Future<void> _navigateAfterLogin({String? passwordForBiometric}) async {
    if (!mounted) return;

    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      GoRouter.of(context).go(AppRoutes.login);
      return;
    }

    final profile = await SupabaseService.getProfile(currentUser.id);
    final role = SupabaseService.normalizeAccountType(
      profile?['account_type'] ?? currentUser.userMetadata?['account_type'],
    );
    final isAdmin = SupabaseService.isAuthorizedAdminUser(
      email: currentUser.email,
      accountType: role,
    );
    if (!isAdmin && passwordForBiometric != null) {
      final biometricActivated = await _offerBiometricActivation(
        email: currentUser.email ?? _emailController.text.trim(),
        password: passwordForBiometric,
      );
      if (!biometricActivated) return;
    }

    final destination = await SupabaseService.getRoleRoute(currentUser.id);
    if (!mounted) return;
    GoRouter.of(context).go(destination);
  }

  Future<bool> _offerBiometricActivation({
    required String email,
    required String password,
  }) async {
    final available = await BiometricService.isAvailable();
    if (await BiometricService.isBiometricEnabled()) return true;
    if (!available) {
      final reason = await BiometricService.unavailableReason();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              reason == 'not_enrolled'
                  ? 'No biometric is enrolled. You can continue without biometric login.'
                  : 'Biometric authentication is unavailable. You can continue without it.',
            ),
            backgroundColor: AppColors.warning,
          ),
        );
      }
      return true;
    }

    final label = await BiometricService.getBiometricLabel();
    if (!mounted) return false;
    final shouldEnable = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text('Enable $label?'),
        content: Text(
          'Use $label for faster, secure access to your SmartJob account next time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Enable'),
          ),
        ],
      ),
    );
    if (shouldEnable != true || !mounted) return true;

    final authenticated = await BiometricService.authenticate(
      reason: 'Confirm $label for SmartJob sign in',
    );
    if (!authenticated) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Biometric activation was cancelled or failed. Try again to continue.',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return false;
    }
    await BiometricService.saveCredentials(email, password);
    return true;
  }
}
