import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'password_recovery_repository.dart';
import 'password_recovery_state.dart';

final passwordRecoveryRepositoryProvider = Provider<PasswordRecoveryRepository>(
  (ref) {
    return SupabasePasswordRecoveryRepository();
  },
);

final passwordRecoveryProvider =
    StateNotifierProvider<PasswordRecoveryNotifier, PasswordRecoveryState>((
      ref,
    ) {
      return PasswordRecoveryNotifier(
        ref.watch(passwordRecoveryRepositoryProvider),
      );
    });

class PasswordRecoveryNotifier extends StateNotifier<PasswordRecoveryState> {
  PasswordRecoveryNotifier(this._repository)
    : super(const PasswordRecoveryState());

  final PasswordRecoveryRepository _repository;

  Future<void> sendResetEmail(String email) async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      status: PasswordRecoveryStatus.submitting,
    );

    try {
      await _repository.sendResetEmail(email);
      state = state.copyWith(
        email: email,
        isLoading: false,
        emailSent: true,
        status: PasswordRecoveryStatus.emailSent,
      );
    } on AuthException catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: error.message,
        status: PasswordRecoveryStatus.error,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Unable to send recovery email. Please try again.',
        status: PasswordRecoveryStatus.error,
      );
    }
  }

  Future<void> resetPassword(String password) async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      status: PasswordRecoveryStatus.resetting,
    );

    try {
      await _repository.updatePassword(password);
      state = state.copyWith(
        isLoading: false,
        resetSuccess: true,
        status: PasswordRecoveryStatus.success,
      );
    } on AuthException catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: error.message,
        status: PasswordRecoveryStatus.error,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Unable to reset password. Please try again.',
        status: PasswordRecoveryStatus.error,
      );
    }
  }

  void clear() {
    state = const PasswordRecoveryState();
  }
}
