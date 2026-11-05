import 'package:flutter/material.dart';

class ApexTheme {
  static const Color obsidianBg = Color(0xFF0A0D12);
  static const Color cardGraphite = Color(0xFF131822);
  static const Color cardBorder = Color(0xFF222B3B);
  static const Color voltAccent = Color(0xFFCCFF00);
  static const Color cyanElectric = Color(0xFF00F0FF);
  static const Color readinessGreen = Color(0xFF00E676);
  static const Color warningAmber = Color(0xFFFFB300);
  static const Color deloadCrimson = Color(0xFFFF3D57);
  static const Color textPrimary = Color(0xFFF3F6FA);
  static const Color textMuted = Color(0xFF8C9BAE);

  static Color readinessColor(double recoveryScore) {
    if (recoveryScore < 40.0) {
      return deloadCrimson;
    }
    if (recoveryScore <= 80.0) {
      return warningAmber;
    }
    return readinessGreen;
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: obsidianBg,
      colorScheme: const ColorScheme.dark(
        primary: voltAccent,
        secondary: cyanElectric,
        surface: cardGraphite,
        error: deloadCrimson,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: obsidianBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: kToolbarHeight,
        titleSpacing: 12,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 16.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardGraphite,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: cardBorder, width: 1.1),
        ),
      ),
    );
  }
}
