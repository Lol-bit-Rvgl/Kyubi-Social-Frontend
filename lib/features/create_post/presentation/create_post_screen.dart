import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../models/circle.dart';
import '../../../../services/auth_controller.dart';
import '../../../../services/providers.dart';
import '../../feed/presentation/feed_controller.dart';
import '../../profile/presentation/user_posts_controller.dart';

/// Creador de publicaciones de texto con estética Project Z y soporte estricto de SafeArea.
class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({super.key});

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _tagsController = TextEditingController();
  String _visibility = 'PUBLIC';
  String? _selectedCircleId;
  List<Circle> _myCircles = [];
  bool _loadingCircles = false;
  bool _circlesLoaded = false;
  bool _warnViolence = false;
  bool _warnAdult = false;
  bool _warnDark = false;
  bool _warnSpoiler = false;
  bool _saving = false;

  /// Límites de longitud alineados con el backend y las reglas de diseño.
  static const int _maxTitleLength = 50;
  static const int _maxBodyLength = 2000;
  static const int _maxTagsCount = 5;
  static const int _maxTagLength = 25;
  static const int _maxTagsTotalLength = 150;

  /// Máximo de imágenes por publicación (el backend limita a 4 en el grid del feed).
  static const int _maxImages = 4;

  final ImagePicker _imagePicker = ImagePicker();
  final List<_PickedImage> _selectedImages = [];
  bool _uploadingMedia = false;

  @override
  void initState() {
    super.initState();
    _loadMyCircles();
    _titleController.addListener(_onTextChanged);
    _bodyController.addListener(_onTextChanged);
    _tagsController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadMyCircles() async {
    setState(() => _loadingCircles = true);
    try {
      final circles = await ref.read(circleRepositoryProvider).getMyCircles();
      if (!mounted) return;
      setState(() {
        _myCircles = circles;
        _circlesLoaded = true;
        _loadingCircles = false;
        if (_selectedCircleId == null && circles.isNotEmpty) {
          _selectedCircleId = circles.first.id;
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _circlesLoaded = true;
          _loadingCircles = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _titleController.removeListener(_onTextChanged);
    _bodyController.removeListener(_onTextChanged);
    _tagsController.removeListener(_onTextChanged);
    _titleController.dispose();
    _bodyController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  List<String> get _parsedTags => _tagsController.text
      .split(',')
      .map((t) => t.trim())
      .where((t) => t.isNotEmpty)
      .toList();

  String? get _tagsValidationError {
    final raw = _tagsController.text.trim();
    if (raw.isEmpty) return null;

    final tags = _parsedTags;
    if (tags.length > _maxTagsCount) {
      return 'Máximo $_maxTagsCount etiquetas permitidas (${tags.length}/$_maxTagsCount)';
    }

    final invalidCharsRegex = RegExp(r'^[a-zA-Z0-9_\-\u00C0-\u017F\s#]+$');
    for (final tag in tags) {
      if (tag.length > _maxTagLength) {
        return 'La etiqueta "$tag" supera los $_maxTagLength caracteres (${tag.length}/$_maxTagLength)';
      }
      if (!invalidCharsRegex.hasMatch(tag)) {
        return 'La etiqueta "$tag" contiene caracteres no permitidos';
      }
    }
    return null;
  }

  int get _bodyLength => _bodyController.text.length;
  bool get _isBodyTooLong => _bodyLength > _maxBodyLength;
  bool get _isBodyEmpty => _bodyController.text.trim().isEmpty;
  bool get _isTitleTooLong => _titleController.text.length > _maxTitleLength;

  bool get _canSubmit {
    if (_saving || _uploadingMedia) return false;
    if (_isBodyEmpty || _isBodyTooLong) return false;
    if (_isTitleTooLong) return false;
    if (_tagsValidationError != null) return false;
    if (_visibility == 'CIRCLE' &&
        _selectedCircleId == null &&
        _myCircles.isEmpty) {
      return false;
    }
    return true;
  }

  /// Abre la galería y agrega hasta [_maxImages] imágenes seleccionadas.
  Future<void> _pickImages() async {
    try {
      final remaining = _maxImages - _selectedImages.length;
      if (remaining <= 0) return;
      FocusScope.of(context).unfocus();
      final picked = await _imagePicker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 1920,
      );
      if (picked.isEmpty) return;
      final loaded = <_PickedImage>[];
      for (final file in picked) {
        final bytes = await file.readAsBytes();
        loaded.add(_PickedImage(file, bytes));
      }
      if (!mounted) return;
      setState(() {
        _selectedImages.addAll(loaded.take(remaining));
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudieron cargar las imágenes')),
      );
    }
  }

  /// Descarta una imagen de la previsualización antes de publicar.
  void _removeImage(int index) {
    setState(() => _selectedImages.removeAt(index));
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    if (!_formKey.currentState!.validate()) return;
    if (_tagsValidationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_tagsValidationError!),
          backgroundColor: AppColors.accentCrimson,
        ),
      );
      return;
    }
    if (_visibility == 'CIRCLE') {
      if (_myCircles.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No perteneces a ningún círculo para publicar con visibilidad Círculo',
            ),
          ),
        );
        return;
      }
      if (_selectedCircleId == null || _selectedCircleId!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Debes seleccionar un círculo'),
          ),
        );
        return;
      }
    }
    FocusScope.of(context).unfocus();
    // Gamefeel: impacto medio al publicar (acción principal).
    HapticFeedback.mediumImpact();
    setState(() => _saving = true);
    final tags = _parsedTags
        .take(_maxTagsCount)
        .map((t) => t.length > _maxTagLength ? t.substring(0, _maxTagLength) : t)
        .toList();
    try {
      // Subir las imágenes seleccionadas antes de crear la publicación.
      var mediaUrls = const <String>[];
      if (_selectedImages.isNotEmpty) {
        if (!mounted) return;
        setState(() => _uploadingMedia = true);
        final uploadRepo = ref.read(uploadRepositoryProvider);
        final urls = <String>[];
        for (final image in _selectedImages) {
          final url = await uploadRepo.uploadFile(
            'media',
            bytes: image.bytes,
            filename: image.file.name.isNotEmpty
                ? image.file.name
                : 'image.jpg',
          );
          urls.add(url);
        }
        mediaUrls = urls;
        if (!mounted) return;
        setState(() => _uploadingMedia = false);
      }

      final post = await ref
          .read(postRepositoryProvider)
          .createPost(
            title: _titleController.text.trim(),
            body: _bodyController.text.trim(),
            visibility: _visibility,
            circleId: _visibility == 'CIRCLE' ? _selectedCircleId : null,
            tags: tags,
            mediaUrls: mediaUrls,
            warnViolence: _warnViolence,
            warnAdult: _warnAdult,
            warnDark: _warnDark,
            warnSpoiler: _warnSpoiler,
          );
      if (!mounted) return;
      // Inserción optimista selectiva: un post PRIVATE nunca se inyecta en el
      // feed público (el backend lo excluye vía `visibility: PUBLIC`, así que
      // aparecería y desaparecería al recargar). En su lugar se invalida el
      // muro del perfil propio, que sí lo devuelve para su autor.
      final myId = ref.read(authControllerProvider).user?.id;
      if (!post.isPrivate) {
        ref.read(feedControllerProvider.notifier).insertPostAtTop(post);
      }
      if (myId != null) ref.invalidate(userPostsProvider(myId));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Publicación creada')));
      context.go('/app/feed');
    } catch (e) {
      if (!mounted) return;
      // Se conserva el texto escrito; solo se restablecen los estados de carga.
      setState(() {
        _saving = false;
        _uploadingMedia = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo publicar: $e')));
    }
  }

  /// Cuadrícula de miniaturas de las imágenes seleccionadas más un tile para
  /// agregar más (hasta [_maxImages]).
  Widget _buildImagePreview() {
    final canAdd = _selectedImages.length < _maxImages;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.photo_library_rounded,
              size: 16,
              color: AppColors.accentCyan,
            ),
            const SizedBox(width: 6),
            Text(
              '${_selectedImages.length} de $_maxImages imágenes',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFFB0B0C0),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1,
          ),
          itemCount: _selectedImages.length + (canAdd ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == _selectedImages.length) return _buildAddTile();
            return _buildThumbnail(index);
          },
        ),
      ],
    );
  }

  /// Miniatura con botón de eliminar.
  Widget _buildThumbnail(int index) {
    final image = _selectedImages[index];
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            image.bytes,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              color: const Color(0xFF1E1E2A),
              child: const Icon(Icons.broken_image, color: Colors.white24),
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () => _removeImage(index),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 14,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Tile para agregar más imágenes desde la galería.
  Widget _buildAddTile() {
    return GestureDetector(
      onTap: _uploadingMedia ? null : _pickImages,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF14141B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF22222E), width: 0.8),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_photo_alternate_outlined,
              size: 22,
              color: Color(0xFF6A6A7E),
            ),
            SizedBox(height: 4),
            Text(
              'Añadir',
              style: TextStyle(fontSize: 11, color: Color(0xFF6A6A7E)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundBase,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundBase,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Crear publicación',
          style: TextStyle(
            fontSize: 16.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
      ),
      body: SafeArea(
        bottom: true,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              // ── Campo de Título ──
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF14141B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _isTitleTooLong
                        ? AppColors.accentCrimson
                        : const Color(0xFF22222E),
                    width: 0.8,
                  ),
                ),
                child: TextFormField(
                  controller: _titleController,
                  maxLength: _maxTitleLength,
                  maxLengthEnforcement: MaxLengthEnforcement.enforced,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(_maxTitleLength),
                  ],
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Título (opcional, máx. 50)',
                    hintText: '¿De qué trata tu publicación?',
                    border: InputBorder.none,
                    counterStyle: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF6A6A7E),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ── Campo de Contenido ──
              Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF14141B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _isBodyTooLong
                        ? AppColors.accentCrimson
                        : const Color(0xFF22222E),
                    width: 0.8,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _bodyController,
                      minLines: 6,
                      maxLines: 12,
                      maxLength: _maxBodyLength,
                      maxLengthEnforcement: MaxLengthEnforcement.enforced,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(_maxBodyLength),
                      ],
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Escribe algo para publicar';
                        }
                        if (v.length > _maxBodyLength) {
                          return 'El contenido no puede superar $_maxBodyLength caracteres';
                        }
                        return null;
                      },
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: Colors.white,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Comparte una historia, idea o noticia...',
                        hintStyle: TextStyle(
                          fontSize: 13.5,
                          color: Color(0xFF6A6A7E),
                        ),
                        border: InputBorder.none,
                        counterText: '',
                      ),
                    ),
                    const Divider(color: Color(0xFF22222E), height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$_bodyLength / $_maxBodyLength caracteres',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: _bodyLength > _maxBodyLength
                                ? AppColors.accentCrimson
                                : (_bodyLength >= 1800
                                    ? Colors.orangeAccent
                                    : const Color(0xFF7A7A8E)),
                          ),
                        ),
                        Icon(
                          Icons.text_fields_rounded,
                          size: 16,
                          color: _bodyLength > _maxBodyLength
                              ? AppColors.accentCrimson
                              : Colors.white.withValues(alpha: 0.3),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ── Previsualización de imágenes seleccionadas ──
              if (_selectedImages.isNotEmpty) ...[
                _buildImagePreview(),
                const SizedBox(height: 12),
              ],

              // ── Campo de Etiquetas ──
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF14141B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _tagsValidationError != null
                        ? AppColors.accentCrimson
                        : const Color(0xFF22222E),
                    width: 0.8,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _tagsController,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(_maxTagsTotalLength),
                      ],
                      style: const TextStyle(fontSize: 13.5, color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Etiquetas (máx. $_maxTagsCount, hasta $_maxTagLength car. c/u)',
                        hintText: 'terror, roleplay, anime',
                        prefixIcon: Icon(
                          Icons.tag_rounded,
                          size: 20,
                          color: _tagsValidationError != null
                              ? AppColors.accentCrimson
                              : AppColors.accentCyan,
                        ),
                        border: InputBorder.none,
                        suffixText: '${_parsedTags.length}/$_maxTagsCount',
                        suffixStyle: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: _parsedTags.length > _maxTagsCount
                              ? AppColors.accentCrimson
                              : const Color(0xFF6A6A7E),
                        ),
                      ),
                    ),
                    if (_tagsValidationError != null) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6, left: 4),
                        child: Text(
                          _tagsValidationError!,
                          style: const TextStyle(
                            color: AppColors.accentCrimson,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ── Selector de Visibilidad ──
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF14141B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF22222E),
                    width: 0.8,
                  ),
                ),
                child: DropdownButtonFormField<String>(
                  initialValue: _visibility,
                  dropdownColor: const Color(0xFF191924),
                  style: const TextStyle(fontSize: 13.5, color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Visibilidad',
                    border: InputBorder.none,
                    prefixIcon: Icon(
                      Icons.public_rounded,
                      size: 20,
                      color: AppColors.accentCrimson,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'PUBLIC', child: Text('Público')),
                    DropdownMenuItem(value: 'CIRCLE', child: Text('Círculo')),
                    DropdownMenuItem(value: 'PRIVATE', child: Text('Privado')),
                  ],
                  onChanged: (v) {
                    setState(() {
                      _visibility = v ?? 'PUBLIC';
                      if (_visibility == 'CIRCLE' && !_circlesLoaded && !_loadingCircles) {
                        _loadMyCircles();
                      }
                    });
                  },
                ),
              ),

              // ── Selector de Círculo (si visibilidad es Círculo) ──
              if (_visibility == 'CIRCLE') ...[
                const SizedBox(height: 12),
                if (_loadingCircles)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF14141B),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF22222E),
                        width: 0.8,
                      ),
                    ),
                    child: const Row(
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.accentCyan,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Cargando tus círculos...',
                          style: TextStyle(
                            fontSize: 13.5,
                            color: Color(0xFFB0B0C0),
                          ),
                        ),
                      ],
                    ),
                  )
                else if (_myCircles.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1624),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.accentCyan.withValues(alpha: 0.4),
                        width: 0.8,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.bubble_chart_rounded,
                              size: 20,
                              color: AppColors.accentCyan,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'No perteneces a ningún círculo aún',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Únete a un círculo para compartir publicaciones temáticas con su comunidad.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.65),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () => context.push('/circles'),
                            style: TextButton.styleFrom(
                              backgroundColor: AppColors.accentCyan.withValues(alpha: 0.15),
                              foregroundColor: AppColors.accentCyan,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                            ),
                            icon: const Icon(Icons.explore_rounded, size: 16),
                            label: const Text(
                              'Explorar Círculos',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF14141B),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF22222E),
                        width: 0.8,
                      ),
                    ),
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedCircleId ?? (_myCircles.isNotEmpty ? _myCircles.first.id : null),
                      dropdownColor: const Color(0xFF191924),
                      style: const TextStyle(fontSize: 13.5, color: Colors.white),
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Seleccionar Círculo',
                        border: InputBorder.none,
                        prefixIcon: Icon(
                          Icons.bubble_chart_rounded,
                          size: 20,
                          color: AppColors.accentCyan,
                        ),
                      ),
                      validator: (v) {
                        if (_visibility == 'CIRCLE' && (v == null || v.isEmpty)) {
                          return 'Debes seleccionar un círculo';
                        }
                        return null;
                      },
                      items: _myCircles.map((circle) {
                        return DropdownMenuItem<String>(
                          value: circle.id,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  circle.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              if (circle.isPrivate) ...[
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.lock_rounded,
                                  size: 13,
                                  color: Colors.white38,
                                ),
                              ],
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (v) => setState(() => _selectedCircleId = v),
                    ),
                  ),
              ],

              const SizedBox(height: 16),

              // ── Avisos de Contenido (Warnings) ──
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 17,
                      color: Color(0xFFFFD600),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Avisos de contenido',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              _WarningCheck(
                label: 'Violencia',
                value: _warnViolence,
                onChanged: (v) => setState(() => _warnViolence = v),
              ),
              const SizedBox(height: 6),
              _WarningCheck(
                label: 'Contenido adulto',
                value: _warnAdult,
                onChanged: (v) => setState(() => _warnAdult = v),
              ),
              const SizedBox(height: 6),
              _WarningCheck(
                label: 'Tema oscuro',
                value: _warnDark,
                onChanged: (v) => setState(() => _warnDark = v),
              ),
              const SizedBox(height: 6),
              _WarningCheck(
                label: 'Contiene spoilers',
                value: _warnSpoiler,
                onChanged: (v) => setState(() => _warnSpoiler = v),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        bottom: true,
        child: Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewPadding.bottom + 12,
            left: 16,
            right: 16,
            top: 8,
          ),
          decoration: const BoxDecoration(
            color: AppColors.backgroundBase,
            border: Border(
              top: BorderSide(color: Color(0xFF22222E), width: 0.8),
            ),
          ),
          child: Row(
            children: [
              // Botón de adjuntar imágenes de la galería.
              if (!_uploadingMedia)
                IconButton(
                  onPressed: _selectedImages.length >= _maxImages
                      ? null
                      : _pickImages,
                  style: IconButton.styleFrom(
                    foregroundColor: AppColors.accentCyan,
                    disabledForegroundColor: Colors.white24,
                    backgroundColor: const Color(0xFF14141B),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: Color(0xFF22222E)),
                    ),
                  ),
                  tooltip: 'Adjuntar imágenes (máx $_maxImages)',
                  icon: const Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 22,
                  ),
                ),
              if (_uploadingMedia)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.accentCyan,
                    ),
                  ),
                ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _canSubmit ? _submit : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _canSubmit
                          ? AppColors.accentCrimson
                          : const Color(0xFF33202A),
                      foregroundColor: _canSubmit
                          ? Colors.white
                          : Colors.white38,
                      disabledBackgroundColor: const Color(0xFF221620),
                      disabledForegroundColor: Colors.white24,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: _canSubmit ? 4 : 0,
                      shadowColor: AppColors.accentCrimson.withValues(
                        alpha: 0.4,
                      ),
                    ),
                    child: (_saving || _uploadingMedia)
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Subiendo imágenes…',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '✈️ Publicar',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WarningCheck extends StatelessWidget {
  const _WarningCheck({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: value
            ? AppColors.accentCrimson.withValues(alpha: 0.1)
            : const Color(0xFF14141B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: value
              ? AppColors.accentCrimson.withValues(alpha: 0.45)
              : const Color(0xFF22222E),
          width: 0.8,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: CheckboxListTile(
          value: value,
          onChanged: (v) => onChanged(v ?? false),
          activeColor: AppColors.accentCrimson,
          checkColor: Colors.white,
          title: Text(
            label,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: value ? FontWeight.w700 : FontWeight.w500,
              color: value ? Colors.white : const Color(0xFFB0B0C0),
            ),
          ),
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          controlAffinity: ListTileControlAffinity.leading,
        ),
      ),
    );
  }
}

/// Imagen seleccionada de la galería junto con sus bytes ya leídos
/// (para mostrar la miniatura y subirla sin volver a leer el archivo).
class _PickedImage {
  const _PickedImage(this.file, this.bytes);

  final XFile file;
  final Uint8List bytes;
}
