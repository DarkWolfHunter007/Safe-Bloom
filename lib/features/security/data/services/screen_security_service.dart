import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/services/secure_storage_service.dart';

class ScreenSecurityService {
  static final ScreenSecurityService instance = ScreenSecurityService._init();
  final FlutterSecureStorage _secureStorage = SafeBloomSecureStorage.instance;
  static const MethodChannel _channel =
      MethodChannel('com.example.safe_bloom/screen_security');

  static const String _screenSecurityKey = 'prevent_screen_recording';

  ScreenSecurityService._init();

  /// Returns true if screen recording and screenshots are BLOCKED.
  /// Default is false (screen recording & screenshots ALLOWED).
  Future<bool> isScreenSecurityEnabled() async {
    try {
      final value = await _secureStorage.read(key: _screenSecurityKey);
      return value == 'true';
    } catch (e) {
      debugPrint('Error reading screen security setting: $e');
      return false;
    }
  }

  /// Enable or disable screen security (FLAG_SECURE on Android).
  /// If [enabled] is true, screenshots & screen recordings are BLOCKED.
  /// If [enabled] is false, screenshots & screen recordings are ALLOWED.
  Future<void> setScreenSecurityEnabled(bool enabled) async {
    try {
      await _secureStorage.write(
        key: _screenSecurityKey,
        value: enabled.toString(),
      );
      await _channel
          .invokeMethod('setScreenSecurityEnabled', {'enabled': enabled});
    } catch (e) {
      debugPrint('Error updating screen security setting: $e');
    }
  }

  /// Applies the stored preference on app startup
  Future<void> applyPersistedSetting() async {
    final enabled = await isScreenSecurityEnabled();
    try {
      await _channel
          .invokeMethod('setScreenSecurityEnabled', {'enabled': enabled});
    } catch (e) {
      debugPrint('Error applying persisted screen security setting: $e');
    }
  }
}
