import 'package:flutter/material.dart';

/// Fondo ambiental cósmico: resplandores radiales dinámicos de 2 colores
/// (primario y secundario) sobre base obsidiana (#0D0A14).
///
/// Da profundidad a pantallas sin llenar la interfaz de color. Se coloca
/// detrás del contenido y se ignora la interacción.
class BrandBackdrop extends StatelessWidget {
  const BrandBackdrop({super.key, this.strength = 1.0, this.texture = false});

  final double strength;
  final bool texture;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final top = isDark ? 0.22 : 0.08;
    final bottom = isDark ? 0.18 : 0.06;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final secondaryColor = Theme.of(context).colorScheme.secondary;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Base neutral deep dark
        const ColoredBox(color: Color(0xFF0D0A14)),
        // Fondo cósmico reactivo
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                primaryColor.withValues(alpha: 0.22 * strength),
                const Color(0xFF0D0A14),
                secondaryColor.withValues(alpha: 0.18 * strength),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),
        // Top-left primary glow
        Positioned(
          top: -120,
          left: -80,
          child: _Glow(
            size: 300,
            color: primaryColor,
            opacity: top * strength,
          ),
        ),
        // Bottom-right secondary glow
        Positioned(
          bottom: -150,
          right: -110,
          child: _Glow(
            size: 340,
            color: secondaryColor,
            opacity: bottom * strength,
          ),
        ),
      ],
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.color, required this.opacity});

  final double size;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: opacity),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}
