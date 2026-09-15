import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Muestra una notificaci��n flotante, centrada y no invasiva (system toast).
///
/// Se pinta sobre el [Overlay] actual, no bloquea gestos (IgnorePointer) y se
/// auto-destruye tras [duration]. Dise��o para eventos en vivo de sala: cambios
/// de modo, moderaci��n de voz, inicio/fin de cine, etc.
void showSystemToast(
  BuildContext context, {
  required String message,
  String emoji = '',
  Color? accentColor,
  Duration duration = const Duration(milliseconds: 2400),
}) {
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _SystemToast(
      message: message,
      emoji: emoji,
      accentColor: accentColor,
      onDismissed: () {
        if (entry.mounted) entry.remove();
      },
    ),
  );
  overlay.insert(entry);
  Timer(duration, () {
    if (entry.mounted) entry.remove();
  });
}

class _SystemToast extends StatefulWidget {
  const _SystemToast({
    required this.message,
    required this.emoji,
    required this.onDismissed,
    this.accentColor,
  });

  final String message;
  final String emoji;
  final Color? accentColor;
  final VoidCallback onDismissed;

  @override
  State<_SystemToast> createState() => _SystemToastState();
}

class _SystemToastState extends State<_SystemToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  )..forward();
  late final Animation<double> _opacity =
      CurvedAnimation(parent: _controller, curve: Curves.easeOut);
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, -0.35),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: FadeTransition(
          opacity: _opacity,
          child: SlideTransition(
            position: _slide,
            child: Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 36),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xF01E1A2E),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color:
                        widget.accentColor ?? AppColors.accentCyan.withValues(alpha: 0.35),
                    width: 1,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 18,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.emoji.isNotEmpty) ...[
                      Text(widget.emoji, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 10),
                    ],
                    Flexible(
                      child: Text(
                        widget.message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}