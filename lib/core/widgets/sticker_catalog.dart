/// Catálogo de stickers animados empaquetados como assets Lottie.
class StickerItem {
  const StickerItem({
    required this.id,
    required this.name,
    required this.emoji,
    required this.assetPath,
  });

  final String id;
  final String name;

  /// Emoji de reserva: también se previsualiza en el selector y se muestra
  /// como fallback si el asset Lottie no pudiera cargarse.
  final String emoji;
  final String assetPath;
}

/// Stickers disponibles en el chat de salas. Los assets viven en
/// `assets/stickers/*.json` y se entregan con un emoji de reserva.
const List<StickerItem> stickerCatalog = [
  StickerItem(
    id: 'sparkle',
    name: 'Destello',
    emoji: '✨',
    assetPath: 'assets/stickers/sparkle.json',
  ),
  StickerItem(
    id: 'heart',
    name: 'Corazón',
    emoji: '❤️',
    assetPath: 'assets/stickers/heart.json',
  ),
  StickerItem(
    id: 'confetti',
    name: 'Fiesta',
    emoji: '🎉',
    assetPath: 'assets/stickers/confetti.json',
  ),
  StickerItem(
    id: 'fire',
    name: 'Fuego',
    emoji: '🔥',
    assetPath: 'assets/stickers/fire.json',
  ),
  StickerItem(
    id: 'happy',
    name: 'Feliz',
    emoji: '😄',
    assetPath: 'assets/stickers/happy.json',
  ),
];

StickerItem? stickerById(String? id) {
  for (final s in stickerCatalog) {
    if (s.id == id) return s;
  }
  return null;
}
