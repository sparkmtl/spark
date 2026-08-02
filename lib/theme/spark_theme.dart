import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'spark_colors.dart';

ThemeData buildSparkTheme() {
  final base = GoogleFonts.plusJakartaSansTextTheme();

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: SparkColors.background,
    colorScheme: const ColorScheme.dark(
      surface: SparkColors.background,
      primary: SparkColors.accent,
      onPrimary: SparkColors.onAccent,
      secondary: SparkColors.accent,
      onSurface: SparkColors.title,
    ),
    textTheme: base.copyWith(
      headlineLarge: base.headlineLarge?.copyWith(
        color: SparkColors.title,
        fontWeight: FontWeight.w700,
        fontSize: 32,
        letterSpacing: -0.4,
        height: 1.15,
      ),
      titleMedium: base.titleMedium?.copyWith(
        color: SparkColors.fieldText,
        fontWeight: FontWeight.w500,
        fontSize: 16,
      ),
      labelLarge: base.labelLarge?.copyWith(
        color: SparkColors.onAccent,
        fontWeight: FontWeight.w700,
        fontSize: 17,
        letterSpacing: 0.1,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        color: SparkColors.fieldText,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: SparkColors.surface,
      hintStyle: GoogleFonts.plusJakartaSans(
        color: SparkColors.placeholder,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      errorStyle: GoogleFonts.plusJakartaSans(
        color: const Color(0xFFFF6B6B),
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: SparkColors.accent, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFFF6B6B), width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFFF6B6B), width: 1.4),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: SparkColors.accent,
        foregroundColor: SparkColors.onAccent,
        elevation: 0,
        shadowColor: Colors.transparent,
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        textStyle: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w700,
          fontSize: 17,
        ),
      ),
    ),
    appBarTheme: const AppBarTheme(
      systemOverlayStyle: SystemUiOverlayStyle.light,
      backgroundColor: Colors.transparent,
      elevation: 0,
    ),
  );
}
