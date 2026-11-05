import 'package:flutter/material.dart';

/// Sistema de Diseño "TECHNICAL PITWALL":
/// Paleta de instrumentación e ingeniería deportiva de alto contraste
/// (cero colores "IA Neón", sin resplandores ni sombras de color).
class ApexTheme {
  /// Background base: Grafito mate oscuro (#0A0B0E)
  static const Color obsidianBg = Color(0xFF0A0B0E);

  /// Cards y contenedores: (#14171E) con bordes finos de 1px en (#232834)
  static const Color cardGraphite = Color(0xFF14171E);
  static const Color cardBorder = Color(0xFF232834);
  static const Color borderGraphite = Color(0xFF232834);

  /// Superficies y bordes secundarios para botones outline (#1A1E27 / #2C3242)
  static const Color secondarySurface = Color(0xFF1A1E27);
  static const Color secondaryBorder = Color(0xFF2C3242);
  static const Color buttonSecondaryBg = Color(0xFF1A1E27);
  static const Color buttonSecondaryBorder = Color(0xFF2C3242);

  /// Acentos primarios de instrumentación (Blanco técnico #F8FAFC y Acero #94A3B8)
  static const Color voltAccent = Color(0xFFF8FAFC);
  static const Color cyanElectric = Color(0xFF94A3B8);

  /// Semáforo funcional y métricas biométricas
  /// - Recuperación alta / Zonas seguras: Verde técnico (#10B981)
  /// - Zona media / Carga / Strain: Ámbar técnico (#F59E0B)
  /// - Zona baja / Estrés elevado / Alerta: Carmesí de instrumentación (#EF4444)
  static const Color readinessGreen = Color(0xFF10B981);
  static const Color warningAmber = Color(0xFFF59E0B);
  static const Color deloadCrimson = Color(0xFFEF4444);

  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textMuted = Color(0xFF8B95A5);

  static Color readinessColor(double recoveryScore) {
    if (recoveryScore < 34.0) {
      return deloadCrimson;
    }
    if (recoveryScore < 67.0) {
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
        onPrimary: obsidianBg,
        secondary: cyanElectric,
        onSecondary: obsidianBg,
        surface: cardGraphite,
        onSurface: textPrimary,
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
          fontSize: 15.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardGraphite,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: cardBorder, width: 1.0),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: voltAccent,
          foregroundColor: obsidianBg,
          elevation: 0,
          shadowColor: Colors.transparent,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            letterSpacing: 0.3,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: secondarySurface,
          foregroundColor: textPrimary,
          elevation: 0,
          shadowColor: Colors.transparent,
          side: const BorderSide(color: secondaryBorder, width: 1.0),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 11.5,
            letterSpacing: 0.3,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: obsidianBg,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 11,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: cardBorder, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: voltAccent, width: 1.2),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: cardBorder, width: 1.0),
        ),
      ),
    );
  }
}
