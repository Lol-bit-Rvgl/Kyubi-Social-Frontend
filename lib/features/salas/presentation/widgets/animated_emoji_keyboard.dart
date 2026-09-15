import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/animated_emoji_manager.dart';

/// Teclado de emojis animados WebP para chats y salas de rol.
///
/// Se despliega como panel inferior con pestañas por categoría, grid optimizado
/// y barra de frecuentes. Diseñado para funcionar dentro de [ChatMessageInputBar]
/// y [RichTextRoleplayModal].
class AnimatedEmojiKeyboard extends StatefulWidget {
  const AnimatedEmojiKeyboard({
    super.key,
    required this.onEmojiSelected,
    this.height = 280,
  });

  final void Function(EmojiEntry emoji) onEmojiSelected;
  final double height;

  @override
  State<AnimatedEmojiKeyboard> createState() => _AnimatedEmojiKeyboardState();
}

class _AnimatedEmojiKeyboardState extends State<AnimatedEmojiKeyboard>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: EmojiCategory.values.length + 1,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final manager = AnimatedEmojiManager.instance;

    return Container(
      height: widget.height,
      decoration: const BoxDecoration(
        color: Color(0xFF100D1A),
        border: Border(top: BorderSide(color: Color(0xFF2E2744), width: 0.8)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
    );
  }

  Widget _buildTabBar() {
    return SizedBox(
      height: 38,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: AppColors.accentCyan,
        unselectedLabelColor: const Color(0xFF6E6888),
        indicatorColor: AppColors.accentCyan,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w500,
        ),
        tabs: [
          const Tab(text: '⭐'),
          for (final cat in EmojiCategory.values) Tab(text: cat.icon),
        ],
      ),
    );
  }

  Widget _buildEmojiGrid(List<EmojiEntry> emojis) {
    if (emojis.isEmpty) {
      return const Center(
        child: Text(
          'Vacío',
          style: TextStyle(color: Color(0xFF6E6888), fontSize: 12),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemCount: emojis.length,
      physics: const BouncingScrollPhysics(),
      itemBuilder: (context, index) {
        final emoji = emojis[index];
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            widget.onEmojiSelected(emoji);
          },
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A1628),
              borderRadius: BorderRadius.circular(6),
            ),
            padding: const EdgeInsets.all(3),
            child: StaticEmojiFrame(assetPath: emoji.path, size: 26),
          ),
        );
      },
    );
  }
}
