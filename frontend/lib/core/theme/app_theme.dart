import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// GarajOS gamified palette. Deep slate/navy "dark garage" background with a
/// neon spark-plug green as the primary accent, electric blue + vibrant
/// orange as secondary/warning accents. Keep all raw hexes here — every
/// screen should reference AppColors, never inline hex values.
class AppColors {
  AppColors._();

  static const bg = Color(0xFF0A0F13);
  static const surface = Color(0xFF0F161C);
  static const surfaceRaised = Color(0xFF141C22);
  static const border = Color(0xFF1C262E);

  static const neonGreen = Color(0xFF42FF8A);
  static const neonGreenDim = Color(0xFF1FCF64);
  static const electricBlue = Color(0xFF00C2FF);
  static const vividOrange = Color(0xFFFF9A44);

  static const textHigh = Color(0xFFE9F3EE);
  static const textMuted = Color(0xFF7E8D97);
  static const textFaint = Color(0xFF4C5960);

  static const draft = textMuted;
  static const completed = vividOrange;
  static const paid = neonGreen;

  static Color statusColor(String status) => switch (status) {
        'draft' => draft,
        'completed' => completed,
        'paid' => paid,
        _ => textMuted,
      };
}

/// Font helpers backing the `fontFamily: 'Montserrat' / 'Poppins' / 'RobotoMono'`
/// string literals used throughout the gamified widgets — those files were
/// authored assuming google_fonts (or bundled font assets) would be wired up
/// separately, per their own header comments. Centralised here so every
/// call site gets the real font instead of silently falling back to the
/// platform default.
class AppFonts {
  AppFonts._();

  static TextStyle header([TextStyle? textStyle]) => GoogleFonts.montserrat(textStyle: textStyle);
  static TextStyle body([TextStyle? textStyle]) => GoogleFonts.poppins(textStyle: textStyle);
  static TextStyle mono([TextStyle? textStyle]) => GoogleFonts.robotoMono(textStyle: textStyle);
}

class AppTheme {
  static ThemeData dark() {
    final scheme = const ColorScheme.dark(
      brightness: Brightness.dark,
      primary: AppColors.neonGreen,
      onPrimary: Color(0xFF04170C),
      secondary: AppColors.electricBlue,
      onSecondary: Color(0xFF04141A),
      tertiary: AppColors.vividOrange,
      error: Color(0xFFFF5C5C),
      surface: AppColors.surface,
      onSurface: AppColors.textHigh,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.bg,
      canvasColor: AppColors.bg,
      fontFamily: AppFonts.body().fontFamily,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      textTheme: TextTheme(
        headlineSmall: AppFonts.header(const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textHigh)),
        titleLarge: AppFonts.header(const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textHigh)),
        titleMedium: AppFonts.header(const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textHigh)),
        bodyLarge: AppFonts.body(const TextStyle(color: AppColors.textHigh)),
        bodyMedium: AppFonts.body(const TextStyle(color: AppColors.textHigh)),
        labelLarge: AppFonts.body(const TextStyle(fontWeight: FontWeight.w600)),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: const Color(0xFF0D1318),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: AppFonts.header(const TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: AppColors.textHigh)),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.border)),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(color: AppColors.border, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceRaised,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.neonGreen, width: 1.5)),
        labelStyle: const TextStyle(color: AppColors.textMuted),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.neonGreen,
          foregroundColor: const Color(0xFF04170C),
          textStyle: AppFonts.header(const TextStyle(fontWeight: FontWeight.w700)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceRaised,
        selectedColor: AppColors.neonGreenDim,
        side: const BorderSide(color: AppColors.border),
        labelStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: const Color(0xFF0D1318),
        selectedIconTheme: const IconThemeData(color: AppColors.neonGreen),
        unselectedIconTheme: const IconThemeData(color: AppColors.textMuted),
        selectedLabelTextStyle: const TextStyle(color: AppColors.neonGreen, fontWeight: FontWeight.w600, fontSize: 11),
        unselectedLabelTextStyle: const TextStyle(color: AppColors.textMuted, fontSize: 11),
        indicatorColor: AppColors.neonGreenDim.withValues(alpha: 0.18),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF0D1318),
        indicatorColor: AppColors.neonGreenDim.withValues(alpha: 0.18),
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: states.contains(WidgetState.selected) ? AppColors.neonGreen : AppColors.textMuted,
            )),
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              color: states.contains(WidgetState.selected) ? AppColors.neonGreen : AppColors.textMuted,
            )),
      ),
    );
  }

  /// Light theme kept as a fallback (e.g. system light mode); the product is
  /// dark-mode-first per spec — app.dart sets `themeMode: ThemeMode.dark`, so
  /// this is only reachable if that's ever changed back to `ThemeMode.system`.
  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: AppColors.neonGreenDim, brightness: Brightness.light),
      visualDensity: VisualDensity.adaptivePlatformDensity,
      appBarTheme: const AppBarTheme(centerTitle: false),
      inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
    );
  }
}
