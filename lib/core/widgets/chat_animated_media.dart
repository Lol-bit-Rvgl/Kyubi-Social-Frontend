import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../utils/animated_emoji_manager.dart';

/// Ámbito que pausa las animaciones del chat cuando el usuario está
/// escribiendo (campo de texto con foco) o cuando el chat pierde el foco.
///
/// Los emojis animados (WebP) y stickers (Lottie) dentro de este ámbito solo
/// corren sus bucles si el notifier está activo y además el widget sigue
/// visible en el viewport ([ChatBubbleAnimatedMedia]).
class ChatAnimationScope extends InheritedNotifier<ValueNotifier<bool>> {
  const ChatAnimationScope({
    super.key,
    required ValueNotifier<bool> animationsEnabled,
    required super.child,
  }) : super(notifier: animationsEnabled);

  /// True si el ámbito no existe (comportamiento heredado: siempre animado)
  /// o si el notifier está activo.
  static bool enabledOf(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<ChatAnimationScope>();
    if (scope == null) return true;
    return (scope.notifier?.value ?? true);
  }
}

/// Media animada de chat (emoji WebP, PNG/GIF o sticker Lottie) con pausa
/// inteligente:
/// - Los bucles activos solo corren mientras el widget es visible en el
///   viewport (se detecta la posición respecto al Scrollable más cercano).
/// - Se pausan cuando el chat no tiene el foco o el usuario está escribiendo
///   ([ChatAnimationScope]).
///
/// Cuando está pausado, los WebP/GIF se renderizan con su primer frame estático
/// ([StaticEmojiFrame]) y los Lottie con `animate: false`, evitando que sigan
/// consumiendo ciclos de decodificación/render fuera de pantalla.
class ChatBubbleAnimatedMedia extends StatefulWidget {
  const ChatBubbleAnimatedMedia({
    super.key,
    required this.assetPath,
    this.emoji,
    this.width = 140,
    this.height = 140,
    this.fit = BoxFit.contain,
  });

  final String assetPath;
  final String? emoji;
  final double width;
  final double height;
  final BoxFit fit;

  @override
  State<ChatBubbleAnimatedMedia> createState() => _ChatBubbleAnimatedMediaState();
}

class _ChatBubbleAnimatedMediaState extends State<ChatBubbleAnimatedMedia> {
  ScrollPosition? _position;
  bool _visible = true;
  bool _pendingEvaluate = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final pos = Scrollable.maybeOf(context)?.position;
    if (pos != _position) {
      _position?.removeListener(_onScroll);
      _position = pos;
      pos?.addListener(_onScroll);
    }
    _scheduleEvaluate();
  }

  @override
  void dispose() {
    _position?.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() => _scheduleEvaluate();

  void _scheduleEvaluate() {
    if (_pendingEvaluate) return;
    _pendingEvaluate = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pendingEvaluate = false;
      _evaluate();
    });
  }

  /// Recalcula si este widget sigue intersectando el viewport del Scrollable.
  void _evaluate() {
    if (!mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    final viewportContext =
        _position?.context.notificationContext?.findRenderObject();
    if (box == null || viewportContext is! RenderBox) return;

    final top = box.localToGlobal(Offset.zero).dy;
    final bottom = top + box.size.height;
    final viewTop = viewportContext.localToGlobal(Offset.zero).dy;
    final viewBottom = viewTop + viewportContext.size.height;
    final visible = bottom > viewTop && top < viewBottom;

    if (visible != _visible) {
      setState(() => _visible = visible);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scopeEnabled = ChatAnimationScope.enabledOf(context);
    final animate = scopeEnabled && _visible;
    final path = widget.assetPath.toLowerCase();

    if (path.endsWith('.webp') ||
        path.endsWith('.png') ||
        path.endsWith('.gif')) {
      if (animate) {
        return Image.asset(
          widget.assetPath,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => _buildFallback(),
        );
      }
      // Primer frame estático del WebP/GIF: sin bucle activo.
      return StaticEmojiFrame(
        assetPath: widget.assetPath,
        size: widget.width,
      );
    }

    return Lottie.asset(
      widget.assetPath,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      repeat: true,
      reverse: false,
      animate: animate,
      errorBuilder: (_, _, _) => _buildFallback(),
    );
  }

  Widget _buildFallback() {
    final emoji = widget.emoji;
    if (emoji == null) return const SizedBox.shrink();
    return Container(
      width: widget.width,
      height: widget.height,
      alignment: Alignment.center,
      child: Text(emoji, style: TextStyle(fontSize: widget.width * 0.55)),
    );
  }
}

/// Utilidad para pausar globalmente las animaciones de una pantalla mientras
/// una condición se cumple (jerarquía de ámbitos anidados).
class ChatAnimationsPauseController extends ChangeNotifier {
  ChatAnimationsPauseController({this.paused = false});

  bool paused;
  ValueNotifier<bool> get notifier => _notifier;

  final ValueNotifier<bool> _notifier = ValueNotifier<bool>(false);
  int _tokens = 0;
  bool _disposed = false;

  void acquire() {
    _tokens++;
    _apply(_tokens > 0);
  }

  void release() {
    if (_tokens > 0) _tokens--;
    _apply(_tokens > 0);
  }

  void setPaused(bool value) {
    paused = value;
    _apply(paused);
  }

  void _apply(bool value) {
    if (_disposed) return;
    if (_notifier.value != value) _notifier.value = value;
  }

  @override
  void dispose() {
    _disposed = true;
    _notifier.dispose();
    super.dispose();
  }
}