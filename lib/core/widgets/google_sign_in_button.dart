import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';

/// Painter vectorial para el logotipo multicolor oficial de Google ("G").
class GoogleLogoPainter extends CustomPainter {
  const GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double cx = w / 2;
    final double cy = h / 2;
    final double r = w / 2;

    // Colores oficiales de la marca Google
    const Color blue = Color(0xFF4285F4);
    const Color green = Color(0xFF34A853);
    const Color yellow = Color(0xFFFBBC05);
    const Color red = Color(0xFFEA4335);

    final Paint paint = Paint()..style = PaintingStyle.fill;

    // Segmento Azul (barra horizontal y cuadrante derecho)
    paint.color = blue;
    final Path bluePath = Path()
      ..moveTo(cx, cy)
      ..lineTo(w, cy)
      ..arcTo(Rect.fromCircle(center: Offset(cx, cy), radius: r), 0, 0.785, false)
      ..lineTo(cx + r * 0.58, cy + r * 0.28)
      ..arcTo(Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.58), 0.5, -0.5, false)
      ..lineTo(cx, cy)
      ..close();
    canvas.drawPath(bluePath, paint);

    // Segmento Verde (cuadrante inferior)
    paint.color = green;
    final Path greenPath = Path()
      ..moveTo(cx, cy)
      ..arcTo(Rect.fromCircle(center: Offset(cx, cy), radius: r), 0.785, 1.57, false)
      ..lineTo(cx, cy)
      ..close();
    canvas.drawPath(greenPath, paint);

    // Segmento Amarillo (cuadrante inferior-izquierdo)
    paint.color = yellow;
    final Path yellowPath = Path()
      ..moveTo(cx, cy)
      ..arcTo(Rect.fromCircle(center: Offset(cx, cy), radius: r), 2.355, 1.18, false)
      ..lineTo(cx, cy)
      ..close();
    canvas.drawPath(yellowPath, paint);

    // Segmento Rojo (cuadrante superior)
    paint.color = red;
    final Path redPath = Path()
      ..moveTo(cx, cy)
      ..arcTo(Rect.fromCircle(center: Offset(cx, cy), radius: r), 3.535, 1.96, false)
      ..lineTo(cx, cy)
      ..close();
    canvas.drawPath(redPath, paint);

    // Vaciado central blanco/recorte para crear el efecto donut de la "G"
    final Paint holePaint = Paint()..style = PaintingStyle.fill;
    holePaint.color = AppColors.ink800; // Mismo color de fondo del botón
    canvas.drawCircle(Offset(cx, cy), r * 0.58, holePaint);

    // Brazo central de la "G"
    paint.color = blue;
    final Rect armRect = Rect.fromLTRB(cx, cy - r * 0.22, w - 1, cy + r * 0.22);
    canvas.drawRRect(RRect.fromRectAndRadius(armRect, const Radius.circular(2)), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Icono oficial de Google nítido y auto-contenido.
class GoogleLogoWidget extends StatelessWidget {
  const GoogleLogoWidget({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: const GoogleLogoPainter(),
        size: Size(size, size),
      ),
    );
  }
}

/// Botón estilizado para el inicio de sesión y registro con Google.
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    this.loading = false,
    this.label = 'Continuar con Google',
  });

  final VoidCallback? onPressed;
  final bool loading;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: loading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.ink800,
          side: const BorderSide(color: AppColors.ink600, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const GoogleLogoWidget(size: 20),
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
