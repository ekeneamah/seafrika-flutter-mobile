import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primary = Color.fromARGB(255, 84, 146, 68); // Forest Green
  static const Color lightPrimary = Color(0xFF90EE90); // Light Green
  static const Color secondary = Color(0xFF2E8B57);
  static const Color accent = Color(0xFF6B8E23);
  static const Color earth = Color(0xFF8D6E63); // Earth brown
  static const Color earthLight = Color(0xFFD7CCC8); // Lighter earth
  static const Color whiteSmoke = Color(0xFFF5F5F5); // Very light neutral
  static const Color dividerColor = earth;
  static const Color background = earthLight;
  static const Color textPrimary = Color(0xFF003300);
  static const Color textSecondary = Color(0xFF1A1A1A);
  static const Color textColor = Color(0xFFF0F1C5); // sunlightFog
  static const Color backgroundColor = Color(0xFFF1F8E9);

  // New modern colors for glassy interface
  static const Color glass = Color(0xFFFFFFFF);
  static const Color glassSecondary = Color(0xFFFAFAFA);
  static const Color softGreen = Color(0xFFE8F5E8);
  static const Color mintGreen = Color(0xFFF0F9F0);
  static const Color sage = Color(0xFF9CAF88);
  static const Color forestMist = Color(0xFFE1EDD8);

  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.light(
      primary: primary,
      secondary: secondary,
      surface: Colors.white,
      background: backgroundColor,
      error: Colors.red,
    ),
    scaffoldBackgroundColor: backgroundColor,
    appBarTheme: AppBarTheme(
      backgroundColor: glass,
      foregroundColor: textPrimary,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: GoogleFonts.inter(
        color: textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),
    textTheme: GoogleFonts.interTextTheme().copyWith(
      displayLarge:
          GoogleFonts.inter(color: textPrimary, fontWeight: FontWeight.w700),
      displayMedium:
          GoogleFonts.inter(color: textPrimary, fontWeight: FontWeight.w600),
      displaySmall:
          GoogleFonts.inter(color: textPrimary, fontWeight: FontWeight.w600),
      headlineMedium:
          GoogleFonts.inter(color: textPrimary, fontWeight: FontWeight.w600),
      headlineSmall:
          GoogleFonts.inter(color: textPrimary, fontWeight: FontWeight.w600),
      titleLarge:
          GoogleFonts.inter(color: textPrimary, fontWeight: FontWeight.w600),
      titleMedium:
          GoogleFonts.inter(color: textPrimary, fontWeight: FontWeight.w500),
      bodyLarge:
          GoogleFonts.inter(color: textSecondary, fontWeight: FontWeight.w400),
      bodyMedium:
          GoogleFonts.inter(color: textSecondary, fontWeight: FontWeight.w400),
      labelLarge:
          GoogleFonts.inter(color: textPrimary, fontWeight: FontWeight.w500),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 0,
        shadowColor: primary.withOpacity(0.3),
        textStyle: GoogleFonts.inter(
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: glass,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: earthLight, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: earthLight, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: secondary, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: secondary, width: 2),
      ),
      labelStyle: GoogleFonts.inter(
        color: earth,
        fontWeight: FontWeight.w500,
      ),
      hintStyle: GoogleFonts.inter(
        color: earth.withOpacity(0.7),
        fontWeight: FontWeight.w400,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    ),
  );

  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.dark(
      primary: primary,
      secondary: secondary,
      surface: const Color(0xFF1A1A1A),
      background: const Color(0xFF121212),
      error: Colors.red,
    ),
    scaffoldBackgroundColor: const Color(0xFF121212),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1A1A1A),
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(color: Colors.white),
      displayMedium: TextStyle(color: Colors.white),
      displaySmall: TextStyle(color: Colors.white),
      headlineMedium: TextStyle(color: Colors.white),
      headlineSmall: TextStyle(color: Colors.white),
      titleLarge: TextStyle(color: Colors.white),
      bodyLarge: TextStyle(color: Colors.white70),
      bodyMedium: TextStyle(color: Colors.white70),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF1A1A1A),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: primary),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: primary),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: primary, width: 2),
      ),
    ),
  );

  static final ThemeData forestTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.dark(
      primary: primary,
      secondary: secondary,
      surface: const Color(0xFF1A1A1A),
      background: const Color(0xFF121212),
      error: Colors.red,
    ),
    scaffoldBackgroundColor: const Color(0xFF121212),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1A1A1A),
      foregroundColor: textColor,
      elevation: 0,
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(color: textColor),
      displayMedium: TextStyle(color: textColor),
      displaySmall: TextStyle(color: textColor),
      headlineMedium: TextStyle(color: textColor),
      headlineSmall: TextStyle(color: textColor),
      titleLarge: TextStyle(color: textColor),
      bodyLarge: TextStyle(
          color: Color(0xFFC7C7A6)), // softened version of sunlightFog
      bodyMedium: TextStyle(color: Color(0xFFC7C7A6)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: secondary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF1A1A1A),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: primary),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: primary),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: primary, width: 2),
      ),
    ),
  );

  static final ThemeData forestTheme2 = ThemeData(
    primaryColor: Color(0xFF2E7D32),
    scaffoldBackgroundColor: Color(0xFFF1F8E9),
    colorScheme: ColorScheme.fromSwatch().copyWith(
      primary: Color(0xFF2E7D32),
      secondary: Color(0xFF66BB6A),
      background: Color(0xFFF1F8E9),
      surface: Color(0xFFE8F5E9),
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onBackground: Color(0xFF2E7D32),
      onSurface: Color(0xFF2E7D32),
    ),
    dividerColor: Color(0xFFB0BEC5),
    appBarTheme: AppBarTheme(
      backgroundColor: Color(0xFF2E7D32),
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    textTheme: GoogleFonts.latoTextTheme(),
    chipTheme: ChipThemeData(
      backgroundColor: Color(0xFFA5D6A7),
      labelStyle: TextStyle(color: Color(0xFF2E7D32)),
      selectedColor: Color(0xFF66BB6A),
      secondarySelectedColor: Color(0xFF8D6E63),
    ),
  );
}
