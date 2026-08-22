import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/services/local_notification_service.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'features/onboarding/presentation/views/onboarding_view.dart';
import 'features/security/data/services/biometric_auth_service.dart';
import 'features/security/data/services/screen_security_service.dart';
import 'features/security/presentation/views/biometric_lock_screen.dart';
import 'features/security/presentation/views/database_recovery_view.dart';
import 'features/tracking/data/datasources/database_helper.dart';
import 'features/tracking/domain/entities/user_profile.dart';
import 'features/tracking/presentation/views/home_shell_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Silence all debug printing in release builds to protect privacy and eliminate logcat exposure
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }

  // Mobile UI System Bar overlay for iOS & Android
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.lightCardBackground,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Lock to mobile portrait orientation
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const SafeBloomApp());

  // Prompt for OS notification permission after initial frame is mounted
  unawaited(LocalNotificationService.instance.requestPermission());
}

class SafeBloomApp extends StatelessWidget {
  const SafeBloomApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Safe Bloom',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const AppStartupWrapper(),
    );
  }
}

class AppStartupWrapper extends StatefulWidget {
  const AppStartupWrapper({super.key});

  @override
  State<AppStartupWrapper> createState() => _AppStartupWrapperState();
}

class _AppStartupWrapperState extends State<AppStartupWrapper>
    with WidgetsBindingObserver {
  bool _isLoading = true;
  bool _hasProfile = false;
  bool _isBiometricLockEnabled = false;
  bool _isAuthenticated = false;
  bool _isDatabaseCorrupted = false;
  String? _databaseError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAppStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Lock on paused (Android background), hidden (recent-apps screen),
    // and inactive (iOS app-switcher / incoming call overlay).
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.inactive) {
      if (_isBiometricLockEnabled && _hasProfile && !_isDatabaseCorrupted) {
        setState(() {
          _isAuthenticated = false;
        });
      }
    }
  }

  Future<void> _checkAppStatus() async {
    setState(() {
      _isLoading = true;
      _isDatabaseCorrupted = false;
      _databaseError = null;
    });

    try {
      // Parallelize screen security, database query, and biometric status checks
      final results = await Future.wait([
        ScreenSecurityService.instance.applyPersistedSetting(),
        DatabaseHelper.instance.getUserProfile(),
        BiometricAuthService.instance.isBiometricLockEnabled(),
      ]);

      final profile = results[1] as UserProfile?;
      final isBiometricEnabled = results[2] as bool;

      if (mounted) {
        setState(() {
          _hasProfile = profile != null;
          _isBiometricLockEnabled = isBiometricEnabled;
          _isAuthenticated = !isBiometricEnabled;
          _isDatabaseCorrupted = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDatabaseCorrupted = true;
          _databaseError = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.lightBackground,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.dropCoral),
        ),
      );
    }

    if (_isDatabaseCorrupted) {
      return DatabaseRecoveryView(
        errorMessage: _databaseError ?? 'Unable to open encrypted database.',
        onRecovered: () => _checkAppStatus(),
        onPurged: () {
          setState(() {
            _hasProfile = false;
            _isDatabaseCorrupted = false;
            _databaseError = null;
          });
        },
      );
    }

    if (!_hasProfile) {
      return OnboardingView(
        onComplete: () {
          setState(() {
            _hasProfile = true;
          });
        },
      );
    }

    if (_isBiometricLockEnabled && !_isAuthenticated) {
      return BiometricLockScreen(
        onUnlocked: () {
          setState(() {
            _isAuthenticated = true;
          });
        },
      );
    }

    return const HomeShellView();
  }
}
