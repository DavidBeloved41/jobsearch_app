import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase/supabase_service.dart';

class AuthState {
  final Session? session;
  final User? user;
  final String? role;
  final bool initialized;

  const AuthState({
    this.session,
    this.user,
    this.role,
    this.initialized = false,
  });

  bool get isAuthenticated =>
      SupabaseService.canAccessAuthenticatedApp(session: session, user: user);
  bool get isEmployer => isAuthenticated && role == 'employer';
  bool get isJobSeeker => isAuthenticated && role == 'job_seeker';
  bool get isAdmin => isAuthenticated && role == 'admin';
  bool get needsRoleSelection =>
      isAuthenticated && (role == null || role == 'unknown');
}

class AuthNotifier extends ChangeNotifier {
  AuthState _state = const AuthState(initialized: false);
  StreamSubscription? _authSubscription;

  AuthNotifier() {
    _listenToAuthChanges();
  }

  AuthState get state => _state;
  bool get initialized => _state.initialized;
  bool get isAuthenticated => _state.isAuthenticated;
  bool get isEmployer => _state.isEmployer;
  bool get isJobSeeker => _state.isJobSeeker;
  bool get isAdmin => _state.isAdmin;
  bool get needsRoleSelection => _state.needsRoleSelection;
  String? get role => _state.role;
  bool get roleKnown => _state.role != null && _state.role != 'unknown';

  Future<void> _listenToAuthChanges() async {
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      event,
    ) async {
      await _refreshAuthState();
    });
    await _refreshAuthState();
  }

  Future<void> _refreshAuthState() async {
    final session = Supabase.instance.client.auth.currentSession;
    final user = Supabase.instance.client.auth.currentUser;
    String? role;

    if (SupabaseService.canAccessAuthenticatedApp(
      session: session,
      user: user,
    )) {
      final authenticatedUser = user!;
      final profile = await SupabaseService.getProfile(authenticatedUser.id);
      final rawRoleFromMetadata =
          authenticatedUser.userMetadata?['account_type'] as String?;

      if (profile == null) {
        await SupabaseService.createProfile(
          authenticatedUser.id,
          email: authenticatedUser.email,
          fullName: authenticatedUser.userMetadata?['full_name'] as String?,
          accountType: rawRoleFromMetadata,
        );
        role =
            (rawRoleFromMetadata == null || rawRoleFromMetadata.trim().isEmpty)
            ? null
            : SupabaseService.normalizeAccountType(rawRoleFromMetadata);
      } else {
        final rawRole = profile['account_type'] as String?;
        final rawRoleToUse = (rawRole == null || rawRole.trim().isEmpty)
            ? rawRoleFromMetadata
            : rawRole;

        if (rawRoleToUse == null || rawRoleToUse.trim().isEmpty) {
          role = null;
        } else {
          role = SupabaseService.normalizeAccountType(rawRoleToUse);
          final normalizedRole = SupabaseService.normalizeAccountType(
            rawRoleToUse,
          );
          if (rawRole != normalizedRole) {
            await SupabaseService.updateProfile(authenticatedUser.id, {
              'account_type': normalizedRole,
            });
          }
        }
      }
    } else {
      role = null;
    }

    _state = AuthState(
      session: session,
      user: user,
      role: role,
      initialized: true,
    );
    notifyListeners();
  }

  Future<void> setRole(String role) async {
    final session = Supabase.instance.client.auth.currentSession;
    final user = Supabase.instance.client.auth.currentUser ?? session?.user;
    if (user == null) {
      throw StateError('No authenticated user available to set role.');
    }

    final normalizedRole = SupabaseService.normalizeAccountType(role);
    debugPrint(
      'AuthController: setting role $normalizedRole for user ${user.id}',
    );

    final profile = await SupabaseService.getProfile(user.id);
    if (profile == null) {
      await SupabaseService.createProfile(
        user.id,
        email: user.email,
        fullName: user.userMetadata?['full_name'] as String?,
        accountType: normalizedRole,
      );
    } else {
      await SupabaseService.updateProfile(user.id, {
        'account_type': normalizedRole,
      });
    }

    await _refreshAuthState();
  }

  Future<void> signOut() async {
    await Supabase.instance.client.auth.signOut();
  }

  void setPasswordRecoveryFromLink(Uri uri) {
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}

late final AuthNotifier authNotifier;
final authControllerProvider = ChangeNotifierProvider<AuthNotifier>((ref) {
  return authNotifier;
});
