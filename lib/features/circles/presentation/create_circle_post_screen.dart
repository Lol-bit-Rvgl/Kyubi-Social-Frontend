import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/liquid_glass_container.dart';
import '../../../../services/providers.dart';
import 'circle_detail_controller.dart';

/// Creador de publicaciones dentro de un círculo con soporte de SafeArea.
class CreateCirclePostScreen extends ConsumerStatefulWidget {
  const CreateCirclePostScreen({super.key, required this.circleId});

  final String circleId;

  @override
  ConsumerState<CreateCirclePostScreen> createState() =>
      _CreateCirclePostScreenState();
}

class _CreateCirclePostScreenState
    extends ConsumerState<CreateCirclePostScreen> {
  final _formKey = GlobalKey<FormState>();
  static const int _maxTitleLength = 50;
  static const int _maxBodyLength = 2000;
  static const int _maxTagsCount = 5;
  static const int _maxTagLength = 25;
  static const int _maxTagsTotalLength = 150;

  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _tagsController = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_onTextChanged);
    _bodyController.addListener(_onTextChanged);
    _tagsController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
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
    if (_saving) return false;
    if (_isBodyEmpty || _isBodyTooLong) return false;
    if (_isTitleTooLong) return false;
    if (_tagsValidationError != null) return false;
    return true;
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
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    final tags = _parsedTags
        .take(_maxTagsCount)
        .map((t) => t.length > _maxTagLength ? t.substring(0, _maxTagLength) : t)
        .toList();
    try {
      final post = await ref
          .read(circleRepositoryProvider)
          .createCirclePost(
            widget.circleId,
            title: _titleController.text.trim(),
            body: _bodyController.text.trim(),
            tags: tags,
          );
      if (!mounted) return;
      ref
          .read(circleDetailControllerProvider(widget.circleId).notifier)
          .insertPostAtTop(post);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Publicación creada')));
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo publicar: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundBase,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundBase,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Publicar en el círculo',
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
              // ── Título ──
              LiquidGlassContainer(
                borderRadius: 16,
                blur: 12,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
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

              // ── Contenido ──
              LiquidGlassContainer(
                borderRadius: 16,
                blur: 12,
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
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
                          return 'Escribe algo para el círculo';
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
                        hintText: 'Comparte con el círculo...',
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

              // ── Etiquetas ──
              LiquidGlassContainer(
                borderRadius: 16,
                blur: 12,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
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
                        hintText: 'terror, roleplay, comunidad',
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
          child: SizedBox(
            height: 48,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _canSubmit ? _submit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _canSubmit
                    ? const Color(0xFF3B2D60)
                    : const Color(0xFF221A36),
                foregroundColor: _canSubmit ? Colors.white : Colors.white38,
                disabledBackgroundColor: const Color(0xFF1B152B),
                disabledForegroundColor: Colors.white24,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: _canSubmit ? 4 : 0,
                shadowColor: const Color(0xFF9B6FCB).withValues(alpha: 0.4),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
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
      ),
    );
  }
}
