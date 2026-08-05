import 'package:flutter/material.dart';
import 'app_colors.dart';

abstract class AppTheme {
  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.lightBackground,
    colorScheme: const ColorScheme.light(
      primary: AppColors.petalRose,
      secondary: AppColors.dropCoral,
      surface: AppColors.lightCardBackground,
    ),
    useMaterial3: true,
  );

  static ThemeData get darkTheme => lightTheme;
}
