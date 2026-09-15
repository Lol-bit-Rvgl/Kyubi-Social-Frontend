import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/user.dart';
import 'app_colors.dart';
import 'app_dimensions.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get dark => buildDark();
  static ThemeData get light => buildLight();

  static ThemeData buildDark({UserThemeSettings? themeSettings}) {
    final effectivePrimary = themeSettings?.primary ?? AppColors.primary;
    final effectiveSecondary =
        themeSettings?.accent ?? deriveHarmonicSecondary(effectivePrimary);
    return _build(
      brightness: Brightness.dark,
      background: AppColors.obsidianBg,
      surface: AppColors.ink800,
      surfaceAlt: AppColors.ink700,
      textPrimary: AppColors.gray50,
      textSecondary: AppColors.gray400,
      border: AppColors.gray700,
      primaryColor: effectivePrimary,
      secondaryColor: effectiveSecondary,
    );
  }

  static ThemeData buildLight({UserThemeSettings? themeSettings}) {
    final effectivePrimary = themeSettings?.primary ?? AppColors.primary;
    final effectiveSecondary =
        themeSettings?.accent ?? deriveHarmonicSecondary(effectivePrimary);
    return _build(
      brightness: Brightness.light,
      background: AppColors.gray50,
      surface: Colors.white,
      surfaceAlt: AppColors.gray100,
      textPrimary: AppColors.ink900,
      textSecondary: AppColors.gray500,
      border: AppColors.gray200,
      primaryColor: effectivePrimary,
      secondaryColor: effectiveSecondary,
    );
  }

  /// Decoración de fondo cósmico reactivo de dos colores canónico de Kyubi.
  ///
  /// Base neutra profunda (`#0D0A14`) con resplandor superior izquierdo del color
  /// primario (`alpha: 0.22`), centro neutro profundo y base inferior derecha
  /// del color secundario armónico (`alpha: 0.18`).
  static BoxDecoration buildCosmicBackgroundDecoration(
    BuildContext context, {
    Color? primaryColor,
    Color? secondaryColor,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final effectivePrimary = primaryColor ?? scheme.primary;
    final effectiveSecondary = secondaryColor ?? scheme.secondary;
    return BoxDecoration(
      color: const Color(0xFF0D0A14),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          effectivePrimary.withValues(alpha: 0.22),
          const Color(0xFF0D0A14),
          effectiveSecondary.withValues(alpha: 0.18),
        ],
        stops: const [0.0, 0.5, 1.0],
      ),
    );
  }

  static ThemeData _build({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color surfaceAlt,
    required Color textPrimary,
    required Color textSecondary,
    required Color border,
    Color primaryColor = AppColors.primary,
    Color secondaryColor = AppColors.vhsCyan,
  }) {
    final isDark = brightness == Brightness.dark;
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: primaryColor,
      onPrimary: Colors.white,
      secondary: secondaryColor,
      onSecondary: Colors.black,
      error: AppColors.danger,
      onError: Colors.white,
      surface: surface,
      onSurface: textPrimary,
      surfaceContainerHighest: surfaceAlt,
      onSurfaceVariant: textSecondary,
      outline: border,
      outlineVariant: border,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: isDark ? Colors.white : AppColors.ink900,
      onInverseSurface: isDark ? AppColors.ink900 : Colors.white,
      inversePrimary: AppColors.primaryLight,
      onPrimaryContainer: isDark ? AppColors.ink900 : Colors.white,
      primaryContainer: isDark ? AppColors.primaryDark : AppColors.primaryLight,
      secondaryContainer: AppColors.ink700,
      onSecondaryContainer: AppColors.gray100,
      tertiary: AppColors.vhsFuchsia,
      onTertiary: Colors.white,
      tertiaryContainer: AppColors.ink700,
      onTertiaryContainer: AppColors.gray100,
      errorContainer: AppColors.danger.withAlpha(51),
      onErrorContainer: AppColors.danger,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: ZoomPageTransitionsBuilder(),
          TargetPlatform.windows: ZoomPageTransitionsBuilder(),
          TargetPlatform.macOS: ZoomPageTransitionsBuilder(),
          TargetPlatform.linux: ZoomPageTransitionsBuilder(),
        },
      ),
    );

    // ── Tipografía corporativa Nebulæ ────────────────────────────────────────
    // SpaceGrotesk define títulos/encabezados; Inter define cuerpos de texto y
    // subtítulos. Ambas se mantienen coherentes con la paleta Nebulæ.
    final spaceGrotesk = GoogleFonts.spaceGroteskTextTheme(base.textTheme);
    final inter = GoogleFonts.interTextTheme(base.textTheme);

    final textTheme = base.textTheme
        .copyWith(
          displayLarge: spaceGrotesk.displayLarge,
          displayMedium: spaceGrotesk.displayMedium,
          displaySmall: spaceGrotesk.displaySmall,
          headlineLarge: spaceGrotesk.headlineLarge,
          headlineMedium: spaceGrotesk.headlineMedium,
          headlineSmall: spaceGrotesk.headlineSmall,
          titleLarge: spaceGrotesk.titleLarge,
          titleMedium: inter.titleMedium,
          titleSmall: inter.titleSmall,
          bodyLarge: inter.bodyLarge,
          bodyMedium: inter.bodyMedium,
          bodySmall: inter.bodySmall,
          labelLarge: inter.labelLarge,
          labelMedium: inter.labelMedium,
          labelSmall: inter.labelSmall,
        )
        .apply(bodyColor: textPrimary, displayColor: textPrimary);

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: AppColors.primary.withAlpha(46),
        surfaceTintColor: Colors.transparent,
        height: AppDimens.bottomNavHeight,
        elevation: 0,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusFull),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.primary
                : textSecondary,
          ),
        ),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: textSecondary,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceGlass,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
          side: BorderSide(
            color: isDark ? AppColors.borderGlow : border.withAlpha(153),
            width: 1,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        // Shape intentionally not set: CircleBorder for regular FABs,
        // StadiumBorder for FloatingActionButton.extended (text label).
      ),
      dividerTheme: DividerThemeData(
        color: border.withAlpha(127),
        thickness: 0.6,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceGlass,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimens.md,
          vertical: AppDimens.sm,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          borderSide: BorderSide(color: AppColors.borderGlow),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          borderSide: BorderSide(color: AppColors.borderGlow),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          borderSide: const BorderSide(
            color: AppColors.accentCrimson,
            width: 1.4,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          borderSide: BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          borderSide: BorderSide(color: AppColors.danger, width: 1.4),
        ),
        hintStyle: TextStyle(color: textSecondary),
        labelStyle: TextStyle(color: textSecondary),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accentCrimson,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.radiusFull),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          minimumSize: const Size.fromHeight(48),
          side: BorderSide(color: AppColors.borderGlow),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.radiusFull),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AppColors.surfaceGlass,
        selectedColor: AppColors.accentCrimson.withAlpha(51),
        labelStyle: TextStyle(color: textPrimary),
        side: BorderSide(color: AppColors.borderGlow),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusFull),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.surfaceGlassStrong,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppDimens.radiusCard),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surfaceGlassStrong,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceGlassStrong,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: textSecondary,
        textColor: textPrimary,
        subtitleTextStyle: TextStyle(color: textSecondary),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.accentCrimson,
        linearTrackColor: AppColors.borderGlow.withAlpha(102),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.accentCrimson,
        unselectedLabelColor: textSecondary,
        indicatorColor: AppColors.accentCrimson,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}
