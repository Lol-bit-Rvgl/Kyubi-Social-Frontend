import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Un sticker animado individual. Renderiza un archivo Lottie empaquetado y,
/// si este no puede cargarse (asset ausente / forma inválida), cae a un emoji
/// estático con un halo suave para no romper el chat.
class AnimatedSticker extends StatelessWidget {
  const AnimatedSticker({
    super.key,
    required this.assetPath,
    this.emoji,
    this.width = 96,
    this.height = 96,
    this.fit = BoxFit.contain,
    this.repeat = true,
    this.reverse = false,
  });

  final String assetPath;
  final String? emoji;
  final double width;
  final double height;
  final BoxFit fit;
  final bool repeat;
  final bool reverse;

  @override
  Widget build(BuildContext context) {
    final path = assetPath.toLowerCase();
    if (path.endsWith('.webp') ||
        path.endsWith('.png') ||
        path.endsWith('.gif')) {
      return Image.asset(
        assetPath,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => _buildFallback(),
      );
    }

    return Lottie.asset(
      assetPath,
      width: width,
      height: height,
      fit: fit,
      repeat: repeat,
      reverse: reverse,
      animate: true,
      errorBuilder: (context, error, stackTrace) => _buildFallback(),
    );
  }

  Widget _buildFallback() {
    final emoji = this.emoji;
    if (emoji == null) return const SizedBox.shrink();
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      child: Text(emoji, style: TextStyle(fontSize: width * 0.55)),
    );
  }
}
