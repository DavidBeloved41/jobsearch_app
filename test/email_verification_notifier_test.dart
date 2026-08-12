import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jobsearch_app/core/auth/email_verification_notifier.dart';
import 'package:jobsearch_app/core/auth/email_verification_repository.dart';
import 'package:jobsearch_app/core/auth/email_verification_state.dart';

class FakeEmailVerificationRepository implements EmailVerificationRepository {
  bool shouldThrow = false;
  String? lastEmail;

  @override
  Future<void> resendVerificationEmail(String email) async {
    lastEmail = email;
    if (shouldThrow) {
      throw const AuthException('Unable to resend verification email');
    }
  }
}

void main() {
  late FakeEmailVerificationRepository repository;
  late ProviderContainer container;

  setUp(() {
    repository = FakeEmailVerificationRepository();
    container = ProviderContainer(
      overrides: [
        emailVerificationRepositoryProvider.overrideWithValue(repository),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  test('resendVerificationEmail updates state to sent on success', () async {
    final notifier = container.read(emailVerificationProvider.notifier);

    await notifier.resendVerificationEmail('test@example.com');

    final state = container.read(emailVerificationProvider);
    expect(state.emailSent, isTrue);
    expect(state.errorMessage, isNull);
    expect(state.status, EmailVerificationStatus.sent);
    expect(repository.lastEmail, 'test@example.com');
  });

  test('resendVerificationEmail sets errorMessage on failure', () async {
    repository.shouldThrow = true;
    final notifier = container.read(emailVerificationProvider.notifier);

    await notifier.resendVerificationEmail('test@example.com');

    final state = container.read(emailVerificationProvider);
    expect(state.emailSent, isFalse);
    expect(state.hasError, isTrue);
    expect(state.errorMessage, 'Unable to resend verification email');
    expect(state.status, EmailVerificationStatus.error);
  });
}
