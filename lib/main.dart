import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'features/tracking/presentation/views/home_shell_view.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Mobile UI System Bar overlay for iOS & Android
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark, // Android dark icons
      statusBarBrightness: Brightness.light,   // iOS dark icons
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
      home: const HomeShellView(),
    );
  }
}
