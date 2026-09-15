import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Nebulæ palette ───────────────────────────────────────────────────────
  static const Color backgroundBase = Color(0xFF0F0B25);
  static const Color surfaceCards = Color(0xFF2B0D3A);
  static const Color surfaceAlt = Color(0xFF3F2A7C);
  static const Color borderNight = Color(0xFF5E35B1);
  static const Color primary = Color(0xFFD100D1);
  static const Color secondary = Color(0xFF6A00A8);
  static const Color brandAccent = Color(0xFF7B2CBF);
  static const Color textSecondary = Color(0xFF9575CD);
  static const Color accentTeal = Color(0xFF00D4B4);
  static const Color accentBlue = Color(0xFF7EC8E3);

  /// Borde translúcido sutil (blanco α0.08). Divisores y bordes finos.
  static const Color borderGlass = Color(0x14FFFFFF);

  /// Borde brand translúcido alternativo a [borderGlass].
  static const Color borderNightGlass = Color(0xFF2A1F4D);

  /// Texto secundario/muted con tono Nebulæ (derivado de onSurfaceVariant).
  static const Color textMutedNebulae = Color(0xFF9E9EA8);

  // ── Legacy names (backwards compatible) ──────────────────────────────────
  static const Color obsidianBg = backgroundBase;
  static const Color surfaceGlass = Color(0x332B0D3A);
  static const Color surfaceGlassStrong = Color(0x552B0D3A);

  static const Color accentCrimson = primary;
  static const Color accentCyan = accentTeal;
  static const Color accentPurple = brandAccent;
  static const Color borderGlow = Color(0x405E35B1);

  static const Color primaryDark = Color(0xFF9B009B);
  static const Color primaryLight = primary;

  static const Color primarySoft = Color(0xFFF3E5F5);
  static const Color primarySoftDark = Color(0xFF1A0033);

  static const Color ink900 = backgroundBase;
  static const Color ink800 = Color(0xFF150E30);
  static const Color ink700 = Color(0xFF1E1540);
  static const Color ink600 = surfaceCards;

  static const Color gray50 = Color(0xFFF7F7F8);
  static const Color gray100 = Color(0xFFE9E9EC);
  static const Color gray200 = Color(0xFFD4D4D9);
  static const Color gray300 = Color(0xFFB3B3BB);
  static const Color gray400 = Color(0xFF8E8E98);
  static const Color gray500 = Color(0xFF6E6E78);
  static const Color gray600 = Color(0xFF52525C);
  static const Color gray700 = Color(0xFF3A3A44);
  static const Color gray800 = Color(0xFF26262E);

  static const Color success = accentTeal;
  static const Color warning = Color(0xFFFF9100);
  static const Color danger = Color(0xFFEF4444);
  static const Color info = accentBlue;

  static const Color vhsFuchsia = primary;
  static const Color vhsCyan = accentTeal;
  static const Color vhsTape = surfaceCards;
  static const Color vhsScanline = Color(0x0D9575CD);
  static const Color vhsActionPurple = textSecondary;
  static const Color vhsActionBg = Color(0xFF1A0033);

  // ── Gradients ─────────────────────────────────────────────────────────────
  static const LinearGradient brandGradient = LinearGradient(
    colors: [primary, brandAccent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [primary, accentTeal],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient purpleGlow = LinearGradient(
    colors: [brandAccent, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient tealGlow = LinearGradient(
    colors: [accentTeal, Color(0xFF007A63)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Calm night gradient (Liquid Glass) — lavanda → azul pizarra
  static const LinearGradient nightGradient = LinearGradient(
    colors: [Color(0xFF382C5E), Color(0xFF233554)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Liquid Glass / Squircles ─────────────────────────────────────────────
  // Violeta noche translúcido → azul medianoche (paneles de cristal líquido).
  static const LinearGradient glassGradient = LinearGradient(
    colors: [Color(0xB316113A), Color(0xD90B081F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Degradados de acciones (reemplazan los colores planos saturados).
  static const LinearGradient mintTurquoise = LinearGradient(
    colors: [Color(0xFF00E5A3), Color(0xFF00B4D8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient crimsonBurgundy = LinearGradient(
    colors: [Color(0xFFFF4B72), Color(0xFF9B1D36)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Keep old gradient names for compatibility
  static const LinearGradient crimsonGlow = purpleGlow;
  static const LinearGradient cyanGlow = tealGlow;

  // ── Helpers ───────────────────────────────────────────────────────────────
  static Color avatarColor(String seed) {
    const palette = [
      primary,
      brandAccent,
      secondary,
      accentTeal,
      accentBlue,
      textSecondary,
      Color(0xFF00E676),
      Color(0xFFFF9100),
    ];
    final hash = seed.codeUnits.fold<int>(0, (acc, c) => acc + c);
    return palette[hash % palette.length];
  }

  static Color fromHex(String? hex) {
    if (hex == null || hex.isEmpty) return primary;
    final buffer = StringBuffer();
    final clean = hex.replaceFirst('#', '');
    if (clean.length != 6 && clean.length != 8) return primary;
    if (clean.length == 6) buffer.write('FF');
    buffer.write(clean);
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}
