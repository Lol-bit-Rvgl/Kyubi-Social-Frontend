import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Envoltorio de gesto para swipe-to-reply con umbral calibrado.
///
/// Sustituye al `Dismissible` que se activaba con micro-deslizamientos
/// horizontales e interfería con el scroll vertical del chat:
/// - Exige un desplazamiento horizontal neto ≥ [threshold] (~64px) para
///   activar la respuesta (al soltar el dedo).
/// - Cancela el gesto si la componente vertical domina el deslizamiento
///   (|dy| > |dx|): el scroll vertical queda totalmente intacto.
/// - Emite [onThresholdCrossed] una única vez por gesto (feedback háptico).
/// - Muestra una insignia de respuesta mientras se supera el umbral.
class SwipeToReply extends StatefulWidget {
  const SwipeToReply({
    super.key,
    required this.child,
    required this.onReply,
    this.threshold = 64.0,
    this.onThresholdCrossed,
  });

  final Widget child;
  final VoidCallback onReply;
  final double threshold;
  final VoidCallback? onThresholdCrossed;

  @override
  State<SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<SwipeToReply> {
  double _dx = 0;
  double _dy = 0;
  bool _crossed = false;

  void _reset({required bool fire}) {
    final dx = _dx;
    final dy = _dy;
    final horizontalDominant = dy.abs() <= dx.abs();
    _dx = 0;
    _dy = 0;
    _crossed = false;
    // Solo activa la respuesta si el gesto terminó siendo horizontal
    // dominante; si el usuario acabó haciendo scroll vertical, se cancela.
    if (fire && horizontalDominant && dx >= widget.threshold) {
      widget.onReply();
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // Si el gesto terminó siendo vertical, no se traslada la burbuja.
    final horizontal = _dy.abs() <= _dx.abs();
    final dx = horizontal ? _dx : 0.0;
    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        Positioned(
          left: 8,
          top: 0,
          bottom: 0,
          child: IgnorePointer(
            child: Opacity(
              opacity: (dx / widget.threshold).clamp(0.0, 1.0),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.accentCyan.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.reply_rounded,
                    color: AppColors.accentCyan,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
        ),
        Transform.translate(
          offset: Offset(dx * 0.35, 0),
          child: GestureDetector(
            behavior: HitTestBehavior.deferToChild,
            onHorizontalDragStart: (_) => _reset(fire: false),
            onHorizontalDragUpdate: (d) {
              setState(() {
                _dx = (_dx + d.delta.dx).clamp(0.0, widget.threshold * 2);
                _dy += d.delta.dy;
                if (!_crossed &&
                    _dx >= widget.threshold &&
                    _dy.abs() <= _dx.abs()) {
                  _crossed = true;
                  widget.onThresholdCrossed?.call();
                }
              });
            },
            onHorizontalDragEnd: (_) => _reset(fire: true),
            onHorizontalDragCancel: () => _reset(fire: false),
            child: widget.child,
          ),
        ),
      ],
    );
  }
}
