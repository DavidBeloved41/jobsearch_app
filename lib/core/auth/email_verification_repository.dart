import 'package:supabase_flutter/supabase_flutter.dart';

abstract class EmailVerificationRepository {
  Future<void> resendVerificationEmail(String email);
  Future<AuthResponse> verifyVerificationCode(String email, String code);
}

class SupabaseEmailVerificationRepository
    implements EmailVerificationRepository {
  final SupabaseClient _client;

  SupabaseEmailVerificationRepository([SupabaseClient? client])
    : _client = client ?? Supabase.instance.client;

  @override
  Future<void> resendVerificationEmail(String email) {
    return _client.auth.resend(email: email.trim(), type: OtpType.signup);
  }

  @override
  Future<AuthResponse> verifyVerificationCode(String email, String code) {
    return _client.auth.verifyOTP(
      email: email.trim(),
      token: code.trim(),
      type: OtpType.signup,
    );
  }
}
