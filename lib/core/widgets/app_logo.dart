import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Logotipo de Kyubi generado por código (no requiere asset externo).
///
/// **Legado:** usa [KyubiLogo] (asset oficial) para la marca. Este componente
/// queda solo como referencia del lenguaje visual: rombo redondeado con
/// gradiente de marca, acento diagonal (corte de identidad) y cola curva
/// inspirada en el concepto "kyubi" (cola de zorro).
@Deprecated('Usa KyubiLogo (asset oficial) en lugar de AppLogo')
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.size = 48,
    this.withWordmark = false,
    this.wordmarkSize = 28,
  });

  final double size;
  final bool withWordmark;
  final double wordmarkSize;

  @override
  Widget build(BuildContext context) {
    final mark = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: size * 0.4,
            offset: Offset(0, size * 0.12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: CustomPaint(
        painter: const _KyubiMarkPainter(),
        child: Center(
          child: Text(
            'K',
            style: TextStyle(
              fontSize: size * 0.58,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              fontStyle: FontStyle.italic,
              height: 1,
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
        const SizedBox(width: 10),
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

/// Pinta el acento diagonal (corte superior derecho) y la cola curva.
class _KyubiMarkPainter extends CustomPainter {
  const _KyubiMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Acento diagonal en la esquina superior derecha.
    final diagonal = Path()
      ..moveTo(w, 0)
      ..lineTo(w, h * 0.20)
      ..lineTo(w - h * 0.20, 0)
      ..close();
    canvas.drawPath(
      diagonal,
      Paint()..color = Colors.white.withValues(alpha: 0.28),
    );

    // Cola: trazos curvos que nacen bajo la letra y se abren hacia la
    // esquina inferior derecha (sutil, sin convertirla en temática anime).
    final baseX = w * 0.62;
    final baseY = h * 0.60;

    void stroke(Path path, double alpha) {
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white.withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = w * 0.05,
      );
    }

    stroke(
      Path()
        ..moveTo(baseX, baseY)
        ..cubicTo(
          baseX + w * 0.12,
          baseY + h * 0.02,
          baseX + w * 0.20,
          baseY + h * 0.08,
          baseX + w * 0.28,
          baseY + h * 0.20,
        ),
      0.45,
    );
    stroke(
      Path()
        ..moveTo(baseX + w * 0.07, baseY + h * 0.09)
        ..cubicTo(
          baseX + w * 0.17,
          baseY + h * 0.10,
          baseX + w * 0.24,
          baseY + h * 0.14,
          baseX + w * 0.31,
          baseY + h * 0.23,
        ),
      0.30,
    );
    stroke(
      Path()
        ..moveTo(baseX + w * 0.14, baseY + h * 0.16)
        ..cubicTo(
          baseX + w * 0.22,
          baseY + h * 0.17,
          baseX + w * 0.28,
          baseY + h * 0.20,
          baseX + w * 0.34,
          baseY + h * 0.26,
        ),
      0.20,
    );
  }

  @override
  bool shouldRepaint(covariant _KyubiMarkPainter oldDelegate) => false;
}
