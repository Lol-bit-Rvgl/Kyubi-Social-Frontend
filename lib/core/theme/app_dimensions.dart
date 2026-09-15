import 'package:flutter/widgets.dart';

/// Métricas y dimensiones consistentes.
class AppDimens {
  AppDimens._();

  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  static const double radiusXs = 6;
  static const double radiusSm = 10;
  static const double radiusMd = 16;
  static const double radiusCard = 20;
  static const double radiusChip = 12;
  static const double radiusLg = 24;
  static const double radiusFull = 999;

  static const double avatarSm = 32;
  static const double avatarMd = 48;
  static const double avatarLg = 72;
  static const double avatarXl = 96;

  static const double bottomNavHeight = 68;
  static const double appBarHeight = 56;
  static const double maxContentWidth = 600;
  static const double profileBannerHeight = 150;

  /// Movimiento y microinteracciones.
  static const Duration motionFast = Duration(milliseconds: 150);
  static const Duration motionBase = Duration(milliseconds: 260);
  static const Duration motionSlow = Duration(milliseconds: 420);
  static const Curve curveStandard = Curves.easeOutCubic;
  static const Curve curveSnappy = Curves.easeOutBack;

  static const EdgeInsets pagePadding = EdgeInsets.symmetric(
    horizontal: md,
    vertical: sm,
  );

  static const EdgeInsets cardPadding = EdgeInsets.all(md);
}
