import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Paleta do Homefy (tokens herdados do FlutterFlow, refinados).
class HomefyColors {
  HomefyColors._();

  // Marca (identidade v2, 03/10/2026)
  static const primary = Color(0xFF13604A); // verde-mandacaru: confiança
  static const primaryDark = Color(0xFF0B3D2F);
  static const secondary = Color(0xFF3E9C77);
  static const mint = Color(0xFFDDF1E6); // verde bem suave (fundos)
  static const sol = Color(0xFFF5B82E); // amarelo-sol do agreste: a porta da logo
  static const solSuave = Color(0xFFFFF3D6);
  static const tertiary = Color(0xFF0077B6); // azul de avisos

  // Neutros
  static const background = Color(0xFFF4F6F3);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFE3E8E4);
  static const text = Color(0xFF16201B);
  static const textSecondary = Color(0xFF55615A);
  static const textMuted = Color(0xFF8E9A93);

  // Estados
  static const error = Color(0xFFC81D25);
  static const warning = Color(0xFFB7791F);

  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryDark, primary],
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

  final body = GoogleFonts.figtreeTextTheme(base.textTheme);
  final display = GoogleFonts.bricolageGrotesqueTextTheme(base.textTheme);

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
    appBarTheme: AppBarTheme(
      backgroundColor: HomefyColors.background,
      surfaceTintColor: Colors.transparent,
      foregroundColor: HomefyColors.text,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      titleTextStyle: textTheme.titleLarge,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: HomefyColors.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: HomefyColors.mint,
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith((s) => textTheme.labelMedium?.copyWith(
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
            color: s.contains(WidgetState.selected) ? HomefyColors.primary : HomefyColors.textSecondary,
          )),
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
            color: s.contains(WidgetState.selected) ? HomefyColors.primary : HomefyColors.textSecondary,
          )),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: HomefyColors.surface,
      selectedColor: HomefyColors.mint,
      side: const BorderSide(color: HomefyColors.border),
      labelStyle: textTheme.labelLarge?.copyWith(color: HomefyColors.text),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: HomefyColors.primary,
        minimumSize: const Size.fromHeight(52),
        side: const BorderSide(color: HomefyColors.border, width: 1.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(HomefySpace.radiusMd)),
        textStyle: textTheme.labelLarge?.copyWith(fontSize: 15),
      ),
    ),
  );
}
