import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_redirects.dart';

abstract class PasswordRecoveryRepository {
  Future<void> sendResetEmail(String email);
  Future<void> updatePassword(String password);
}

class SupabasePasswordRecoveryRepository implements PasswordRecoveryRepository {
  final SupabaseClient _client;

  SupabasePasswordRecoveryRepository([SupabaseClient? client])
    : _client = client ?? Supabase.instance.client;

  @override
  Future<void> sendResetEmail(String email) {
    return _client.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: AppAuthRedirects.resetPasswordCallback,
    );
  }

  @override
  Future<void> updatePassword(String password) async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) {
      throw const AuthException(
        'A valid recovery session is required to reset the password.',
      );
    }

    await _client.auth.updateUser(UserAttributes(password: password.trim()));
  }
}
