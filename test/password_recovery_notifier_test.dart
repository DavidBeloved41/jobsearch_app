import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jobsearch_app/core/auth/password_recovery_notifier.dart';
import 'package:jobsearch_app/core/auth/password_recovery_repository.dart';
import 'package:jobsearch_app/core/auth/password_recovery_state.dart';

class FakePasswordRecoveryRepository implements PasswordRecoveryRepository {
  bool shouldThrow = false;
  String? lastEmail;
  String? lastPassword;

  @override
  Future<void> sendResetEmail(String email) async {
    lastEmail = email;
    if (shouldThrow) {
      throw const AuthException('Unable to send reset email');
    }
  }

  @override
  Future<void> updatePassword(String password) async {
    lastPassword = password;
    if (shouldThrow) {
      throw const AuthException('Unable to reset password');
    }
  }
}

void main() {
  late FakePasswordRecoveryRepository repository;
  late ProviderContainer container;

  setUp(() {
    repository = FakePasswordRecoveryRepository();
    container = ProviderContainer(
      overrides: [
        passwordRecoveryRepositoryProvider.overrideWithValue(repository),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  test('sendResetEmail updates state to emailSent on success', () async {
    final notifier = container.read(passwordRecoveryProvider.notifier);

    await notifier.sendResetEmail('user@example.com');

    final state = container.read(passwordRecoveryProvider);
    expect(state.emailSent, isTrue);
    expect(state.errorMessage, isNull);
    expect(state.status, PasswordRecoveryStatus.emailSent);
    expect(repository.lastEmail, 'user@example.com');
  });

  test('sendResetEmail sets errorMessage on failure', () async {
    repository.shouldThrow = true;
    final notifier = container.read(passwordRecoveryProvider.notifier);

    await notifier.sendResetEmail('user@example.com');

    final state = container.read(passwordRecoveryProvider);
    expect(state.emailSent, isFalse);
    expect(state.hasError, isTrue);
    expect(state.errorMessage, 'Unable to send reset email');
    expect(state.status, PasswordRecoveryStatus.error);
  });

  test('resetPassword updates state to success on success', () async {
    final notifier = container.read(passwordRecoveryProvider.notifier);

    await notifier.resetPassword('newpassword123');

    final state = container.read(passwordRecoveryProvider);
    expect(state.resetSuccess, isTrue);
    expect(state.hasError, isFalse);
    expect(state.status, PasswordRecoveryStatus.success);
    expect(repository.lastPassword, 'newpassword123');
  });

  test('resetPassword sets errorMessage on failure', () async {
    repository.shouldThrow = true;
    final notifier = container.read(passwordRecoveryProvider.notifier);

    await notifier.resetPassword('newpassword123');

    final state = container.read(passwordRecoveryProvider);
    expect(state.resetSuccess, isFalse);
    expect(state.hasError, isTrue);
    expect(state.errorMessage, 'Unable to reset password');
    expect(state.status, PasswordRecoveryStatus.error);
  });
}
