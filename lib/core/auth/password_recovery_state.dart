enum PasswordRecoveryStatus {
  initial,
  submitting,
  emailSent,
  resetting,
  success,
  error,
}

class PasswordRecoveryState {
  final String email;
  final bool isLoading;
  final bool emailSent;
  final bool resetSuccess;
  final String? errorMessage;
  final PasswordRecoveryStatus status;

  const PasswordRecoveryState({
    this.email = '',
    this.isLoading = false,
    this.emailSent = false,
    this.resetSuccess = false,
    this.errorMessage,
    this.status = PasswordRecoveryStatus.initial,
  });

  bool get hasError => errorMessage != null && errorMessage!.isNotEmpty;

  PasswordRecoveryState copyWith({
    String? email,
    bool? isLoading,
    bool? emailSent,
    bool? resetSuccess,
    String? errorMessage,
    PasswordRecoveryStatus? status,
  }) {
    return PasswordRecoveryState(
      email: email ?? this.email,
      isLoading: isLoading ?? this.isLoading,
      emailSent: emailSent ?? this.emailSent,
      resetSuccess: resetSuccess ?? this.resetSuccess,
      errorMessage: errorMessage,
      status: status ?? this.status,
    );
  }
}
