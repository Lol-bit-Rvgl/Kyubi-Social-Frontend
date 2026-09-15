import 'dart:io';
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Clipper que genera un polígono hexagonal perfecto con orientación vertical.
class HexagonClipper extends CustomClipper<Path> {
  const HexagonClipper();

  @override
  Path getClip(Size size) {
    final path = Path();
    final width = size.width;
    final height = size.height;
    final radius = math.min(width, height) / 2;
    final centerX = width / 2;
    final centerY = height / 2;

    for (int i = 0; i < 6; i++) {
      // 30 grados de offset para tener un vértice arriba y abajo
      final angle = (60 * i - 30) * math.pi / 180;
      final x = centerX + radius * math.cos(angle);
      final y = centerY + radius * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Painter para dibujar el borde continuo o punteado/discontinuo del hexágono.
class HexagonBorderPainter extends CustomPainter {
  const HexagonBorderPainter({
    required this.color,
    this.strokeWidth = 2.0,
    this.isDashed = false,
  });

  final Color color;
  final double strokeWidth;
  final bool isDashed;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final width = size.width;
    final height = size.height;
    final radius = (math.min(width, height) / 2) - (strokeWidth / 2);
    final centerX = width / 2;
    final centerY = height / 2;

    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (60 * i - 30) * math.pi / 180;
      final x = centerX + radius * math.cos(angle);
      final y = centerY + radius * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    if (!isDashed) {
      canvas.drawPath(path, paint);
      return;
    }

    // Dibujar trazo discontinuo/punteado
    final pathMetrics = path.computeMetrics();
    for (final metric in pathMetrics) {
      double distance = 0.0;
      const dashLength = 6.0;
      const spaceLength = 5.0;
      while (distance < metric.length) {
        final extractPath = metric.extractPath(
          distance,
          math.min(distance + dashLength, metric.length),
        );
        canvas.drawPath(extractPath, paint);
        distance += dashLength + spaceLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant HexagonBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.isDashed != isDashed;
  }
}

/// Avatar Hexagonal con borde personalizado para Roles y OCs de Kyubi.
class HexagonAvatar extends StatelessWidget {
  const HexagonAvatar({
    super.key,
    this.imageUrl,
    this.size = 54,
    this.borderColor = AppColors.accentCyan,
    this.borderWidth = 2.0,
    this.isDashed = false,
    this.hasActiveMic = false,
    this.badgeText,
    this.badgeColor,
    this.onTap,
    this.child,
  });

  final String? imageUrl;
  final double size;
  final Color borderColor;
  final double borderWidth;
  final bool isDashed;
  final bool hasActiveMic;
  final String? badgeText;
  final Color? badgeColor;
  final VoidCallback? onTap;
  final Widget? child;

  Widget _buildImage(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        errorWidget: (_, _, _) => _buildFallback(),
      );
    }
    try {
      final file = File(url);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _buildFallback(),
        );
      }
    } catch (_) {}
    return _buildFallback();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Contenido interior recortado en hexágono
            ClipPath(
              clipper: const HexagonClipper(),
              child: Container(
                width: size - (borderWidth * 2),
                height: size - (borderWidth * 2),
                color: const Color(0xFF14141B),
                child:
                    child ??
                    (imageUrl != null && imageUrl!.isNotEmpty
                        ? _buildImage(imageUrl!)
                        : _buildFallback()),
              ),
            ),

            // Borde hexagonal
            CustomPaint(
              size: Size(size, size),
              painter: HexagonBorderPainter(
                color: borderColor,
                strokeWidth: borderWidth,
                isDashed: isDashed,
              ),
            ),

            // Indicador de micrófono / mano levantada (Stage de rol)
            if (hasActiveMic)
              Positioned(
                top: -3,
                right: -3,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFD600),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.front_hand_rounded,
                    size: 11,
                    color: Colors.black,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2E1220), Color(0xFF121A2E)],
        ),
      ),
      child: const Center(
        child: Icon(Icons.person_rounded, color: Colors.white38, size: 24),
      ),
    );
  }
}
