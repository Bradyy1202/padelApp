import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tema de la app aplicando UI/UX Pro Max (estilo sporty/competitivo):
/// - Paleta de marca: teal de "cancha" + acento lima energético (tokens semánticos).
/// - Tipografía: pareja Sora (títulos) / Inter (cuerpo).
/// - Componentes M3 con touch targets ≥48dp, escala de espaciado 8pt y elevación consistente.
class AppColors {
  static const brand = Color(0xFF0F6E5E); // teal cancha
  static const accent = Color(0xFFB6FF3B); // lima energía (highlights/rating)
  static const accentInk = Color(0xFF14361A); // texto sobre acento
  static const danger = Color(0xFFE5484D);
  static const warning = Color(0xFFE8A317);
  static const success = Color(0xFF2BB673);

  // Degradado del hero de rating.
  static const heroGradient = [Color(0xFF0F6E5E), Color(0xFF12907A)];
}

class AppTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.brand,
      brightness: brightness,
    ).copyWith(
      tertiary: AppColors.accent,
      onTertiary: AppColors.accentInk,
      error: AppColors.danger,
    );

    final base = ThemeData(brightness: brightness, useMaterial3: true, colorScheme: scheme);
    final text = _textTheme(base.textTheme, scheme.onSurface);

    return base.copyWith(
      scaffoldBackgroundColor: isDark ? const Color(0xFF0E1513) : const Color(0xFFF5F8F6),
      textTheme: text,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.sora(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
        iconTheme: IconThemeData(color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          textStyle: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          textStyle: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.4 : 0.6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1),
    );
  }

  static TextTheme _textTheme(TextTheme base, Color color) {
    final body = GoogleFonts.interTextTheme(base);
    TextStyle sora(TextStyle? s, FontWeight w) =>
        GoogleFonts.sora(textStyle: s, fontWeight: w, color: color);
    return body.copyWith(
      displayLarge: sora(base.displayLarge, FontWeight.w700),
      displayMedium: sora(base.displayMedium, FontWeight.w700),
      displaySmall: sora(base.displaySmall, FontWeight.w700),
      headlineMedium: sora(base.headlineMedium, FontWeight.w700),
      headlineSmall: sora(base.headlineSmall, FontWeight.w600),
      titleLarge: sora(base.titleLarge, FontWeight.w600),
    );
  }
}
