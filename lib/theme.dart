import 'package:flutter/material.dart';

class AppTheme {
  // ─── Design Tokens ─────────────────────────────────────────────────────────
  static const Color backgroundBase = Color(0xFF0B0E14);
  static const Color surface1       = Color(0xFF161B22);
  static const Color surface2       = Color(0xFF21262D);
  static const Color border         = Color(0xFF30363D);
  static const Color primaryAccent  = Color(0xFFFF4D4D);
  static const Color reading        = Color(0xFF38BDF8);
  static const Color completed      = Color(0xFF34D399);
  static const Color planToRead     = Color(0xFFFBBF24);
  static const Color onHold         = Color(0xFF94A3B8);
  static const Color dropped        = Color(0xFF94A3B8);
  static const Color onHoldDropped  = Color(0xFF94A3B8);
  static const Color textPrimary    = Color(0xFFF0F6FC);
  static const Color textSecondary  = Color(0xFF8B949E);
  static const Color textMuted      = Color(0xFF484F58);

  // ─── Color Helpers ─────────────────────────────────────────────────────────
  static Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'reading':   return reading;
      case 'completed': return completed;
      case 'plan':      return planToRead;
      case 'hold':      return onHold;
      case 'dropped':   return dropped;
      default:          return onHold;
    }
  }

  static String statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'reading':   return 'Membaca';
      case 'plan':      return 'Rencana';
      case 'completed': return 'Selesai';
      case 'hold':      return 'Ditahan';
      case 'dropped':   return 'Dropped';
      default:          return status;
    }
  }

  static String typeLabel(String type) {
    switch (type.toLowerCase()) {
      case 'manga':  return 'Manga';
      case 'manhwa': return 'Manhwa';
      case 'manhua': return 'Manhua';
      default:       return type.toUpperCase();
    }
  }

  // ─── Typography ────────────────────────────────────────────────────────────
  static const TextTheme textTheme = TextTheme(
    displayLarge: TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.w700,
      color: textPrimary,
      letterSpacing: -0.5,
    ),
    displayMedium: TextStyle(
      fontSize: 26,
      fontWeight: FontWeight.w700,
      color: textPrimary,
      letterSpacing: -0.3,
    ),
    titleLarge: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      color: textPrimary,
      letterSpacing: -0.2,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: textPrimary,
    ),
    titleSmall: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: textPrimary,
    ),
    bodyLarge: TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.normal,
      color: textPrimary,
    ),
    bodyMedium: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.normal,
      color: textSecondary,
    ),
    bodySmall: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.normal,
      color: textMuted,
    ),
    labelLarge: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: textPrimary,
      letterSpacing: 0.2,
    ),
    labelMedium: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      color: textSecondary,
      letterSpacing: 0.4,
    ),
    labelSmall: TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w500,
      color: textMuted,
      letterSpacing: 0.5,
    ),
  );

  // ─── ThemeData ─────────────────────────────────────────────────────────────
  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: backgroundBase,
    primaryColor: primaryAccent,
    canvasColor: surface1,
    cardColor: surface1,
    dividerColor: border,
    dialogBackgroundColor: surface2,
    colorScheme: const ColorScheme.dark(
      primary: primaryAccent,
      secondary: reading,
      surface: surface1,
      background: backgroundBase,
      error: primaryAccent,
      onPrimary: Colors.white,
      onSecondary: Colors.black,
      onSurface: textPrimary,
      onBackground: textPrimary,
      outline: border,
    ),
    textTheme: textTheme,
    appBarTheme: const AppBarTheme(
      backgroundColor: backgroundBase,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: textPrimary),
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        letterSpacing: -0.3,
      ),
    ),
    cardTheme: CardTheme(
      color: surface1,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: border, width: 1),
      ),
      margin: EdgeInsets.zero,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: surface2,
      modalBackgroundColor: surface2,
      elevation: 16,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: surface1,
      selectedItemColor: primaryAccent,
      unselectedItemColor: textSecondary,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
      selectedLabelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: primaryAccent,
      foregroundColor: Colors.white,
      elevation: 6,
      highlightElevation: 10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface2,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: border, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: border, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: primaryAccent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: primaryAccent, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: primaryAccent, width: 1.5),
      ),
      hintStyle: const TextStyle(color: textMuted, fontSize: 13),
      labelStyle: const TextStyle(color: textSecondary, fontSize: 13),
    ),
    dividerTheme: const DividerThemeData(
      color: border,
      thickness: 1,
      space: 1,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: surface2,
      contentTextStyle: const TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: border, width: 1),
      ),
      behavior: SnackBarBehavior.floating,
      elevation: 8,
    ),
  );
}

// ─── Backwards Compatibility Helpers ─────────────────────────────────────────
typedef AppColors = AppTheme;

ThemeData buildAppTheme() => AppTheme.theme;

class AppTypography {
  static const TextStyle cardTitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppTheme.textPrimary,
    height: 1.25,
  );

  static const TextStyle body = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.normal,
    color: AppTheme.textSecondary,
  );

  static const TextStyle badge = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
  );
}
