import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../../../core/theme/app_colors.dart';
import '../../../services/providers.dart';
import 'story_controller.dart';

/// Pantalla de creación de historia efímera (24h).
///
/// Permite elegir una imagen o video corto de la galería, añadir un texto
/// opcional (caption) y publicar. La subida usa `UploadRepository` y la
/// creación `POST /stories` del backend.
class CreateStoryScreen extends ConsumerStatefulWidget {
  const CreateStoryScreen({super.key});

  @override
  ConsumerState<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends ConsumerState<CreateStoryScreen> {
  final _captionController = TextEditingController();

  Uint8List? _bytes;
  String? _filename;
  String _mediaType = 'IMAGE';
  bool _publishing = false;

  VideoPlayerController? _videoPreview;

  @override
  void dispose() {
    _captionController.dispose();
    _videoPreview?.dispose();
    super.dispose();
  }

  Future<void> _pickMedia(ImageSource source, {required bool video}) async {
    try {
      final picker = ImagePicker();
      final picked = video
          ? await picker.pickVideo(source: source)
          : await picker.pickImage(
              source: source,
              maxWidth: 1080,
              maxHeight: 1920,
              imageQuality: 85,
            );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      await _videoPreview?.dispose();
      _videoPreview = null;
      setState(() {
        _bytes = bytes;
        _filename = picked.name;
        _mediaType = video ? 'VIDEO' : 'IMAGE';
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo cargar el archivo')),
      );
    }
  }

  Future<void> _publish() async {
    final bytes = _bytes;
    if (bytes == null || _publishing) return;

    setState(() => _publishing = true);
    try {
      final uploads = ref.read(uploadRepositoryProvider);
      final url = await uploads.uploadFile(
        'story',
        bytes: bytes,
        filename:
            _filename ?? (_mediaType == 'VIDEO' ? 'story.mp4' : 'story.jpg'),
      );

      final story = await ref
          .read(storyRepositoryProvider)
          .createStory(
            mediaUrl: url,
            mediaType: _mediaType,
            caption: _captionController.text.trim(),
          );

      if (!mounted) return;
      ref.read(storyControllerProvider.notifier).prependStory(story);
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _publishing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo publicar la historia: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundBase,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundBase,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Nueva historia',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: _bytes == null || _publishing ? null : _publish,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: AppColors.primary.withValues(
                  alpha: 0.3,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              icon: _publishing
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded, size: 16),
              label: const Text(
                'Publicar',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildPreview(),
                  const SizedBox(height: 16),
                  _buildCaptionField(),
                  const SizedBox(height: 16),
                  _buildSourceButtons(),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    return AspectRatio(
      aspectRatio: 9 / 16,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 480),
        decoration: BoxDecoration(
          color: AppColors.surfaceCards,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.surfaceAlt, width: 0.8),
        ),
        clipBehavior: Clip.antiAlias,
        child: _bytes == null
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 44,
                      color: Color(0xFF6E6E78),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Elige una imagen o un video',
                      style: TextStyle(fontSize: 13, color: Color(0xFF6E6E78)),
                    ),
                  ],
                ),
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  if (_mediaType == 'VIDEO')
                    const ColoredBox(
                      color: Colors.black87,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.videocam_outlined,
                              size: 44,
                              color: Colors.white70,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Video seleccionado',
                              style: TextStyle(color: Colors.white54),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Image.memory(_bytes!, fit: BoxFit.cover),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: GestureDetector(
                      onTap: () {
                        _videoPreview?.dispose();
                        _videoPreview = null;
                        setState(() {
                          _bytes = null;
                          _filename = null;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black54,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildCaptionField() {
    return TextField(
      controller: _captionController,
      maxLines: 3,
      maxLength: 500,
      style: const TextStyle(fontSize: 14, color: Colors.white),
      decoration: InputDecoration(
        hintText: 'Añade un texto (opcional)...',
        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF6A6A7A)),
        filled: true,
        fillColor: AppColors.surfaceCards,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.surfaceAlt, width: 0.8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1),
        ),
      ),
    );
  }

  Widget _buildSourceButtons() {
    return Row(
      children: [
        Expanded(
          child: _SourceButton(
            icon: Icons.photo_library_outlined,
            label: 'Galería (imagen)',
            onTap: () => _pickMedia(ImageSource.gallery, video: false),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SourceButton(
            icon: Icons.video_library_outlined,
            label: 'Galería (video)',
            onTap: () => _pickMedia(ImageSource.gallery, video: true),
          ),
        ),
      ],
    );
  }
}

class _SourceButton extends StatelessWidget {
  const _SourceButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceCards,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.surfaceAlt, width: 0.8),
        ),
        child: Column(
          children: [
            Icon(icon, size: 22, color: AppColors.accentTeal),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
