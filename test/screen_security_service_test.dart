import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_bloom/features/security/data/services/screen_security_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel screenSecurityChannel =
      MethodChannel('com.example.safe_bloom/screen_security');
  const MethodChannel secureStorageChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  final List<MethodCall> log = <MethodCall>[];
  final Map<String, String> storage = <String, String>{};

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(screenSecurityChannel,
            (MethodCall methodCall) async {
      log.add(methodCall);
      if (methodCall.method == 'setScreenSecurityEnabled') {
        return true;
      }
      if (methodCall.method == 'isScreenSecurityEnabled') {
        return false;
      }
      if (methodCall.method == 'areNotificationsEnabled') {
        return true;
      }
      if (methodCall.method == 'openNotificationSettings') {
        return true;
      }
      return null;
    });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel,
            (MethodCall methodCall) async {
      final Map<dynamic, dynamic>? args =
          methodCall.arguments as Map<dynamic, dynamic>?;
      final String? key = args?['key'] as String?;
      final String? value = args?['value'] as String?;

      switch (methodCall.method) {
        case 'write':
          if (key != null && value != null) {
            storage[key] = value;
          }
          return null;
        case 'read':
          return storage[key];
        case 'delete':
          if (key != null) {
            storage.remove(key);
          }
          return null;
        case 'readAll':
          return storage;
        default:
          return null;
      }
    });

    log.clear();
    storage.clear();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(screenSecurityChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, null);
  });

  test('isScreenSecurityEnabled defaults to false (screen recording allowed)',
      () async {
    final isEnabled =
        await ScreenSecurityService.instance.isScreenSecurityEnabled();
    expect(isEnabled, isFalse);
  });

  test('setScreenSecurityEnabled invokes native MethodChannel with enabled flag',
      () async {
    await ScreenSecurityService.instance.setScreenSecurityEnabled(true);
    expect(log, hasLength(1));
    expect(log.first.method, equals('setScreenSecurityEnabled'));
    expect(log.first.arguments, equals({'enabled': true}));
    expect(await ScreenSecurityService.instance.isScreenSecurityEnabled(), isTrue);
  });

  test('applyPersistedSetting applies setting to MethodChannel', () async {
    await ScreenSecurityService.instance.applyPersistedSetting();
    expect(log, hasLength(1));
    expect(log.first.method, equals('setScreenSecurityEnabled'));
    expect(log.first.arguments, equals({'enabled': false}));
  });
}
