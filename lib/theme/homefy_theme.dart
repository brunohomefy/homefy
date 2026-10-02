import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Paleta do Homefy (tokens herdados do FlutterFlow, refinados).
class HomefyColors {
  HomefyColors._();

  // Marca
  static const primary = Color(0xFF2D6A4F); // verde principal
  static const primaryDark = Color(0xFF1B4332);
  static const secondary = Color(0xFF52B788); // verde claro
  static const mint = Color(0xFFD8F3DC); // verde bem suave (fundos)
  static const tertiary = Color(0xFF0077B6); // azul de destaque

  // Neutros
  static const background = Color(0xFFF6F8F7);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFE6EBE8);
  static const text = Color(0xFF14201A);
  static const textSecondary = Color(0xFF5B6660);
  static const textMuted = Color(0xFF98A29C);

  // Estados
  static const error = Color(0xFFD90429);
  static const warning = Color(0xFFFFB703);

  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1B4332), primary, Color(0xFF40916C)],
  );
}

/// Espaçamentos e raios usados em todo o app.
class HomefySpace {
  HomefySpace._();
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;

  static const radiusSm = 12.0;
  static const radiusMd = 16.0;
  static const radiusLg = 24.0;
  static const radiusXl = 32.0;
}

/// Sombra suave, usada em cards e botões flutuantes.
const homefyShadow = [
  BoxShadow(
    color: Color(0x0F14201A),
    blurRadius: 24,
    offset: Offset(0, 8),
  ),
  BoxShadow(
    color: Color(0x0A14201A),
    blurRadius: 4,
    offset: Offset(0, 1),
  ),
];

ThemeData buildHomefyTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: HomefyColors.primary,
      primary: HomefyColors.primary,
      secondary: HomefyColors.secondary,
      tertiary: HomefyColors.tertiary,
      surface: HomefyColors.surface,
      error: HomefyColors.error,
    ),
    scaffoldBackgroundColor: HomefyColors.background,
  );

  final body = GoogleFonts.interTextTheme(base.textTheme);
  final display = GoogleFonts.plusJakartaSansTextTheme(base.textTheme);

  final textTheme = body.copyWith(
    displaySmall: display.displaySmall?.copyWith(
        fontWeight: FontWeight.w800, color: HomefyColors.text, letterSpacing: -1),
    headlineMedium: display.headlineMedium?.copyWith(
        fontWeight: FontWeight.w800, color: HomefyColors.text, letterSpacing: -0.8),
    headlineSmall: display.headlineSmall?.copyWith(
        fontWeight: FontWeight.w800, color: HomefyColors.text, letterSpacing: -0.5),
    titleLarge: display.titleLarge?.copyWith(
        fontWeight: FontWeight.w700, color: HomefyColors.text, letterSpacing: -0.3),
    titleMedium: display.titleMedium?.copyWith(
        fontWeight: FontWeight.w700, color: HomefyColors.text),
    bodyLarge: body.bodyLarge?.copyWith(color: HomefyColors.text),
    bodyMedium: body.bodyMedium?.copyWith(color: HomefyColors.textSecondary),
    bodySmall: body.bodySmall?.copyWith(color: HomefyColors.textSecondary),
    labelLarge: body.labelLarge?.copyWith(fontWeight: FontWeight.w600),
  );

  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(HomefySpace.radiusMd),
        borderSide: BorderSide(color: c, width: w),
      );

  return base.copyWith(
    textTheme: textTheme,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: HomefyColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      hintStyle: textTheme.bodyMedium?.copyWith(color: HomefyColors.textMuted),
      labelStyle: textTheme.bodyMedium,
      prefixIconColor: HomefyColors.textMuted,
      suffixIconColor: HomefyColors.textMuted,
      border: border(HomefyColors.border),
      enabledBorder: border(HomefyColors.border),
      focusedBorder: border(HomefyColors.primary, 1.6),
      errorBorder: border(HomefyColors.error),
      focusedErrorBorder: border(HomefyColors.error, 1.6),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: HomefyColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(HomefySpace.radiusMd)),
        textStyle: textTheme.labelLarge?.copyWith(fontSize: 16),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: HomefyColors.primary,
        textStyle: textTheme.labelLarge,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: HomefyColors.text,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HomefySpace.radiusSm)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: HomefyColors.surface,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(HomefySpace.radiusXl)),
      ),
    ),
    dividerTheme: const DividerThemeData(color: HomefyColors.border, thickness: 1),
  );
}
