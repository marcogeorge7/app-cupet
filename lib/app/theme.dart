import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CupetColors {
  static const Color primary = Color(0xFFFFD23F);
  static const Color primaryDark = Color(0xFFE0B521);
  static const Color ink = Color(0xFF1B1B1B);
  static const Color surface = Color(0xFFFFF8E5);
  static const Color soft = Color(0xFFF5EAD0);
  static const Color danger = Color(0xFFE63946);
  static const Color accent = Color(0xFF4ECDC4);
}

ThemeData buildCupetTheme() {
  final base = ThemeData.light(useMaterial3: true);

  final colorScheme = ColorScheme.fromSeed(
    seedColor: CupetColors.primary,
    brightness: Brightness.light,
    primary: CupetColors.primary,
    onPrimary: CupetColors.ink,
    surface: Colors.white,
  );

  final headingFont = GoogleFonts.barrioTextTheme(base.textTheme);
  final bodyFont = GoogleFonts.manropeTextTheme(base.textTheme);

  final textTheme = bodyFont.copyWith(
    displayLarge: headingFont.displayLarge?.copyWith(color: CupetColors.ink),
    displayMedium: headingFont.displayMedium?.copyWith(color: CupetColors.ink),
    displaySmall: headingFont.displaySmall?.copyWith(color: CupetColors.ink),
    headlineLarge: headingFont.headlineLarge?.copyWith(color: CupetColors.ink),
    headlineMedium: headingFont.headlineMedium?.copyWith(color: CupetColors.ink),
    headlineSmall: headingFont.headlineSmall?.copyWith(color: CupetColors.ink),
    titleLarge: headingFont.titleLarge?.copyWith(color: CupetColors.ink),
  );

  return base.copyWith(
    colorScheme: colorScheme,
    scaffoldBackgroundColor: CupetColors.surface,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: CupetColors.surface,
      foregroundColor: CupetColors.ink,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: headingFont.titleLarge?.copyWith(
        color: CupetColors.ink,
        fontSize: 22,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: CupetColors.primary,
        foregroundColor: CupetColors.ink,
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        textStyle: bodyFont.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: CupetColors.ink,
        minimumSize: const Size.fromHeight(54),
        side: const BorderSide(color: CupetColors.ink, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 16,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: CupetColors.soft),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: CupetColors.soft),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: CupetColors.primaryDark, width: 2),
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: const BorderSide(color: CupetColors.soft),
      ),
    ),
  );
}
