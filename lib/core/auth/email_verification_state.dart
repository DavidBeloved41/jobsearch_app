enum EmailVerificationStatus { initial, submitting, sent, verified, error }

class EmailVerificationState {
  final String email;
  final bool isLoading;
  final bool emailSent;
  final bool verificationSucceeded;
  final String? errorMessage;
  final EmailVerificationStatus status;

  const EmailVerificationState({
    this.email = '',
    this.isLoading = false,
    this.emailSent = false,
    this.verificationSucceeded = false,
    this.errorMessage,
    this.status = EmailVerificationStatus.initial,
  });

  bool get hasError => errorMessage != null && errorMessage!.isNotEmpty;

  EmailVerificationState copyWith({
    String? email,
    bool? isLoading,
    bool? emailSent,
    bool? verificationSucceeded,
    String? errorMessage,
    EmailVerificationStatus? status,
  }) {
    return EmailVerificationState(
      email: email ?? this.email,
      isLoading: isLoading ?? this.isLoading,
      emailSent: emailSent ?? this.emailSent,
      verificationSucceeded:
          verificationSucceeded ?? this.verificationSucceeded,
      errorMessage: errorMessage,
      status: status ?? this.status,
    );
  }
}
