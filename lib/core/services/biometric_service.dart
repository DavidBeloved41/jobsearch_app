import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _keyBiometricEnabled = 'biometric_enabled';
  static const _keyStoredEmail = 'stored_email';
  static const _keyStoredPassword = 'stored_password';

  static Future<bool> isAvailable() async {
    try {
      final isDeviceSupported = await _auth.isDeviceSupported();
      final canCheckBiometrics = await _auth.canCheckBiometrics;
      final availableBiometrics = await _auth.getAvailableBiometrics();

      debugPrint('BiometricService: isDeviceSupported=$isDeviceSupported');
      debugPrint('BiometricService: canCheckBiometrics=$canCheckBiometrics');
      debugPrint('BiometricService: availableBiometrics=$availableBiometrics');

      return isDeviceSupported &&
          canCheckBiometrics &&
          availableBiometrics.isNotEmpty;
    } catch (e) {
      debugPrint('BiometricService: isAvailable error: $e');
      return false;
    }
  }

  static Future<String?> unavailableReason() async {
    try {
      if (!await _auth.isDeviceSupported()) return 'unsupported';
      if (!await _auth.canCheckBiometrics) return 'unavailable';
      if ((await _auth.getAvailableBiometrics()).isEmpty) return 'not_enrolled';
      return null;
    } on PlatformException catch (error) {
      debugPrint(
        'BiometricService: capability check failed code=${error.code}',
      );
      return 'platform_error';
    } catch (error) {
      debugPrint('BiometricService: capability check failed: $error');
      return 'platform_error';
    }
  }

  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }

  static Future<bool> authenticate({
    String reason = 'Authenticate to access SmartJob',
  }) async {
    try {
      final result = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          sensitiveTransaction: true,
        ),
      );
      debugPrint('BiometricService: authenticate result=$result');
      return result;
    } on PlatformException catch (e) {
      debugPrint('BiometricService: PlatformException: $e');
      return false;
    } catch (e) {
      debugPrint('BiometricService: authenticate error: $e');
      return false;
    }
  }

  static Future<void> saveCredentials(String email, String password) async {
    try {
      debugPrint('BiometricService: Attempting to save credentials for $email');
      await _storage.write(key: _keyStoredEmail, value: email);
      debugPrint('BiometricService: Email stored');
      await _storage.write(key: _keyStoredPassword, value: password);
      debugPrint('BiometricService: Password stored');
      await _storage.write(key: _keyBiometricEnabled, value: 'true');
      debugPrint('BiometricService: credentials saved for $email');
    } catch (e) {
      debugPrint('BiometricService: Error saving credentials: $e');
      rethrow;
    }
  }

  static Future<Map<String, String?>> getCredentials() async {
    final email = await _storage.read(key: _keyStoredEmail);
    final password = await _storage.read(key: _keyStoredPassword);
    return {'email': email, 'password': password};
  }

  static Future<bool> isBiometricEnabled() async {
    try {
      final value = await _storage.read(key: _keyBiometricEnabled);
      return value == 'true';
    } catch (e) {
      return false;
    }
  }

  static Future<void> disableBiometric() async {
    await _storage.delete(key: _keyBiometricEnabled);
    await _storage.delete(key: _keyStoredEmail);
    await _storage.delete(key: _keyStoredPassword);
  }

  static Future<String> getBiometricLabel() async {
    final types = await getAvailableBiometrics();
    if (types.contains(BiometricType.face)) return 'Face ID';
    if (types.contains(BiometricType.fingerprint)) return 'Fingerprint';
    if (types.contains(BiometricType.strong)) return 'Biometrics';
    return 'Biometrics';
  }
}
