import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../app/router.dart';
import '../../../core/auth/email_verification_notifier.dart';
import '../../../core/auth/email_verification_state.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../../core/theme/app_colors.dart';

class EmailVerificationScreen extends ConsumerStatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  ConsumerState<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState
    extends ConsumerState<EmailVerificationScreen> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  DateTime? _resendAvailableAt;
  Timer? _countdownTicker;
  bool _showSuccess = false;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _countdownTicker?.cancel();
    super.dispose();
  }

  Future<void> _resendVerificationEmail() async {
    final email = _emailController.text.trim();
    if (!_isValidEmail(email)) return;
    if (_resendAvailableAt != null &&
        DateTime.now().isBefore(_resendAvailableAt!)) {
      return;
    }

    await ref
        .read(emailVerificationProvider.notifier)
        .resendVerificationEmail(email);
    if (!mounted) return;
    final state = ref.read(emailVerificationProvider);
    if (state.status == EmailVerificationStatus.sent) {
      _startResendCountdown();
    }
  }

  Future<void> _verifyCode() async {
    final email = _emailController.text.trim();
    final code = _codeController.text.trim();
    if (!_isValidEmail(email) || code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your email and the 6-digit code.')),
      );
      return;
    }

    final verified = await ref
        .read(emailVerificationProvider.notifier)
        .verifyVerificationCode(email, code);
    if (!verified || !mounted) return;

    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null || !SupabaseService.isEmailConfirmed(user)) {
        throw StateError('Verified user session was not returned.');
      }
      final existingProfile = await SupabaseService.getProfile(user.id);
      if (existingProfile == null) {
        await SupabaseService.createProfile(
          user.id,
          fullName: user.userMetadata?['full_name'] as String?,
          accountType: user.userMetadata?['account_type'] as String?,
        );
      }
      await client.auth.signOut();
      if (!mounted) return;
      setState(() => _showSuccess = true);
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      if (mounted) context.go(AppRoutes.login);
    } catch (_) {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Email verified, but account setup failed. Please try again.',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _goToLogin() {
    ref.read(emailVerificationProvider.notifier).clear();
    context.go(AppRoutes.login);
  }

  void _goToSignup() {
    ref.read(emailVerificationProvider.notifier).clear();
    context.go(AppRoutes.signup);
  }

  void _startResendCountdown() {
    _countdownTicker?.cancel();
    setState(() {
      _resendAvailableAt = DateTime.now().add(const Duration(seconds: 60));
    });
    _countdownTicker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted ||
          _resendAvailableAt == null ||
          !DateTime.now().isBefore(_resendAvailableAt!)) {
        timer.cancel();
        if (mounted) setState(() => _resendAvailableAt = null);
        return;
      }
      setState(() {});
    });
  }

  bool _isValidEmail(String email) =>
      email.isNotEmpty && email.contains('@') && email.contains('.');

  String _resendLabel() {
    final availableAt = _resendAvailableAt;
    if (availableAt == null) return 'Resend code';
    final seconds = availableAt.difference(DateTime.now()).inSeconds;
    if (seconds <= 0) return 'Resend code';
    return 'Resend code in ${seconds + 1}s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final state = ref.watch(emailVerificationProvider);
    if (_emailController.text.isEmpty && state.email.isNotEmpty) {
      _emailController.text = state.email;
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        foregroundColor: colorScheme.onSurface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _goToLogin,
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _showSuccess ? _buildVerifiedView() : _buildCodeView(state),
        ),
      ),
    );
  }

  Widget _buildCodeView(EmailVerificationState state) {
    final colorScheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.email_outlined,
              size: 32,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Verify your email',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We sent a 6-digit verification code to ${SupabaseService.maskEmail(_emailController.text.isNotEmpty ? _emailController.text : state.email)}. Enter it here to verify the same account you just created.',
            style: TextStyle(
              fontSize: 15,
              color: colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Check your inbox, spam, and promotions folders. The code expires, so use the newest code.',
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          if (state.hasError)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                state.errorMessage ?? 'Failed to resend verification email.',
                style: TextStyle(color: colorScheme.error),
              ),
            ),
          TextField(
            controller: _emailController,
            readOnly: true,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              hintText: 'Enter your email',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _codeController,
            autofocus: true,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Verification code',
              hintText: 'Enter 6-digit code',
              prefixIcon: Icon(Icons.lock_outline),
              counterText: '',
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: state.isLoading ? null : _verifyCode,
            child: state.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text('Verify code'),
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed:
                  state.isLoading ||
                      (_resendAvailableAt != null &&
                          DateTime.now().isBefore(_resendAvailableAt!))
                  ? null
                  : _resendVerificationEmail,
              child: Text(_resendLabel()),
            ),
          ),
          Center(
            child: TextButton(
              onPressed: _goToSignup,
              child: const Text('Change email / Back to sign up'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerifiedView() {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.check_circle_outline,
            size: 50,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Email verified successfully.',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Your account is ready. Sign in with your email and password to continue.',
          style: TextStyle(
            fontSize: 15,
            color: colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: () => context.go(AppRoutes.login),
          child: const Text('Continue to sign in'),
        ),
      ],
    );
  }
}
