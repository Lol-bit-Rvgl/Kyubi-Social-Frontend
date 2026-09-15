import 'package:flutter/material.dart';

/// Botón de vidrio líquido (Liquid Glass).
///
/// Sustituye los botones fucsia/neón chillones por un acabado sobrio y
/// traslúcido: gradiente azul/morado noche, borde superior con resplandor
/// lavanda suave y texto/icono en blanco/lavanda.
class LiquidGlassButton extends StatelessWidget {
  const LiquidGlassButton({
    super.key,
    required this.label,
    this.icon,
    required this.onTap,
    this.enabled = true,
    this.height = 46,
    this.borderRadius = 16.0,
    this.borderColor,
    this.customGradient,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool enabled;
  final double height;
  final double borderRadius;
  final Color? borderColor;
  final LinearGradient? customGradient;

  /// Gradiente traslúcido azul/morado noche sobrio.
  static const LinearGradient nightGradient = LinearGradient(
    colors: [Color(0xFF382C5E), Color(0xFF1F2D48)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  Widget build(BuildContext context) {
    final effectiveBorderColor =
        borderColor?.withValues(alpha: 0.5) ??
        const Color(0xFF9E8CD9).withValues(alpha: 0.35);

    final button = Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: customGradient ?? nightGradient,
        border: Border(
          top: BorderSide(
            // Borde superior con resplandor suave según tema
            color: effectiveBorderColor,
            width: 1.2,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: effectiveBorderColor.withValues(alpha: 0.12),
            blurRadius: 16,
            spreadRadius: -4,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: const Color(0xFFC9B8FF)),
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
    );

    final content = Opacity(opacity: enabled ? 1.0 : 0.5, child: button);

    return GestureDetector(
      onTap: enabled ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: content,
    );
  }
}
