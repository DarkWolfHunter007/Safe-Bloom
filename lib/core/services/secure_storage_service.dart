import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Centralized secure storage configuration for Safe Bloom.
/// - Android: Configured with EncryptedSharedPreferences (AES-256 GCM backed by Android Keystore).
/// - iOS: Configured with KeychainAccessibility.first_unlock_this_device (isolated to physical device).
class SafeBloomSecureStorage {
  static const AndroidOptions androidOptions = AndroidOptions(
    encryptedSharedPreferences: true,
  );

  static const IOSOptions iosOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  );

  /// Standard singleton instance with hardware-isolated options.
  static const FlutterSecureStorage instance = FlutterSecureStorage(
    aOptions: androidOptions,
    iOptions: iosOptions,
  );

  /// Creates a configured FlutterSecureStorage instance.
  static FlutterSecureStorage create() => const FlutterSecureStorage(
    aOptions: androidOptions,
    iOptions: iosOptions,
  );
}
