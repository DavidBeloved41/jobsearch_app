import 'package:supabase_flutter/supabase_flutter.dart';

abstract class EmailVerificationRepository {
  Future<void> resendVerificationEmail(String email);
}

class SupabaseEmailVerificationRepository
    implements EmailVerificationRepository {
  final SupabaseClient _client;

  SupabaseEmailVerificationRepository([SupabaseClient? client])
    : _client = client ?? Supabase.instance.client;

  @override
  Future<void> resendVerificationEmail(String email) {
    return _client.auth.resend(
      email: email.trim(),
      type: OtpType.signup,
      emailRedirectTo: 'smartjob://login',
    );
  }
}
