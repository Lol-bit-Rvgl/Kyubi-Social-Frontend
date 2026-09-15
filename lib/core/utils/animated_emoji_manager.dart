import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Categorías de emojis animados WebP disponibles en `assets/Emojis/`.
enum EmojiCategory {
  smileys('Smileys and emotions', '😊'),
  people('People', '👋'),
  animals('Animals and nature', '🐾'),
  food('Food and drink', '🍔'),
  activities('Activities and events', '⚽'),
  objects('Objects', '💡'),
  travel('Travel and places', '✈️'),
  symbols('Symbols', '💡'),
  flags('Flags', '🏁');

  const EmojiCategory(this.folder, this.icon);
  final String folder;
  final String icon;
}

/// Información de un emoji individual.
class EmojiEntry {
  const EmojiEntry({
    required this.path,
    required this.category,
    required this.index,
  });

  final String path;
  final EmojiCategory category;
  final int index;
}

/// Servicio centralizado para gestionar los ~980 emojis animados WebP.
///
/// Carga las rutas de assets una sola vez usando [AssetManifest] y las
/// mantiene en caché para todo el ciclo de vida de la app.
class AnimatedEmojiManager {
  AnimatedEmojiManager._();

  static final AnimatedEmojiManager instance = AnimatedEmojiManager._();

  List<EmojiEntry>? _allEmojis;
  Map<EmojiCategory, List<EmojiEntry>>? _byCategory;
  List<EmojiEntry>? _frequent;

  /// Inicializa el catálogo leyendo el AssetManifest.
  Future<void> init() async {
    if (_allEmojis != null) return;

    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final allPaths = manifest.listAssets();

    final emojis = <EmojiEntry>[];
    for (final cat in EmojiCategory.values) {
      final prefix = 'assets/Emojis/${cat.folder}/';
      final catPaths =
          allPaths
              .where((p) => p.startsWith(prefix) && p.endsWith('.webp'))
              .toList()
            ..sort();

      for (var i = 0; i < catPaths.length; i++) {
        emojis.add(EmojiEntry(path: catPaths[i], category: cat, index: i));
      }
    }

    _allEmojis = emojis;

    _byCategory = {};
    for (final cat in EmojiCategory.values) {
      _byCategory![cat] = emojis.where((e) => e.category == cat).toList();
    }

    _frequent = _buildFrequentList();
  }

  /// Emojis frecuentes: primeros de cada categoría (hasta 24).
  List<EmojiEntry> _buildFrequentList() {
    final result = <EmojiEntry>[];
    for (final cat in EmojiCategory.values) {
      final catEmojis = _byCategory![cat] ?? [];
      result.addAll(catEmojis.take(3));
      if (result.length >= 24) break;
    }
    return result.take(24).toList();
  }

  /// Todos los emojis.
  List<EmojiEntry> get allEmojis => _allEmojis ?? [];

  /// Emojis agrupados por categoría.
  Map<EmojiCategory, List<EmojiEntry>> get byCategory => _byCategory ?? {};

  /// Lista rápida de emojis frecuentes.
  List<EmojiEntry> get frequent => _frequent ?? [];

  /// Emojis de una categoría específica.
  List<EmojiEntry> emojisFor(EmojiCategory cat) => _byCategory?[cat] ?? [];

  /// Renderiza un emoji WebP como widget [Image].
  static Widget renderEmoji(
    String assetPath, {
    double size = 24,
    BoxFit fit = BoxFit.contain,
  }) {
    return Image.asset(
      assetPath,
      width: size,
      height: size,
      fit: fit,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => Icon(
        Icons.emoji_emotions_outlined,
        size: size,
        color: const Color(0xFF6E6888),
      ),
    );
  }
}

/// Renderiza SOLO el primer frame de un emoji WebP animado (estático).
///
/// Las grillas de selección muestran cientos de emojis a la vez; animar todos
/// al mismo tiempo satura el renderer. Este widget decodifica únicamente el
/// primer frame y lo pinta con [CustomPaint], dejando el ciclo animado para
/// el emoji ya insertado en el chat ([AnimatedEmojiManager.renderEmoji]).
class StaticEmojiFrame extends StatefulWidget {
  const StaticEmojiFrame({super.key, required this.assetPath, this.size = 24});

  final String assetPath;
  final double size;

  @override
  State<StaticEmojiFrame> createState() => _StaticEmojiFrameState();
}

class _StaticEmojiFrameState extends State<StaticEmojiFrame> {
  ui.Image? _frame;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  @override
  void didUpdateWidget(covariant StaticEmojiFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetPath != widget.assetPath) {
      _frame?.dispose();
      _frame = null;
      _decode();
    }
  }

  @override
  void dispose() {
    _frame?.dispose();
    super.dispose();
  }

  Future<void> _decode() async {
    try {
      final data = await rootBundle.load(widget.assetPath);
      final target = (widget.size * 2).round().clamp(32, 96);
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
        targetWidth: target,
        targetHeight: target,
      );
      final frame = await codec.getNextFrame();
      codec.dispose();
      if (!mounted) return;
      setState(() => _frame = frame.image);
    } catch (_) {
      if (!mounted) return;
      setState(() => _frame = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final frame = _frame;
    final empty = SizedBox(
      width: widget.size,
      height: widget.size,
      child: const Icon(
        Icons.emoji_emotions_outlined,
        size: 16,
        color: Color(0xFF6E6888),
      ),
    );
    if (frame == null) return empty;
    return CustomPaint(
      size: Size.square(widget.size),
      painter: _EmojiFramePainter(frame),
    );
  }
}

class _EmojiFramePainter extends CustomPainter {
  _EmojiFramePainter(this.image);

  final ui.Image image;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Offset.zero & size,
      Paint(),
    );
  }

  @override
  bool shouldRepaint(covariant _EmojiFramePainter oldDelegate) {
    return oldDelegate.image != image;
  }
}
