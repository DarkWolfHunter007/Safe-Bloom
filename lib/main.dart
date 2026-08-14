import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'features/onboarding/presentation/views/onboarding_view.dart';
import 'features/security/data/services/biometric_auth_service.dart';
import 'features/security/data/services/screen_security_service.dart';
import 'features/security/presentation/views/biometric_lock_screen.dart';
import 'features/tracking/data/datasources/database_helper.dart';
import 'features/tracking/presentation/views/home_shell_view.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
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
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      if (_isBiometricLockEnabled && _hasProfile) {
        setState(() {
          _isAuthenticated = false;
        });
      }
    }
  }

  Future<void> _checkAppStatus() async {
    await ScreenSecurityService.instance.applyPersistedSetting();
    final profile = await DatabaseHelper.instance.getUserProfile();
    final isBiometricEnabled =
        await BiometricAuthService.instance.isBiometricLockEnabled();

    if (mounted) {
      setState(() {
        _hasProfile = profile != null;
        _isBiometricLockEnabled = isBiometricEnabled;
        _isAuthenticated = !isBiometricEnabled;
        _isLoading = false;
      });
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

    if (!_hasProfile) {
      return const OnboardingView();
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
