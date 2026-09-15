import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/animated_emoji_manager.dart';

/// Selector de reacciones animadas WebP con pestañas por categoría.
///
/// Se abre como modal bottom sheet y permite al usuario seleccionar un emoji
/// animado para reaccionar a un post, comentario o entrada de muro.
class AnimatedReactionPickerModal extends StatefulWidget {
  const AnimatedReactionPickerModal({super.key, required this.onSelect});

  final void Function(EmojiEntry emoji) onSelect;

  static Future<void> show(
    BuildContext context, {
    required void Function(EmojiEntry emoji) onSelect,
  }) async {
    HapticFeedback.selectionClick();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: AnimatedReactionPickerModal(
          onSelect: (emoji) {
            Navigator.of(ctx).pop();
            onSelect(emoji);
          },
        ),
      ),
    );
  }

  @override
  State<AnimatedReactionPickerModal> createState() =>
      _AnimatedReactionPickerModalState();
}

class _AnimatedReactionPickerModalState
    extends State<AnimatedReactionPickerModal>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final AnimationController _animController;
  late final Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: EmojiCategory.values.length + 1, // +1 for "Frecuentes"
      vsync: this,
    );
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    )..forward();
    _slideAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final manager = AnimatedEmojiManager.instance;

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(_slideAnimation),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.45,
        decoration: const BoxDecoration(
          color: Color(0xFF100D1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(top: BorderSide(color: Color(0xFF2E2744), width: 1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHandle(),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildEmojiGrid(manager.frequent),
                  for (final cat in EmojiCategory.values)
                    _buildEmojiGrid(manager.emojisFor(cat)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHandle() {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: const Color(0xFF3A3550),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: AppColors.accentCyan,
        unselectedLabelColor: const Color(0xFF6E6888),
        indicatorColor: AppColors.accentCyan,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
        tabs: [
          const Tab(text: '⭐ Frecuentes'),
          for (final cat in EmojiCategory.values)
            Tab(text: '${cat.icon} ${_catLabel(cat)}'),
        ],
      ),
    );
  }

  String _catLabel(EmojiCategory cat) {
    switch (cat) {
      case EmojiCategory.smileys:
        return 'Smileys';
      case EmojiCategory.people:
        return 'People';
      case EmojiCategory.animals:
        return 'Animals';
      case EmojiCategory.food:
        return 'Food';
      case EmojiCategory.activities:
        return 'Events';
      case EmojiCategory.objects:
        return 'Objects';
      case EmojiCategory.travel:
        return 'Travel';
      case EmojiCategory.symbols:
        return 'Symbols';
      case EmojiCategory.flags:
        return 'Flags';
    }
  }

  Widget _buildEmojiGrid(List<EmojiEntry> emojis) {
    if (emojis.isEmpty) {
      return const Center(
        child: Text(
          'No hay emojis disponibles',
          style: TextStyle(color: Color(0xFF6E6888), fontSize: 13),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: emojis.length,
      itemBuilder: (context, index) {
        final emoji = emojis[index];
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            widget.onSelect(emoji);
          },
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A1628),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(4),
            child: AnimatedEmojiManager.renderEmoji(emoji.path, size: 28),
          ),
        );
      },
    );
  }
}
