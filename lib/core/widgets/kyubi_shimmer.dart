import 'package:flutter/material.dart';

/// Widget de carga tipo shimmer/esqueleto sutil con pulso oscuro.
class KyubiShimmer extends StatefulWidget {
  const KyubiShimmer({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.color,
  });

  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Color? color;

  @override
  State<KyubiShimmer> createState() => _KyubiShimmerState();
}

class _KyubiShimmerState extends State<KyubiShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _animation = Tween<double>(
      begin: 0.3,
      end: 0.8,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.color ?? const Color(0xFF1A1A26);
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: base.withValues(alpha: _animation.value),
            borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
            border: Border.all(
              color: const Color(0xFF22222E).withValues(alpha: 0.5),
              width: 0.8,
            ),
          ),
        );
      },
    );
  }
}
