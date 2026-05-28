import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CupetColors {
  // Primary playful yellow lifted from the brand deck.
  static const Color primary = Color(0xFFFFD23F);
  static const Color primaryDark = Color(0xFFE0B521);
  // Deep ink for type + Germeen's fur.
  static const Color ink = Color(0xFF1B1B1B);
  // Cream surface keeps the page warm without competing with yellow.
  static const Color surface = Color(0xFFFFF6D6);
  static const Color soft = Color(0xFFF5EAD0);
  static const Color danger = Color(0xFFE63946);
  static const Color accent = Color(0xFFFF6FB5); // Germeen blush
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

  // Barrio for display + headlines (the brand's "main" font), Manrope for
  // body copy as a free, widely-available stand-in for "Obviously".
  final headingFont = GoogleFonts.barrioTextTheme(base.textTheme);
  final bodyFont = GoogleFonts.manropeTextTheme(base.textTheme);

  TextStyle? heading(TextStyle? s, {double scale = 1, double letter = -1}) =>
      s?.copyWith(
        color: CupetColors.ink,
        height: 1.05,
        letterSpacing: letter,
        fontSize: s.fontSize == null ? null : s.fontSize! * scale,
      );

  final textTheme = bodyFont
      .apply(bodyColor: CupetColors.ink, displayColor: CupetColors.ink)
      .copyWith(
        displayLarge: heading(headingFont.displayLarge, scale: 1.05),
        displayMedium: heading(headingFont.displayMedium, scale: 1.05),
        displaySmall: heading(headingFont.displaySmall, scale: 1.05),
        headlineLarge: heading(headingFont.headlineLarge, scale: 1.05),
        headlineMedium: heading(headingFont.headlineMedium, scale: 1.05),
        headlineSmall: heading(headingFont.headlineSmall, scale: 1.05),
        titleLarge: heading(headingFont.titleLarge),
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
