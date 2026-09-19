import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Colors
  static const Color background = Color(0xFF090D16);
  static const Color backgroundAlt = Color(0xFF0D1322);
  static const Color surface = Color(0xFF131B2E);
  static const Color surfaceLighter = Color(0xFF1B2640);
  static const Color surfaceGlass = Color(0x99131B2E);
  
  // Accents
  static const Color primaryCyan = Color(0xFF06B6D4);
  static const Color primaryCyanGlow = Color(0xFF22D3EE);
  static const Color secondaryViolet = Color(0xFF8B5CF6);
  static const Color secondaryVioletGlow = Color(0xFFA78BFA);
  static const Color accentGreen = Color(0xFF10B981);
  static const Color accentDanger = Color(0xFFEF4444);
  static const Color accentAmber = Color(0xFFF59E0B);
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);
  static const Color borderSubtle = Color(0x22FFFFFF);
  static const Color borderGlass = Color(0x3338BDF8);

  // Gradients
  static const LinearGradient brandGradient = LinearGradient(
    colors: [primaryCyan, secondaryViolet],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    colors: [Color(0xFF172036), Color(0xFF0F172A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient glassGradient = LinearGradient(
    colors: [Color(0x331E293B), Color(0x1A0F172A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient dangerGradient = LinearGradient(
    colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF059669)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData get darkTheme {
    final baseTextTheme = ThemeData.dark().textTheme;
    final textTheme = GoogleFonts.plusJakartaSansTextTheme(baseTextTheme).apply(
      bodyColor: textPrimary,
      displayColor: textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: primaryCyan,
      canvasColor: surface,
      textTheme: textTheme,
      colorScheme: const ColorScheme.dark(
        primary: primaryCyan,
        secondary: secondaryViolet,
        surface: surface,
        error: accentDanger,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: -0.5,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return textMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primaryCyan;
          return surfaceLighter;
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: borderSubtle, width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        elevation: 24,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: borderGlass, width: 1),
        ),
      ),
    );
  }
}
