import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Colors ──
  static const Color primary = Color(0xFF15803D);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color secondary = Color(0xFF22C55E);
  static const Color onSecondary = Color(0xFF0F172A);
  static const Color accent = Color(0xFFA16207);
  static const Color onAccent = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFF0FDF4);
  static const Color foreground = Color(0xFF14532D);
  static const Color card = Color(0xFFFFFFFF);
  static const Color cardForeground = Color(0xFF14532D);
  static const Color muted = Color(0xFFE8F0F1);
  static const Color mutedForeground = Color(0xFF475569);
  static const Color border = Color(0xFFBBF7D0);
  static const Color destructive = Color(0xFFDC2626);
  static const Color ring = Color(0xFF15803D);

  // HWSD Score Colors
  static const Color s1Color = Color(0xFF15803D); // Sangat Sesuai
  static const Color s2Color = Color(0xFF22C55E); // Cukup Sesuai
  static const Color s3Color = Color(0xFFA16207); // Sesuai Bersyarat
  static const Color nColor = Color(0xFFDC2626);  // Tidak Sesuai

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: primary,
        onPrimary: onPrimary,
        secondary: secondary,
        onSecondary: onSecondary,
        surface: card,
        onSurface: cardForeground,
        error: destructive,
        onError: onAccent,
      ),
      scaffoldBackgroundColor: background,
      textTheme: GoogleFonts.openSansTextTheme().copyWith(
        headlineLarge: GoogleFonts.poppins(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
        headlineMedium: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: foreground,
        ),
        headlineSmall: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: foreground,
        ),
        bodyLarge: GoogleFonts.openSans(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: foreground,
        ),
        bodyMedium: GoogleFonts.openSans(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: foreground,
        ),
        bodySmall: GoogleFonts.openSans(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: mutedForeground,
        ),
        labelLarge: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: foreground,
        ),
        labelSmall: GoogleFonts.openSans(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: mutedForeground,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: onPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: border, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: background,
        side: const BorderSide(color: border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        labelStyle: GoogleFonts.openSans(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: foreground,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: card,
        selectedItemColor: primary,
        unselectedItemColor: mutedForeground,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        showUnselectedLabels: true,
      ),
    );
  }
}
