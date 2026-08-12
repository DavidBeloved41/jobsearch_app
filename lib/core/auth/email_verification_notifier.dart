import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'email_verification_repository.dart';
import 'email_verification_state.dart';

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

  Future<void> resendVerificationEmail(String email) async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      status: EmailVerificationStatus.submitting,
    );

    try {
      await _repository.resendVerificationEmail(email);
      state = state.copyWith(
        email: email,
        isLoading: false,
        emailSent: true,
        status: EmailVerificationStatus.sent,
      );
    } on AuthException catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: error.message,
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

  void setEmail(String email) {
    state = state.copyWith(email: email);
  }

  void clear() {
    state = const EmailVerificationState();
  }
}
