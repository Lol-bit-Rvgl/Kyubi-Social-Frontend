import 'package:flutter/material.dart';
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
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _tagsController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    final tags = _tagsController.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
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
                  maxLength: 80,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Título (opcional)',
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
                      maxLength: 2000,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Escribe algo para el círculo'
                          : null,
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
                        const Text(
                          '2000 caracteres máx.',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontStyle: FontStyle.italic,
                            color: Color(0xFF7A7A8E),
                          ),
                        ),
                        Icon(
                          Icons.text_fields_rounded,
                          size: 16,
                          color: Colors.white.withValues(alpha: 0.3),
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
                child: TextFormField(
                  controller: _tagsController,
                  style: const TextStyle(fontSize: 13.5, color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Etiquetas (separadas por coma)',
                    hintText: 'terror, roleplay, comunidad',
                    prefixIcon: Icon(
                      Icons.tag_rounded,
                      size: 20,
                      color: AppColors.accentCyan,
                    ),
                    border: InputBorder.none,
                  ),
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
              onPressed: _saving ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B2D60),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
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
