import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../models/post.dart';
import '../../../../services/providers.dart';
import '../feed_controller.dart';
import '../../../profile/presentation/user_posts_controller.dart';

class _NewMediaItem {
  _NewMediaItem({required this.file, required this.bytes});
  final XFile file;
  final Uint8List bytes;
}

/// Modal inferior para edición completa de una publicación:
/// Título, contenido/descripción, gestión de imágenes (eliminar/añadir) y visibilidad.
class EditPostModal extends ConsumerStatefulWidget {
  const EditPostModal({super.key, required this.post});

  final Post post;

  static Future<void> show(BuildContext context, {required Post post}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF14141B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => EditPostModal(post: post),
    );
  }

  @override
  ConsumerState<EditPostModal> createState() => _EditPostModalState();
}

class _EditPostModalState extends ConsumerState<EditPostModal> {
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  late String _selectedVisibility;
  late List<String> _retainedMediaUrls;
  final List<_NewMediaItem> _newImages = [];
  bool _saving = false;
  final ImagePicker _picker = ImagePicker();

  static const int _maxImages = 9;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.post.title);
    _bodyController = TextEditingController(text: widget.post.body);
    _selectedVisibility = widget.post.visibility;
    _retainedMediaUrls = widget.post.mediaUrls.isNotEmpty
        ? List<String>.from(widget.post.mediaUrls)
        : widget.post.media
            .map((m) => m.url)
            .where((u) => u.isNotEmpty)
            .toList();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  int get _totalImagesCount => _retainedMediaUrls.length + _newImages.length;

  Future<void> _pickImages() async {
    final remaining = _maxImages - _totalImagesCount;
    if (remaining <= 0) return;
    try {
      final picked = await _picker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 1920,
      );
      if (picked.isEmpty) return;
      for (final file in picked.take(remaining)) {
        final bytes = await file.readAsBytes();
        _newImages.add(_NewMediaItem(file: file, bytes: bytes));
      }
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudieron cargar las imágenes')),
        );
      }
    }
  }

  Future<void> _pickFilesFromSystem() async {
    final remaining = _maxImages - _totalImagesCount;
    if (remaining <= 0) return;
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'jpg',
          'jpeg',
          'png',
          'webp',
          'mp4',
          'm4a',
          'mp3',
          'aac',
          'pdf',
        ],
        allowMultiple: true,
      );
      if (result == null || result.files.isEmpty) return;
      for (final file in result.files.take(remaining)) {
        Uint8List? bytes = file.bytes;
        final path = file.path;
        if (bytes == null && path != null) {
          final f = File(path);
          if (await f.exists()) {
            bytes = await f.readAsBytes();
          }
        }
        if (bytes != null) {
          final xFile = path != null
              ? XFile(path)
              : XFile.fromData(bytes, name: file.name);
          _newImages.add(_NewMediaItem(file: xFile, bytes: bytes));
        }
      }
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudieron cargar los archivos seleccionados'),
          ),
        );
      }
    }
  }

  void _showMediaPickerOptions() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF141220),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: Color(0xFF2E2746), width: 1)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library_rounded,
                  color: AppColors.accentCyan,
                ),
                title: const Text(
                  'Galería rápida / Fotos',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: const Text(
                  'Selector multimedia predeterminado de la app',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImages();
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.folder_open_rounded,
                  color: Color(0xFF4DD0E1),
                ),
                title: const Text(
                  'Explorador de Archivos / Sistema',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: const Text(
                  'Almacenamiento nativo, carpetas y documentos',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickFilesFromSystem();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _removeExistingImage(int index) {
    setState(() => _retainedMediaUrls.removeAt(index));
  }

  void _removeNewImage(int index) {
    setState(() => _newImages.removeAt(index));
  }

  Future<void> _submit() async {
    final newTitle = _titleController.text.trim();
    final newBody = _bodyController.text.trim();

    if (newBody.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El contenido no puede estar vacío')),
      );
      return;
    }

    if (newBody.length > 2000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El contenido no puede superar 2000 caracteres')),
      );
      return;
    }

    if (newTitle.length > 50) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El título no puede superar 50 caracteres')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final uploadRepo = ref.read(uploadRepositoryProvider);
      final uploadedUrls = <String>[];

      for (final item in _newImages) {
        final url = await uploadRepo.uploadFile(
          'media',
          bytes: item.bytes,
          filename: item.file.name.isNotEmpty
              ? item.file.name
              : 'edited_image_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        uploadedUrls.add(url);
      }

      final finalMediaUrls = [..._retainedMediaUrls, ...uploadedUrls];

      final updated = await ref.read(postRepositoryProvider).updatePost(
            widget.post.id,
            title: newTitle,
            body: newBody,
            visibility: _selectedVisibility,
            mediaUrls: finalMediaUrls,
          );

      ref.read(feedControllerProvider.notifier).updatePost(updated);
      ref
          .read(userPostsProvider(widget.post.author.id).notifier)
          .updatePost(updated);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Publicación actualizada correctamente'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo actualizar la publicación')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, bottomInset + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Pestaña de arrastre
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF3A3A4A),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Encabezado
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Editar publicación',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Campo de Título
            TextField(
              controller: _titleController,
              enabled: !_saving,
              maxLength: 50,
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
              inputFormatters: [
                LengthLimitingTextInputFormatter(50),
              ],
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14.5,
              ),
              decoration: InputDecoration(
                hintText: 'Título (opcional, máx. 50)',
                hintStyle: const TextStyle(color: Color(0xFF6E6888)),
                counterStyle: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF6E6888),
                ),
                filled: true,
                fillColor: const Color(0xFF1E1A2B),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF2E2A40)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF2E2A40)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.accentCyan),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Campo de Contenido / Descripción
            TextField(
              controller: _bodyController,
              enabled: !_saving,
              maxLines: 5,
              minLines: 3,
              maxLength: 2000,
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
              inputFormatters: [
                LengthLimitingTextInputFormatter(2000),
              ],
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: '¿Qué estás pensando?',
                hintStyle: const TextStyle(color: Color(0xFF6E6888)),
                counterStyle: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF6E6888),
                ),
                filled: true,
                fillColor: const Color(0xFF1E1A2B),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF2E2A40)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF2E2A40)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.accentCyan),
                ),
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
            const SizedBox(height: 14),

            // Gestión de Imágenes Adjuntas
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Imágenes adjuntas',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFB0B0C0),
                  ),
                ),
                Text(
                  '$_totalImagesCount/$_maxImages',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6E6888),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            SizedBox(
              height: 88,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  // Imágenes existentes
                  for (int i = 0; i < _retainedMediaUrls.length; i++)
                    _buildExistingThumbnail(i, _retainedMediaUrls[i]),

                  // Imágenes nuevas seleccionadas
                  for (int i = 0; i < _newImages.length; i++)
                    _buildNewThumbnail(i, _newImages[i]),

                  // Botón para añadir más imágenes
                  if (_totalImagesCount < _maxImages) _buildAddMediaButton(),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Selector de Visibilidad
            Row(
              children: [
                const Text(
                  'Visibilidad:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFB0B0C0),
                  ),
                ),
                const SizedBox(width: 12),
                ChoiceChip(
                  label: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.public_rounded, size: 14),
                      SizedBox(width: 4),
                      Text('Público'),
                    ],
                  ),
                  selected: _selectedVisibility != 'PRIVATE',
                  onSelected: _saving
                      ? null
                      : (selected) {
                          if (selected) {
                            setState(() => _selectedVisibility = 'PUBLIC');
                          }
                        },
                  selectedColor: AppColors.accentCyan.withValues(alpha: 0.25),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: _selectedVisibility != 'PRIVATE'
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: _selectedVisibility != 'PRIVATE'
                        ? AppColors.accentCyan
                        : const Color(0xFFB0B0C0),
                  ),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_rounded, size: 14),
                      SizedBox(width: 4),
                      Text('Solo yo'),
                    ],
                  ),
                  selected: _selectedVisibility == 'PRIVATE',
                  onSelected: _saving
                      ? null
                      : (selected) {
                          if (selected) {
                            setState(() => _selectedVisibility = 'PRIVATE');
                          }
                        },
                  selectedColor: AppColors.accentCyan.withValues(alpha: 0.25),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: _selectedVisibility == 'PRIVATE'
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: _selectedVisibility == 'PRIVATE'
                        ? AppColors.accentCyan
                        : const Color(0xFFB0B0C0),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Botones Cancelar / Guardar
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(color: Color(0xFF8E88A8)),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _saving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentCyan,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 11,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Text(
                          'Guardar',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExistingThumbnail(int index, String url) {
    return Container(
      width: 80,
      height: 80,
      margin: const EdgeInsets.only(right: 8),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: CachedNetworkImage(
              imageUrl: url,
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              placeholder: (_, _) => Container(
                color: const Color(0xFF221F33),
                alignment: Alignment.center,
                child: const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              errorWidget: (_, _, _) => Container(
                color: const Color(0xFF221F33),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.broken_image_rounded,
                  color: Colors.white38,
                  size: 20,
                ),
              ),
            ),
          ),
          if (!_saving)
            Positioned(
              top: 2,
              right: 2,
              child: GestureDetector(
                onTap: () => _removeExistingImage(index),
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Colors.black87,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 13,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNewThumbnail(int index, _NewMediaItem item) {
    return Container(
      width: 80,
      height: 80,
      margin: const EdgeInsets.only(right: 8),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.memory(
              item.bytes,
              width: 80,
              height: 80,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            bottom: 3,
            left: 3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
              decoration: BoxDecoration(
                color: AppColors.accentCyan.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'NUEVA',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          if (!_saving)
            Positioned(
              top: 2,
              right: 2,
              child: GestureDetector(
                onTap: () => _removeNewImage(index),
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Colors.black87,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 13,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAddMediaButton() {
    return Container(
      width: 80,
      height: 80,
      margin: const EdgeInsets.only(right: 8),
      child: Material(
        color: const Color(0xFF1E1A2B),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: _saving ? null : _showMediaPickerOptions,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(
                Icons.add_photo_alternate_rounded,
                color: AppColors.accentCyan,
                size: 24,
              ),
              SizedBox(height: 4),
              Text(
                'Añadir',
                style: TextStyle(
                  color: AppColors.accentCyan,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
