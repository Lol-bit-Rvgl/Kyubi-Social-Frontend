import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';

/// Enumeration for accent glow variants on the glass card.
enum GlowVariant { none, crimson, cyan, purple }

/// A reusable glassmorphism card with obsidian background, subtle glass
/// border, and optional neon glow accent. Used across Feed, Salas,
/// Circles, Chats, Marketplace and Profile screens.
class KyubiGlassCard extends StatelessWidget {
  const KyubiGlassCard({
    super.key,
    required this.child,
    this.glow = GlowVariant.none,
    this.enableBlur = false,
    this.borderRadius,
    this.padding,
    this.margin,
    this.onTap,
  });

  final Widget child;
  final GlowVariant glow;
  final bool enableBlur;
  final double? borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  Color get _glowColor {
    switch (glow) {
      case GlowVariant.crimson:
        // Tono calmado (morado/ciruela desaturado) en vez del fucsia neón.
        return const Color(0xFF9B6FCB);
      case GlowVariant.cyan:
        return AppColors.accentCyan;
      case GlowVariant.purple:
        return AppColors.accentPurple;
      case GlowVariant.none:
        return AppColors.borderGlow;
    }
  }

  Color get _shadowColor {
    switch (glow) {
      case GlowVariant.crimson:
        return const Color(0xFF7A5AA6);
      case GlowVariant.cyan:
        return AppColors.accentCyan;
      case GlowVariant.purple:
        return AppColors.accentPurple;
      case GlowVariant.none:
        return Colors.transparent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? AppDimens.radiusCard;
    final effectivePadding = padding ?? const EdgeInsets.all(AppDimens.md);

    final decor = BoxDecoration(
      color: AppColors.surfaceGlass,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: glow != GlowVariant.none
            ? _glowColor.withValues(alpha: 0.35)
            : AppColors.borderGlow,
        width: 1,
      ),
      boxShadow: glow != GlowVariant.none
          ? [
              BoxShadow(
                color: _shadowColor.withValues(alpha: 0.15),
                blurRadius: 24,
                spreadRadius: -4,
              ),
            ]
          : null,
    );

    final content = Container(
      margin: margin,
      decoration: decor,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: enableBlur
            ? BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Padding(padding: effectivePadding, child: child),
              )
            : Padding(padding: effectivePadding, child: child),
      ),
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: content);
    }
    return content;
  }
}

/// Compact variant of glass card for chips/tags in lists. Uses smaller
/// radius and no blur, suitable for long ListView/GridView items
/// (performance-safe).
class KyubiGlassChip extends StatelessWidget {
  const KyubiGlassChip({
    super.key,
    required this.child,
    this.glow = GlowVariant.none,
    this.padding,
    this.onTap,
  });

  final Widget child;
  final GlowVariant glow;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  Color get _glowColor {
    switch (glow) {
      case GlowVariant.crimson:
        return const Color(0xFF9B6FCB);
      case GlowVariant.cyan:
        return AppColors.accentCyan;
      case GlowVariant.purple:
        return AppColors.accentPurple;
      case GlowVariant.none:
        return AppColors.borderGlow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(AppDimens.radiusChip),
        border: Border.all(
          color: glow != GlowVariant.none
              ? _glowColor.withValues(alpha: 0.4)
              : AppColors.borderGlow,
          width: 1,
        ),
      ),
      child: child,
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: content);
    }
    return content;
  }
}
