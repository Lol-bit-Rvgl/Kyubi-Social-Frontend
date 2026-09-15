import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Fondo fluido animado nativo (sin WebViews).
///
/// Renderiza una imagen decorativa con un zoom suave oscilante (~1.05 ↔ 1.20)
/// y un desplazamiento sinusoidal continuo (±35px en X, ±25px en Y), creando
/// un efecto orgánico de "líquido" en movimiento sin caídas de frames
/// (~20s, reversible).
///
/// Uso:
/// ```dart
/// AnimatedFluidBackground(
///   assetPath: 'assets/images/bg_fluid_login.webp',
///   overlayDarkness: 0.32,
///   child: Scaffold(backgroundColor: Colors.transparent, ...),
/// )
/// ```
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

  /// Opacidad del scrim oscuro `Color(0xFF0D0D12)` (0.0–1.0).
  /// Por defecto 0.45 para que el arte fluido se aprecie; en login usar
  /// ~0.30 a 0.35.
  final double overlayDarkness;

  @override
  State<AnimatedFluidBackground> createState() =>
      _AnimatedFluidBackgroundState();
}

class _AnimatedFluidBackgroundState extends State<AnimatedFluidBackground>
    with SingleTickerProviderStateMixin {
  static const _scrimColor = Color(0xFF0D0D12);
  static const double _minScale = 1.05;
  static const double _maxScale = 1.20;
  static const double _maxOffsetX = 35.0;
  static const double _maxOffsetY = 25.0;

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Base: la capa fluida ocupa toda la pantalla y no captura gestos.
        IgnorePointer(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, image) {
              final t = _controller.value;
              // Zoom suave 1.05 ↔ 1.20 (coseno para arranque en fase cero).
              final scale =
                  _minScale +
                  (_maxScale - _minScale) *
                      ((1 - math.cos(2 * math.pi * t)) / 2);
              // Deriva sinusoidal en X e Y con fases desfasadas (órbita suave).
              final dx = _maxOffsetX * math.sin(2 * math.pi * t);
              final dy = _maxOffsetY * math.sin(4 * math.pi * t + math.pi / 3);
              return Transform.translate(
                offset: Offset(dx, dy),
                child: Transform.scale(scale: scale, child: image),
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
