import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/story.dart';
import 'story_controller.dart';

/// Duración por defecto de una historia de imagen.
const Duration _kImageStoryDuration = Duration(seconds: 5);

/// Visor de historias a pantalla completa estilo Instagram/WhatsApp.
///
/// Controles:
/// - Tap en el tercio izquierdo: historia anterior.
/// - Tap en el tercio derecho: siguiente historia.
/// - Mantener pulsado: pausa el progreso.
/// - Swipe hacia abajo: cierra el visor.
class StoryViewerScreen extends ConsumerStatefulWidget {
  const StoryViewerScreen({super.key, required this.group});

  final StoryGroup group;

  @override
  ConsumerState<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends ConsumerState<StoryViewerScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progressController;
  VideoPlayerController? _videoController;

  int _currentIndex = 0;
  bool _paused = false;
  double _dragOffset = 0;

  List<Story> get _stories => widget.group.stories;
  Story get _currentStory => _stories[_currentIndex];

  @override
  void initState() {
    super.initState();
    _progressController =
        AnimationController(vsync: this, duration: _kImageStoryDuration)
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) _next();
          });
    _startCurrentStory();
  }

  @override
  void dispose() {
    _progressController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  // ── Ciclo de vida de la historia actual ────────────────────────────────────

  void _startCurrentStory() {
    _progressController.stop();
    final story = _currentStory;
    ref.read(storyControllerProvider.notifier).markStoryViewed(story.id);

    if (story.isVideo) {
      _playVideo(story.mediaUrl);
    } else {
      _videoController?.dispose();
      _videoController = null;
      _progressController
        ..value = 0
        ..duration = _kImageStoryDuration
        ..forward();
    }
    if (mounted) setState(() {});
  }

  Future<void> _playVideo(String url) async {
    await _videoController?.dispose();
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _videoController = controller;
    try {
      await controller.initialize();
    } catch (_) {
      // Si el video falla al cargar, saltamos a la siguiente historia.
      if (mounted) _next();
      return;
    }
    if (!mounted) return;
    _progressController
      ..value = 0
      ..duration = controller.value.duration;
    await controller.play();
    _progressController.forward();
    setState(() {});
  }

  // ── Navegación entre historias ─────────────────────────────────────────────

  void _next() {
    if (_currentIndex < _stories.length - 1) {
      _currentIndex++;
      _startCurrentStory();
    } else {
      context.pop();
    }
  }

  void _previous() {
    if (_currentIndex > 0) {
      _currentIndex--;
      _startCurrentStory();
    } else {
      _progressController
        ..value = 0
        ..forward();
    }
  }

  // ── Pausa / reanudar ───────────────────────────────────────────────────────

  void _pauseStory() {
    _paused = true;
    _progressController.stop();
    _videoController?.pause();
  }

  void _resumeStory() {
    _paused = false;
    _progressController.forward();
    _videoController?.play();
  }

  // ── Gestos ─────────────────────────────────────────────────────────────────

  void _onTapUp(TapUpDetails details, Size size) {
    final x = details.localPosition.dx;
    if (x < size.width / 3) {
      _previous();
    } else {
      _next();
    }
  }

  void _onSwipeDown(DragUpdateDetails details) {
    setState(() => _dragOffset += details.delta.dy);
    if (_dragOffset < 0) _dragOffset = 0;
  }

  void _onSwipeDownEnd(DragEndDetails details) {
    if (_dragOffset > 120 || (details.primaryVelocity ?? 0) > 700) {
      context.pop();
      return;
    }
    setState(() => _dragOffset = 0);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundBase,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          return GestureDetector(
            onTapUp: (details) => _onTapUp(details, size),
            onLongPressStart: (_) => _pauseStory(),
            onLongPressEnd: (_) => _resumeStory(),
            onVerticalDragUpdate: _onSwipeDown,
            onVerticalDragEnd: _onSwipeDownEnd,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              transform: Matrix4.translationValues(0, _dragOffset, 0),
              child: Stack(
                fit: StackFit.expand,
                children: [_buildMedia(), _buildTopOverlay()],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMedia() {
    final story = _currentStory;
    if (story.isVideo) {
      final controller = _videoController;
      if (controller != null && controller.value.isInitialized) {
        return Center(
          child: AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: VideoPlayer(controller),
          ),
        );
      }
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    return CachedNetworkImage(
      imageUrl: story.mediaUrl,
      fit: BoxFit.contain,
      progressIndicatorBuilder: (context, url, progress) => Center(
        child: CircularProgressIndicator(
          value: progress.progress,
          color: AppColors.primary,
        ),
      ),
      errorWidget: (context, url, error) => const Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: Color(0xFF6E6E78),
          size: 48,
        ),
      ),
    );
  }

  Widget _buildTopOverlay() {
    final author = widget.group.author;
    final displayName = author.displayName.isNotEmpty
        ? author.displayName
        : author.username;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Row(
              children: [
                for (var i = 0; i < _stories.length; i++)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: i < _stories.length - 1 ? 4 : 0,
                      ),
                      child: _ProgressSegment(
                        index: i,
                        currentIndex: _currentIndex,
                        progress: _progressController,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: AppColors.surfaceAlt,
                  backgroundImage:
                      author.avatarUrl != null && author.avatarUrl!.isNotEmpty
                      ? CachedNetworkImageProvider(author.avatarUrl!)
                      : null,
                  child: author.avatarUrl == null || author.avatarUrl!.isEmpty
                      ? Text(
                          displayName.isNotEmpty
                              ? displayName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
                    ),
                  ),
                ),
                if (_currentStory.caption != null &&
                    _currentStory.caption!.isNotEmpty)
                  const Icon(
                    Icons.text_fields_rounded,
                    size: 18,
                    color: Colors.white70,
                  ),
                IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 24,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          if (!_paused &&
              _currentStory.caption != null &&
              _currentStory.caption!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Text(
                      _currentStory.caption!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white,
                        height: 1.3,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Segmento individual de la barra de progreso superior.
class _ProgressSegment extends StatelessWidget {
  const _ProgressSegment({
    required this.index,
    required this.currentIndex,
    required this.progress,
  });

  final int index;
  final int currentIndex;
  final AnimationController progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 3,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(2),
      ),
      child: AnimatedBuilder(
        animation: progress,
        builder: (context, child) {
          final double value;
          if (index < currentIndex) {
            value = 1;
          } else if (index == currentIndex) {
            value = progress.value;
          } else {
            value = 0;
          }
          return FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: value.clamp(0.0, 1.0),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        },
      ),
    );
  }
}
