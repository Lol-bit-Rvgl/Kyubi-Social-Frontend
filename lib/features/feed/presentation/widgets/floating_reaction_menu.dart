import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';

/// Menú flotante de reacciones rápidas con animación de escala.
///
/// Aparece anclado al widget del botón de like al mantenerlo presionado y
/// ofrece las 6 reacciones estándar: LIKE, LOVE, LAUGH, WOW, SAD y ANGRY.
/// Al seleccionar una reacción se dispara una micro-animación de escala
/// acompañada de una vibración háptica suave.
class FloatingReactionMenu {
  const FloatingReactionMenu._();

  /// Reacciones estándar del selector (key del backend → emoji → etiqueta).
  static const List<({String key, String emoji, String name})> reactions = [
    (key: 'like', emoji: '❤️', name: 'Like'),
    (key: 'love', emoji: '😍', name: 'Love'),
    (key: 'laugh', emoji: '😂', name: 'Jaja'),
    (key: 'wow', emoji: '😮', name: 'Wow'),
    (key: 'sad', emoji: '😢', name: 'Triste'),
    (key: 'angry', emoji: '😡', name: 'Bravo'),
  ];

  static const double _itemWidth = 52;
  static const double _menuHeight = 66;

  /// Muestra el menú flotante anclado al widget identificado por [anchorKey].
  ///
  /// Devuelve la key de la reacción seleccionada o `null` si se cierra sin
  /// seleccionar. Llama a [onSelect] cuando el usuario elige una reacción.
  static Future<String?> show(
    BuildContext context, {
    required GlobalKey anchorKey,
    void Function(String type)? onSelect,
  }) async {
    final overlay = Overlay.of(context);
    final ctx = anchorKey.currentContext;
    if (ctx == null) return null;
    final renderBox = ctx.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return null;

    final screenSize = MediaQuery.of(context).size;
    final menuWidth = reactions.length * _itemWidth + 20;

    // Posición horizontal centrada sobre el botón (con margen de seguridad).
    final rawLeft =
        renderBox.localToGlobal(Offset.zero).dx +
        (renderBox.size.width / 2) -
        (menuWidth / 2);
    final left = rawLeft.clamp(8.0, screenSize.width - menuWidth - 8.0);

    // Posición vertical: encima del botón; si no cabe, debajo.
    final anchorDy = renderBox.localToGlobal(Offset.zero).dy;
    final preferAbove = anchorDy - _menuHeight - 14;
    final top = preferAbove >= 8
        ? preferAbove
        : anchorDy + renderBox.size.height + 14;

    final completer = Completer<String?>();

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _ReactionMenuOverlay(
        left: left,
        top: top,
        onSelect: (type) {
          if (!completer.isCompleted) completer.complete(type);
        },
        onDismiss: () {
          if (entry.mounted) entry.remove();
          if (!completer.isCompleted) completer.complete(null);
        },
      ),
    );
    overlay.insert(entry);

    final type = await completer.future;
    if (type != null) onSelect?.call(type);
    return type;
  }
}

class _ReactionMenuOverlay extends StatefulWidget {
  const _ReactionMenuOverlay({
    required this.left,
    required this.top,
    required this.onSelect,
    required this.onDismiss,
  });

  final double left;
  final double top;
  final void Function(String type) onSelect;
  final VoidCallback onDismiss;

  @override
  State<_ReactionMenuOverlay> createState() => _ReactionMenuOverlayState();
}

class _ReactionMenuOverlayState extends State<_ReactionMenuOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  String? _selectedKey;
  String? _hoveredKey;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    )..forward();
    _scale = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSelect(String key) {
    if (_selectedKey != null) return;
    // Vibración háptica suave al seleccionar.
    HapticFeedback.lightImpact();
    setState(() => _selectedKey = key);
    // Micro-animación de escala antes de cerrar y notificar.
    Future<void>.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      widget.onSelect(key);
      widget.onDismiss();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Barrera transparente para cerrar al tocar fuera.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onDismiss,
            child: const ColoredBox(color: Colors.transparent),
          ),
        ),
        Positioned(
          left: widget.left,
          top: widget.top,
          child: ScaleTransition(
            scale: _scale,
            child: Material(
              color: Colors.transparent,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black54,
                      blurRadius: 20,
                      offset: Offset(0, 8),
                    ),
                    BoxShadow(
                      color: Color(0x33D100D1),
                      blurRadius: 16,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceCards.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: AppColors.borderNightGlass.withValues(
                            alpha: 0.7,
                          ),
                          width: 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final r in FloatingReactionMenu.reactions)
                              _buildItem(r),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildItem(({String key, String emoji, String name}) r) {
    final selected = _selectedKey == r.key;
    final hovered = _hoveredKey == r.key;
    return GestureDetector(
      onTapDown: (_) {
        HapticFeedback.selectionClick();
        setState(() => _hoveredKey = r.key);
      },
      onTapCancel: () => setState(() => _hoveredKey = null),
      onTap: () => _handleSelect(r.key),
      child: AnimatedScale(
        scale: selected ? 1.5 : (hovered ? 1.32 : 1.0),
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutBack,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          child: Text(r.emoji, style: TextStyle(fontSize: selected ? 30 : 27)),
        ),
      ),
    );
  }
}
