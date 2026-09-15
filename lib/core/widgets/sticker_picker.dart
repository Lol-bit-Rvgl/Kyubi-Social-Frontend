import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/animated_sticker.dart';
import '../../../core/widgets/sticker_catalog.dart';

/// Abre el selector de stickers animados y notifica el sticker elegido con
/// [onSelected]. Usa el tema oscuro consistente con el chat de salas.
Future<void> showStickerPicker(
  BuildContext context, {
  void Function(StickerItem sticker)? onSelected,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black54,
    builder: (ctx) => _PickerSheet(
      onSelected: (sticker) {
        Navigator.pop(ctx);
        onSelected?.call(sticker);
      },
    ),
  );
}

class _PickerSheet extends StatelessWidget {
  const _PickerSheet({required this.onSelected});

  final void Function(StickerItem sticker) onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.46,
      decoration: const BoxDecoration(
        color: Color(0xFF13101E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF3A3A4A),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 6, 16, 8),
            child: Row(
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 16,
                  color: AppColors.accentCyan,
                ),
                SizedBox(width: 6),
                Text(
                  'Stickers animados',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                Spacer(),
                Icon(
                  Icons.flash_on_rounded,
                  size: 14,
                  color: Color(0xFFFFD600),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFF221D32), height: 1, thickness: 0.8),
          Expanded(child: StickerGridView(onSelected: onSelected)),
        ],
      ),
    );
  }
}

/// Grilla de stickers con preview animado en vivo (Lottie).
class StickerGridView extends StatelessWidget {
  const StickerGridView({super.key, required this.onSelected});

  final void Function(StickerItem sticker) onSelected;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(14),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.0,
      ),
      itemCount: stickerCatalog.length,
      itemBuilder: (context, index) {
        final sticker = stickerCatalog[index];
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onSelected(sticker);
          },
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A1626),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF2C2544), width: 0.8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AnimatedSticker(
                assetPath: sticker.assetPath,
                emoji: sticker.emoji,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.contain,
              ),
            ),
          ),
        );
      },
    );
  }
}
