import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Fondo cósmico fluido y estabilizado con respiración suave (sin WebViews).
///
/// Renderiza la decoración cósmica canónica de 2 colores (#0D0A14 base,
/// resplandor primario superior-izquierdo y secundario inferior-derecho)
/// y un sutil efecto de "respiración" orgánico sin desplazamientos
/// bruscos ni saltos de traslación en los bordes.
class AnimatedFluidBackground extends StatefulWidget {
  const AnimatedFluidBackground({
    super.key,
    required this.assetPath,
    required this.child,
    this.overlayDarkness = 0.45,
  });

  /// Ruta del asset (ej. `assets/images/bg_fluid_login.webp`).
  final String assetPath;

  /// Contenido interactivo sobre la capa de scrim.
  final Widget child;

  /// Opacidad del scrim oscuro `Color(0xFF0D0A14)` (0.0–1.0).
  final double overlayDarkness;

  @override
  State<AnimatedFluidBackground> createState() =>
      _AnimatedFluidBackgroundState();
}

class _AnimatedFluidBackgroundState extends State<AnimatedFluidBackground>
    with SingleTickerProviderStateMixin {
  static const _scrimColor = Color(0xFF0D0A14);

  late final AnimationController _controller;
  late final Animation<double> _breathingAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat(reverse: true);
    _breathingAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final secondaryColor = Theme.of(context).colorScheme.secondary;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Fondo cósmico neutro de 2 colores canónico
        DecoratedBox(
          decoration: AppTheme.buildCosmicBackgroundDecoration(
            context,
            primaryColor: primaryColor,
            secondaryColor: secondaryColor,
          ),
        ),

        // Base: capa fluida estabilizada con respiración sutil (cero temblores o traslaciones en bordes)
        IgnorePointer(
          child: ClipRect(
            child: AnimatedBuilder(
              animation: _breathingAnimation,
              builder: (context, child) {
                final t = _breathingAnimation.value;
                // Efecto de respiración suave (escala 1.00 ↔ 1.02, opacidad 0.88 ↔ 1.00)
                final scale = 1.00 + (0.02 * t);
                final opacity = 0.88 + (0.12 * t);
                return Opacity(
                  opacity: opacity,
                  child: Transform.scale(
                    scale: scale,
                    child: child,
                  ),
                );
              },
              child: Image.asset(
                widget.assetPath,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const ColoredBox(color: _scrimColor),
              ),
            ),
          ),
        ),

        // Scrim oscuro configurable.
        IgnorePointer(
          child: ColoredBox(
            color: _scrimColor.withValues(alpha: widget.overlayDarkness),
          ),
        ),

        // Contenido interactivo.
        widget.child,
      ],
    );
  }
}
