import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../models/role_slot.dart';
import 'role_slots_controller.dart';

/// Crea o edita una vacante de rol ([RoleSlot]) de una publicación.
///
/// - Creación: solo requiere [postId].
/// - Edición: recibe además la vacante en [slot], o su id en [slotId]/[targetSlotId].
class RoleSlotEditorScreen extends ConsumerStatefulWidget {
  const RoleSlotEditorScreen({
    super.key,
    required this.postId,
    this.slot,
    this.slotId,
    this.targetSlotId,
  });

  final String postId;
  final RoleSlot? slot;
  final String? slotId;
  final String? targetSlotId;

  @override
  ConsumerState<RoleSlotEditorScreen> createState() =>
      _RoleSlotEditorScreenState();
}

class _RoleSlotEditorScreenState extends ConsumerState<RoleSlotEditorScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _requirementsController = TextEditingController();

  bool _isOpen = true;
  bool _saving = false;
  String? _activeSlotId;
  bool _creatingNew = false;
  bool _initialized = false;

  void _applySlot(RoleSlot s) {
    _titleController.text = s.title;
    _descriptionController.text = s.description ?? '';
    _requirementsController.text = s.requirements ?? '';
    _isOpen = s.isOpen;
  }

  @override
  void initState() {
    super.initState();
    _activeSlotId = widget.targetSlotId ?? widget.slotId ?? widget.slot?.id;
    final slot = widget.slot;
    if (slot != null) {
      _applySlot(slot);
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _requirementsController.dispose();
    super.dispose();
  }

  Future<void> _save(RoleSlot? currentSlot, bool isEditing) async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ponle un título a la vacante')),
      );
      return;
    }
    if (_saving) return;
    setState(() => _saving = true);

    final description = _descriptionController.text.trim();
    final requirements = _requirementsController.text.trim();
    final notifier = ref.read(
      roleSlotsControllerProvider(widget.postId).notifier,
    );

    final success = isEditing && currentSlot != null
        ? await notifier.updateSlot(
            currentSlot.id,
            title: title,
            description: description.isEmpty ? null : description,
            requirements: requirements.isEmpty ? null : requirements,
            isOpen: _isOpen,
          )
        : await notifier.createSlot(
            title: title,
            description: description.isEmpty ? null : description,
            requirements: requirements.isEmpty ? null : requirements,
          );

    if (!mounted) return;
    setState(() => _saving = false);

    if (success) {
      context.pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo guardar la vacante')),
      );
    }
  }

  Future<void> _delete(RoleSlot currentSlot) async {
    if (_saving) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF14141B),
        title: const Text(
          '¿Eliminar vacante?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Se eliminará "${currentSlot.title}" y no se podrá recuperar.',
          style: const TextStyle(color: Color(0xFFB3B3C4)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);
    final ok = await ref
        .read(roleSlotsControllerProvider(widget.postId).notifier)
        .deleteSlot(currentSlot.id);
    if (!mounted) return;
    setState(() => _saving = false);

    if (ok) {
      context.pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo eliminar la vacante')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final slotsState = ref.watch(roleSlotsControllerProvider(widget.postId));
    final slots = slotsState.slots;
    final targetSlotId = _activeSlotId ?? widget.targetSlotId ?? widget.slotId ?? widget.slot?.id;

    // Acceso nulo-seguro y validación de índice
    final foundIndex = targetSlotId != null
        ? slots.indexWhere((s) => s.id == targetSlotId)
        : -1;
    final currentSlot = (foundIndex >= 0 && foundIndex < slots.length)
        ? slots[foundIndex]
        : (slots.isNotEmpty && !_creatingNew ? slots.first : widget.slot);

    if (!_initialized && currentSlot != null && !_creatingNew) {
      _initialized = true;
      _activeSlotId = currentSlot.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _applySlot(currentSlot);
      });
    }

    final isEditing = !_creatingNew && currentSlot != null;

    final String buttonLabel;
    if (isEditing) {
      buttonLabel = 'Guardar cambios';
    } else if (slots.isEmpty) {
      buttonLabel = '+ Crear primer slot';
    } else {
      buttonLabel = 'Crear vacante';
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D0B14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0B14),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: _saving ? null : () => context.pop(),
        ),
        title: Text(
          isEditing ? 'Editar vacante' : 'Nueva vacante',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          if (isEditing)
            IconButton(
              tooltip: 'Eliminar',
              onPressed: _saving ? null : () => _delete(currentSlot),
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.danger,
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimens.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (slots.isNotEmpty) ...[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ...slots.map((s) {
                      final isSelected = isEditing && currentSlot.id == s.id;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(s.title),
                          selected: isSelected,
                          onSelected: (_) {
                            setState(() {
                              _creatingNew = false;
                              _activeSlotId = s.id;
                              _applySlot(s);
                            });
                          },
                        ),
                      );
                    }),
                    ActionChip(
                      avatar: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('Nueva vacante'),
                      onPressed: () {
                        setState(() {
                          _creatingNew = true;
                          _activeSlotId = null;
                          _titleController.clear();
                          _descriptionController.clear();
                          _requirementsController.clear();
                          _isOpen = true;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimens.md),
            ],
            _field(
              label: 'Título del rol',
              controller: _titleController,
              hint: 'Ej: El guardián del portal',
              maxLength: 120,
            ),
            const SizedBox(height: AppDimens.md),
            _field(
              label: 'Descripción',
              controller: _descriptionController,
              hint: 'Cuénta qué hace este rol en la historia...',
              maxLength: 2000,
              maxLines: 5,
            ),
            const SizedBox(height: AppDimens.md),
            _field(
              label: 'Requisitos',
              controller: _requirementsController,
              hint: 'Ej: escribir mínimo 100 palabras por respuesta',
              maxLength: 1000,
              maxLines: 3,
            ),
            const SizedBox(height: AppDimens.md),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Vacante abierta',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: const Text(
                'Otras personas pueden postularse',
                style: TextStyle(color: Color(0xFF8A8A9A), fontSize: 12),
              ),
              value: _isOpen,
              activeThumbColor: AppColors.accentTeal,
              onChanged: (v) => setState(() => _isOpen = v),
            ),
            const SizedBox(height: AppDimens.lg),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _saving ? null : () => _save(currentSlot, isEditing),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accentCrimson,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                  ),
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
                    : Text(buttonLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    required String hint,
    required int maxLength,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLength: maxLength,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
            filled: true,
            fillColor: const Color(0xFF14141B),
            counterStyle: const TextStyle(color: Color(0xFF6A6A7A)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}
