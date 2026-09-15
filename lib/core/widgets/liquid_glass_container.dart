import 'dart:ui';

import 'package:flutter/material.dart';

/// Estilo visual del contenedor Liquid Glass.
enum GlassStyle {
  /// Difuminado cósmico suave con mayor desenfoque y tinte protector.
  frosted,

  /// Transparente cristal con desenfoque mínimo y alta translucidez,
  /// permitiendo apreciar el arte del banner o fondo nítidamente.
  transparent;

  static GlassStyle fromString(String? value) {
    if (value == 'transparent') return GlassStyle.transparent;
    return GlassStyle.frosted;
  }

  String toValue() => name;
}

/// Contenedor universal de vidrio líquido (Liquid Glass).
///
/// Implementa el estilo Liquid Glass con gradiente perimetral (morados arriba,
/// verde sutil abajo o personalizable según tema del usuario), desenfoque de fondo
/// `BackdropFilter`, tinte semitransparente y sombra suave.
class LiquidGlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double blur;
  final double? width;
  final double? height;
  final Color? tint;
  final Color? tintColor;
  final VoidCallback? onTap;
  final GlassStyle style;
  final LinearGradient? customBorderGradient;
  final Color? primaryColor;
  final Color? accentColor;

  const LiquidGlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 18.0,
    this.padding = const EdgeInsets.all(14.0),
    this.margin,
    this.blur = 12.0,
    this.width,
    this.height,
    this.tint,
    this.tintColor,
    this.onTap,
    this.style = GlassStyle.frosted,
    this.customBorderGradient,
    this.primaryColor,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectivePrimary = primaryColor ?? theme.colorScheme.primary;
    final effectiveAccent = accentColor ?? theme.colorScheme.secondary;

    final borderGradient = customBorderGradient ??
        LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            effectivePrimary.withValues(alpha: 0.55),
            effectivePrimary.withValues(alpha: 0.25),
            effectiveAccent.withValues(alpha: 0.40),
          ],
          stops: const [0.0, 0.65, 1.0],
        );

    final effectiveBlur = style == GlassStyle.transparent
        ? (blur == 12.0 ? 2.0 : blur)
        : blur;

    const neutralDarkBg = Color(0xFF0D0A14);
    final effectiveTint = tintColor ?? tint ??
        (style == GlassStyle.transparent
            ? neutralDarkBg.withValues(alpha: 0.11)
            : neutralDarkBg.withValues(alpha: 0.55));

    final innerRadius = borderRadius > 1.2 ? borderRadius - 1.2 : borderRadius;

    Widget content = ClipRRect(
      borderRadius: BorderRadius.circular(innerRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: effectiveBlur, sigmaY: effectiveBlur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: effectiveTint,
            borderRadius: BorderRadius.circular(innerRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: style == GlassStyle.transparent ? 0.12 : 0.25,
                ),
                blurRadius: style == GlassStyle.transparent ? 8 : 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );

    // Renderizar el borde degradado con Container y padding
    content = Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: borderGradient,
      ),
      padding: const EdgeInsets.all(1.2), // Espesor del borde líquido
      child: content,
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: content,
      );
    }
    return content;
  }
}
