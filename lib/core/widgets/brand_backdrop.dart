import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Fondo ambiental cyberpunk: resplandores radiales de crimson y purple
/// sobre obsidiana, con textura sutil opcional.
///
/// Da profundidad a pantallas sin llenar la interfaz de color. Se coloca
/// detrás del contenido y se ignora la interacción.
class BrandBackdrop extends StatelessWidget {
  const BrandBackdrop({super.key, this.strength = 1.0, this.texture = true});

  final double strength;
  final bool texture;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final top = isDark ? 0.12 : 0.05;
    final bottom = isDark ? 0.14 : 0.04;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Base obsidian
        const ColoredBox(color: AppColors.obsidianBg),
        // Textura sutil (si existe el asset)
        if (texture)
          Positioned.fill(
            child: Opacity(
              opacity: 0.08,
              child: Image.asset(
                'assets/images/profile/background_texture.jpg',
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
        // Top-left crimson glow
        Positioned(
          top: -120,
          left: -80,
          child: _Glow(
            size: 300,
            color: AppColors.accentCrimson,
            opacity: top * strength,
          ),
        ),
        // Bottom-right purple glow
        Positioned(
          bottom: -150,
          right: -110,
          child: _Glow(
            size: 340,
            color: AppColors.accentPurple,
            opacity: bottom * strength,
          ),
        ),
        // Center-left subtle cyan accent
        Positioned(
          top: 200,
          left: -60,
          child: _Glow(
            size: 200,
            color: AppColors.accentCyan,
            opacity: 0.04 * strength,
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
