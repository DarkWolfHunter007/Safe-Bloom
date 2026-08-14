import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

abstract class AppTypography {
  static const List<String> _emojiFontFallbacks = [
    'Apple Color Emoji',
    'Segoe UI Emoji',
    'Noto Color Emoji',
  ];

  // Brand Serif Titles (Cormorant Garamond)
  static TextStyle brandTitle({Color color = AppColors.textMain, double fontSize = 32}) {
    return GoogleFonts.cormorantGaramond(
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      color: color,
      letterSpacing: 0.5,
    ).copyWith(fontFamilyFallback: _emojiFontFallbacks);
  }

  // Taglines & Subtitles (Montserrat Medium, +200 Letter Spacing All-Caps)
  static TextStyle brandTagline({Color color = AppColors.petalRose, double fontSize = 10}) {
    return GoogleFonts.montserrat(
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      color: color,
      letterSpacing: 1.5,
    ).copyWith(fontFamilyFallback: _emojiFontFallbacks);
  }

  // Body Text (Montserrat)
  static TextStyle body({
    Color color = AppColors.textMain,
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w400,
  }) {
    return GoogleFonts.montserrat(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    ).copyWith(fontFamilyFallback: _emojiFontFallbacks);
  }
}
