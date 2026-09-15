import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';

/// Variantes de botón de acción Nebulæ.
enum NebulaeActionVariant {
  /// Botón primario relleno con gradiente de marca e intensidad neón.
  primary,

  /// Botón secundario con glassmorphism translúcido y borde teal.
  glass,
}

/// Envoltura con microinteracción táctil: escala sutil (0.97) al presionar y
/// `HapticFeedback.lightImpact` en cada pulso.
class NebulaePressable extends StatefulWidget {
  const NebulaePressable({
    super.key,
    required this.child,
    this.onTap,
    this.disabled = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool disabled;

  @override
  State<NebulaePressable> createState() => _NebulaePressableState();
}

class _NebulaePressableState extends State<NebulaePressable> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.disabled
          ? null
          : (_) => setState(() => _pressed = true),
      onTapUp: widget.disabled ? null : (_) => setState(() => _pressed = false),
      onTapCancel: widget.disabled
          ? null
          : () => setState(() => _pressed = false),
      onTap: widget.disabled
          ? null
          : () {
              HapticFeedback.lightImpact();
              widget.onTap?.call();
            },
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: AppDimens.motionFast,
        curve: AppDimens.curveStandard,
        child: widget.child,
      ),
    );
  }
}

/// Botón de acción primario o secundario («Editar perfil», «Seguir»,
/// «Mensaje directo»). Se usa dentro de un `Row`/`Expanded` para ancho fluido.
class NebulaeActionButton extends StatelessWidget {
  const NebulaeActionButton({
    super.key,
    required this.label,
    this.icon,
    required this.onTap,
    this.enabled = true,
    this.variant = NebulaeActionVariant.primary,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool enabled;
  final NebulaeActionVariant variant;

  static final LinearGradient calmGradient = LinearGradient(
    colors: [
      const Color(0xFF3B2D60).withValues(alpha: 0.85), // morado noche sutil
      const Color(0xFF233554).withValues(alpha: 0.85), // azul pizarra
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  Widget build(BuildContext context) {
    final isPrimary = variant == NebulaeActionVariant.primary;
    return NebulaePressable(
      onTap: onTap,
      disabled: !enabled,
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.md),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
          gradient: isPrimary ? calmGradient : null,
          color: isPrimary ? null : AppColors.surfaceGlass,
          border: isPrimary
              ? null
              : Border.all(
                  color: AppColors.accentTeal.withValues(alpha: 0.45),
                  width: 1,
                ),
          boxShadow: isPrimary
              ? [
                  BoxShadow(
                    color: const Color(0xFF2A2450).withValues(alpha: 0.45),
                    blurRadius: 14,
                    spreadRadius: -2,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: isPrimary ? Colors.white : AppColors.accentTeal,
              ),
              const SizedBox(width: 7),
            ],
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13.5,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Botón secundario/terciario de icono (tipo compañero flotante): contenedor
/// translúcido `surfaceCards` con borde sutil. Usado para «Compartir»,
/// «Configuración» y acciones de icono.
class NebulaeToolIconButton extends StatelessWidget {
  const NebulaeToolIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.enabled = true,
    this.size = 46,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final bool enabled;
  final double size;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return NebulaePressable(
      onTap: onTap,
      disabled: !enabled,
      child: Tooltip(
        message: tooltip ?? '',
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: const Color(0xFF1E1B2E).withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(AppDimens.radiusCard),
            border: Border.all(
              color: const Color(0xFF8A7EB8).withValues(alpha: 0.20),
              width: 1,
            ),
          ),
          child: Icon(icon, size: size * 0.43, color: Colors.white),
        ),
      ),
    );
  }
}
