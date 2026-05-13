import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppGradients {
  // Very subtle top-green glow — barely noticeable, just kills the flatness
  static const screenBackground = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment(0, 0.55),
    colors: [Color(0xFF0E1C14), Color(0xFF0D1117)],
  );

  // Accent button gradient
  static const accentButton = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF95D5B2), Color(0xFF52B788)],
  );
}

class AppColors {
  static const background    = Color(0xFF0D1117);
  static const surface       = Color(0xFF161B22);
  static const surfaceVariant = Color(0xFF21262D);
  static const accent        = Color(0xFF74C69D);
  static const accentDim     = Color(0xFF40916C);

  static const heatmapEmpty  = Color(0xFF2A2A2A);
  static const heatmap0      = Color(0xFF1B4332);
  static const heatmap50     = Color(0xFF40916C);
  static const heatmap75     = Color(0xFF52B788);
  static const heatmap100    = Color(0xFF74C69D);

  static const textPrimary   = Color(0xFFE6EDF3);
  static const textSecondary = Color(0xFF8B949E);
  static const textMuted     = Color(0xFF484F58);
  static const divider       = Color(0xFF21262D);
}

ThemeData buildDarkTheme() {
  final base = ThemeData.dark();
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.accent,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
    ),
    cardTheme: const CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.background,
      elevation: 0,
      scrolledUnderElevation: 0,
      iconTheme: const IconThemeData(color: AppColors.textSecondary),
      systemOverlayStyle: SystemUiOverlayStyle.light,
      titleTextStyle: GoogleFonts.dmSans(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        letterSpacing: -0.3,
      ),
    ),
    textTheme: GoogleFonts.dmSansTextTheme(base.textTheme).apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceVariant,
      hintStyle: const TextStyle(color: AppColors.textMuted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    ),
    dividerColor: AppColors.divider,
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.surface,
      selectedItemColor: AppColors.accent,
      unselectedItemColor: AppColors.textSecondary,
      elevation: 0,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.accent,
      foregroundColor: Colors.black,
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.surfaceVariant,
      contentTextStyle: TextStyle(color: AppColors.textPrimary),
    ),
  );
}
