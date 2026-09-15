import 'package:flutter/material.dart';

import '../constants/app_assets.dart';
import '../theme/app_colors.dart';

/// Logotipo oficial de Kyubi (`assets/icons/kyubi_logo.jpg`).
///
/// El asset trae fondo negro, por lo que se presenta recortado en squircle
/// (`ClipRRect` con radio 20) y un resplandor sutil (`BoxShadow`) que se integra
/// de forma impecable en la estética Liquid Glass y modo oscuro de la aplicación.
class KyubiLogo extends StatelessWidget {
  const KyubiLogo({
    super.key,
    this.size = 90,
    this.withWordmark = false,
    this.wordmarkSize = 24,
    this.showGlow = true,
  });

  /// Lado del logotipo oficial.
  final double size;

  /// Si se acompaña del nombre "Kyubi" junto al logotipo.
  final bool withWordmark;

  final double wordmarkSize;

  /// Resplandor sutil bajo el logo (se atenúa o desactiva según el contexto).
  final bool showGlow;

  @override
  Widget build(BuildContext context) {
    final radius = (size * (20.0 / 90.0)).clamp(6.0, 24.0);
    final borderRadius = BorderRadius.circular(radius);

    final mark = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: showGlow
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  blurRadius: (size * 0.3).clamp(8.0, 28.0),
                  spreadRadius: 1,
                  offset: Offset(0, (size * 0.05).clamp(2.0, 6.0)),
                ),
                BoxShadow(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.18),
                  blurRadius: (size * 0.4).clamp(10.0, 36.0),
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Image.asset(
          AppAssets.logo,
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => Container(
            color: const Color(0xFF0F0E17),
            alignment: Alignment.center,
            child: Icon(
              Icons.shield_rounded,
              size: size * 0.5,
              color: AppColors.primary,
            ),
          ),
        ),
      ),
    );

    if (!withWordmark) return mark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        const SizedBox(width: 12),
        Text(
          'Kyubi',
          style: TextStyle(
            fontSize: wordmarkSize,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            letterSpacing: -0.5,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
