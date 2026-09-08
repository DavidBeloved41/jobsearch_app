import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'email_verification_repository.dart';
import 'email_verification_state.dart';
import '../supabase/supabase_service.dart';

final emailVerificationRepositoryProvider =
    Provider<EmailVerificationRepository>((ref) {
      return SupabaseEmailVerificationRepository();
    });

final emailVerificationProvider =
    StateNotifierProvider<EmailVerificationNotifier, EmailVerificationState>((
      ref,
    ) {
      return EmailVerificationNotifier(
        ref.watch(emailVerificationRepositoryProvider),
      );
    });

class EmailVerificationNotifier extends StateNotifier<EmailVerificationState> {
  EmailVerificationNotifier(this._repository)
    : super(const EmailVerificationState());

  final EmailVerificationRepository _repository;
  DateTime? _lastResendAt;

  Future<void> resendVerificationEmail(String email) async {
    final now = DateTime.now();
    if (_lastResendAt != null &&
        now.difference(_lastResendAt!) < const Duration(seconds: 60)) {
      state = state.copyWith(
        errorMessage: 'Please wait before requesting another email.',
        status: EmailVerificationStatus.error,
      );
      return;
    }
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      status: EmailVerificationStatus.submitting,
    );

    try {
      await _repository.resendVerificationEmail(email);
      _lastResendAt = now;
      state = state.copyWith(
        email: email,
        isLoading: false,
        emailSent: true,
        status: EmailVerificationStatus.sent,
      );
    } on AuthException catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _friendlyError(error),
        status: EmailVerificationStatus.error,
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Unable to resend verification email. Please try again.',
        status: EmailVerificationStatus.error,
      );
    }
  }

  Future<bool> verifyVerificationCode(String email, String code) async {
    final normalizedEmail = email.trim();
    final normalizedCode = code.trim();
    if (normalizedCode.length != 6 || int.tryParse(normalizedCode) == null) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Enter the 6-digit verification code from your email.',
        status: EmailVerificationStatus.error,
      );
      return false;
    }

    state = state.copyWith(
      email: normalizedEmail,
      isLoading: true,
      errorMessage: null,
      status: EmailVerificationStatus.submitting,
    );

    try {
      final response = await _repository.verifyVerificationCode(
        normalizedEmail,
        normalizedCode,
      );
      final user = response.user;
      if (user == null || !SupabaseService.isEmailConfirmed(user)) {
        state = state.copyWith(
          isLoading: false,
          errorMessage:
              'Email verification did not complete. Please try again.',
          status: EmailVerificationStatus.error,
        );
        return false;
      }
      state = state.copyWith(
        isLoading: false,
        verificationSucceeded: true,
        errorMessage: null,
        status: EmailVerificationStatus.verified,
      );
      return true;
    } on AuthException catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _friendlyVerificationError(error),
        status: EmailVerificationStatus.error,
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Network error. Check your connection and try again.',
        status: EmailVerificationStatus.error,
      );
      return false;
    }
  }

  String _friendlyError(AuthException error) {
    final message = error.message.toLowerCase();
    if (message.contains('rate') || message.contains('too many')) {
      return 'Please wait a few moments before requesting another email.';
    }
    if (message.contains('already') && message.contains('confirm')) {
      return 'This email is already verified. Please continue to sign in.';
    }
    return 'Unable to resend verification email';
  }

  String _friendlyVerificationError(AuthException error) {
    final message = error.message.toLowerCase();
    if (message.contains('expired') || message.contains('invalid')) {
      return 'This verification code is invalid or expired. Request a new code and try again.';
    }
    if (message.contains('rate') || message.contains('too many')) {
      return 'Too many attempts. Please wait and request a new code.';
    }
    return 'Unable to verify this code. Please try again.';
  }

  void setEmail(String email) {
    state = state.copyWith(email: email.trim(), emailSent: true);
  }

  void clear() {
    state = const EmailVerificationState();
  }
}
