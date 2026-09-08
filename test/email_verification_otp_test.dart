import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jobsearch_app/core/auth/email_verification_notifier.dart';
import 'package:jobsearch_app/core/auth/email_verification_repository.dart';
import 'package:jobsearch_app/core/auth/email_verification_state.dart';
import 'package:jobsearch_app/core/supabase/supabase_service.dart';

class _FakeEmailVerificationRepository implements EmailVerificationRepository {
  int resendCalls = 0;
  int verifyCalls = 0;

  @override
  Future<void> resendVerificationEmail(String email) async {
    resendCalls++;
  }

  @override
  Future<AuthResponse> verifyVerificationCode(String email, String code) async {
    verifyCalls++;
    throw const AuthException('Invalid or expired OTP');
  }
}

void main() {
  test(
    'invalid OTP stays in verification and does not create an account',
    () async {
      final repository = _FakeEmailVerificationRepository();
      final notifier = EmailVerificationNotifier(repository);
      addTearDown(notifier.dispose);

      final verified = await notifier.verifyVerificationCode(
        'candidate@example.com',
        '12',
      );

      expect(verified, isFalse);
      expect(repository.verifyCalls, 0);
      expect(notifier.state.status, EmailVerificationStatus.error);
      expect(notifier.state.hasError, isTrue);
    },
  );

  test(
    'resend uses the existing signup email and never calls signup',
    () async {
      final repository = _FakeEmailVerificationRepository();
      final notifier = EmailVerificationNotifier(repository);
      addTearDown(notifier.dispose);

      await notifier.resendVerificationEmail('candidate@example.com');

      expect(repository.resendCalls, 1);
      expect(notifier.state.email, 'candidate@example.com');
      expect(notifier.state.status, EmailVerificationStatus.sent);
    },
  );

  test('unverified auth state cannot access the application', () {
    expect(SupabaseService.isEmailConfirmedAt(null), isFalse);
    expect(SupabaseService.isEmailConfirmedAt(''), isFalse);
    expect(SupabaseService.isEmailConfirmedAt('2026-09-06T00:00:00Z'), isTrue);
  });
}
