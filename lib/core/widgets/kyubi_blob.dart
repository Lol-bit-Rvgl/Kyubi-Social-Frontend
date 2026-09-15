import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Blob orgánico con cola (lenguaje visual Kyubi).
///
/// Forma curva inspirada en una cola de zorro: elegante, discreta y
/// determinista (no genera aleatoriedad en cada frame). Se usa como
/// acento decorativo detrás de iconos, estados vacíos y banners.
class KyubiBlob extends StatelessWidget {
  const KyubiBlob({
    super.key,
    required this.size,
    required this.color,
    this.tail = false,
  });

  final double size;
  final Color color;
  final bool tail;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _KyubiBlobPainter(color: color, tail: tail),
      ),
    );
  }
}

class _KyubiBlobPainter extends CustomPainter {
  const _KyubiBlobPainter({required this.color, required this.tail});

  final Color color;
  final bool tail;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()..color = color;

    // Cuerpo del blob: círculo con ondulaciones suaves.
    final center = Offset(w * 0.45, h * 0.52);
    final radius = w * 0.40;
    const points = 8;
    final offsets = List<Offset>.generate(points, (i) {
      final angle = (i / points) * 2 * math.pi;
      final mod = 1 + 0.16 * math.sin(3 * angle + 0.7);
      return center +
          Offset(
            math.cos(angle) * radius * mod,
            math.sin(angle) * radius * mod,
          );
    });

    final path = Path()..moveTo(offsets[0].dx, offsets[0].dy);
    for (var i = 0; i < points; i++) {
      final current = offsets[i];
      final next = offsets[(i + 1) % points];
      final mid = Offset(
        (current.dx + next.dx) / 2,
        (current.dy + next.dy) / 2,
      );
      path.quadraticBezierTo(current.dx, current.dy, mid.dx, mid.dy);
    }
    path.close();
    canvas.drawPath(path, paint);

    if (tail) {
      final tailPath = Path()
        ..moveTo(w * 0.72, h * 0.58)
        ..cubicTo(w * 0.94, h * 0.50, w * 0.98, h * 0.66, w * 0.86, h * 0.82)
        ..cubicTo(w * 0.80, h * 0.70, w * 0.74, h * 0.64, w * 0.62, h * 0.70)
        ..close();
      canvas.drawPath(tailPath, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _KyubiBlobPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.tail != tail;
  }
}
