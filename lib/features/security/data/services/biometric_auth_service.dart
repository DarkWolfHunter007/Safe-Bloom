import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class BiometricAuthService {
  static final BiometricAuthService instance = BiometricAuthService._init();
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  static const String _biometricLockKey = 'biometric_lock_enabled';

  BiometricAuthService._init();

  /// Check if biometric/PIN lock is enabled in settings
  Future<bool> isBiometricLockEnabled() async {
    try {
      final value = await _secureStorage.read(key: _biometricLockKey);
      return value == 'true';
    } catch (e) {
      debugPrint('Error reading biometric lock setting: $e');
      return false;
    }
  }

  /// Enable or disable biometric lock preference
  Future<void> setBiometricLockEnabled(bool enabled) async {
    try {
      await _secureStorage.write(
        key: _biometricLockKey,
        value: enabled.toString(),
      );
    } catch (e) {
      debugPrint('Error writing biometric lock setting: $e');
    }
  }

  /// Check if hardware/device supports biometric or PIN authentication
  Future<bool> isDeviceSupported() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      return canCheck || isSupported;
    } catch (e) {
      debugPrint('Error checking device biometric support: $e');
      return false;
    }
  }

  /// Get list of available biometric hardware types (e.g. fingerprint, face)
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      debugPrint('Error fetching available biometrics: $e');
      return [];
    }
  }

  /// Trigger Face ID / Fingerprint / Device PIN prompt
  Future<bool> authenticate({
    String reason = 'Authenticate to access Safe Bloom',
  }) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false, // Allows device PIN/passcode fallback
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } on PlatformException catch (e) {
      debugPrint('Biometric authentication PlatformException: ${e.code} - ${e.message}');
      return false;
    } catch (e) {
      debugPrint('Biometric authentication error: $e');
      return false;
    }
  }
}
