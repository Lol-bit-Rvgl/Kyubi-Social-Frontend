import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/animated_emoji_manager.dart';
import '../../../../models/reaction.dart';
import 'floating_reaction_menu.dart';

/// Píldora flotante animada con los 7 emojis populares para reaccionar a publicaciones.
class ReactionPickerPopup extends StatefulWidget {
  const ReactionPickerPopup({super.key, required this.onSelectReaction});

  final void Function(String emoji, String key) onSelectReaction;

  static const List<({String emoji, String key, String name})> reactions = [
    (emoji: '❤️', key: 'like', name: 'Amor'),
    (emoji: '🔥', key: 'fire', name: 'Fuego'),
    (emoji: '😂', key: 'laugh', name: 'Risa'),
    (emoji: '✨', key: 'sparkles', name: 'Brillo'),
    (emoji: '🥺', key: 'pleading', name: 'Ternura'),
    (emoji: '😮', key: 'wow', name: 'Sorpresa'),
    (emoji: '🎉', key: 'party', name: 'Fiesta'),
  ];

  static Future<void> show(
    BuildContext context, {
    required GlobalKey anchorKey,
    required void Function(String emoji, String key) onSelectReaction,
  }) async {
    final type = await FloatingReactionMenu.show(context, anchorKey: anchorKey);
    if (type != null) {
      onSelectReaction(type, type);
    }
  }

  @override
  State<ReactionPickerPopup> createState() => _ReactionPickerPopupState();
}

class _ReactionPickerPopupState extends State<ReactionPickerPopup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  int? _hoveredIndex;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    )..forward();
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF161424).withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: AppColors.accentCrimson.withValues(alpha: 0.4),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: AppColors.accentCrimson.withValues(alpha: 0.2),
                blurRadius: 16,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(ReactionPickerPopup.reactions.length, (
              index,
            ) {
              final r = ReactionPickerPopup.reactions[index];
              final isHovered = _hoveredIndex == index;

              return GestureDetector(
                onTapDown: (_) => setState(() => _hoveredIndex = index),
                onTapCancel: () => setState(() => _hoveredIndex = null),
                onTap: () {
                  HapticFeedback.selectionClick();
                  widget.onSelectReaction(r.emoji, r.key);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  curve: Curves.easeOut,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.all(6),
                  transform: isHovered
                      ? Matrix4.diagonal3Values(1.35, 1.35, 1.0)
                      : Matrix4.identity(),
                  transformAlignment: Alignment.center,
                  decoration: isHovered
                      ? BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        )
                      : null,
                  child: Text(
                    r.emoji,
                    style: const TextStyle(fontSize: 26, height: 1.1),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

/// Fila de chips de reacciones activas con conteo (ej. [ ❤️ 12 ] [ 🔥 5 ]).
class ReactionChipsRow extends StatelessWidget {
  const ReactionChipsRow({
    super.key,
    required this.activeList,
    required this.myReaction,
    required this.onTapReaction,
    required this.onSelectReaction,
  });

  final List<({String emoji, String key, int count})> activeList;
  final String? myReaction;
  final void Function(String key) onTapReaction;
  final void Function(String key) onSelectReaction;

  @override
  Widget build(BuildContext context) {
    if (activeList.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ...activeList.map((r) {
            // Normalizar myReaction para comparar con la key del chip.
            final normalizedMyReaction = myReaction != null
                ? emojiToKey(myReaction!)
                : null;
            final isMine = normalizedMyReaction == r.key;

            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onTapReaction(r.key);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: isMine
                      ? AppColors.accentCrimson.withValues(alpha: 0.18)
                      : const Color(0xFF161522),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isMine
                        ? AppColors.accentCrimson.withValues(alpha: 0.6)
                        : const Color(0xFF262436),
                    width: isMine ? 1.1 : 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildReactionEmoji(r.emoji),
                    const SizedBox(width: 4.5),
                    Text(
                      '${r.count}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: isMine ? FontWeight.w800 : FontWeight.w600,
                        color: isMine
                            ? AppColors.accentCrimson
                            : const Color(0xFF9E9EAF),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          _FloatingPickerButton(onSelectReaction: onSelectReaction),
        ],
      ),
    );
  }

  /// Renderiza un emoji: si es una ruta de asset WebP usa Image.asset,
  /// si es un emoji Unicode lo muestra como texto.
  static Widget _buildReactionEmoji(String emoji) {
    if (emoji.endsWith('.webp') || emoji.contains('/')) {
      return AnimatedEmojiManager.renderEmoji(emoji, size: 15);
    }
    return Text(emoji, style: const TextStyle(fontSize: 13, height: 1.1));
  }
}

/// Botón `+` que abre el [FloatingReactionMenu] anclado a él mismo.
///
/// Reemplaza al teclado de emojis general (`emoji_picker_flutter`) con el
/// selector flotante horizontal de 6 reacciones Nebulæ.
class _FloatingPickerButton extends StatefulWidget {
  const _FloatingPickerButton({required this.onSelectReaction});

  final void Function(String key) onSelectReaction;

  @override
  State<_FloatingPickerButton> createState() => _FloatingPickerButtonState();
}

class _FloatingPickerButtonState extends State<_FloatingPickerButton> {
  final GlobalKey _anchorKey = GlobalKey();

  void _openMenu() {
    FloatingReactionMenu.show(
      context,
      anchorKey: _anchorKey,
      onSelect: widget.onSelectReaction,
    );
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: _anchorKey,
      child: GestureDetector(
        onTap: _openMenu,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF141320),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF262436), width: 0.8),
          ),
          child: const Icon(
            Icons.add_rounded,
            size: 14,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
