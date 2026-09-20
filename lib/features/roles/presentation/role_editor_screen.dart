import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/hexagon_avatar.dart';
import '../../../../models/character.dart';
import '../../../../models/role_character.dart';
import '../../../../repositories/character_repository.dart';
import '../../../../services/providers.dart';

TextInputFormatter _graphemeLimiter(int maxGraphemes) {
  return TextInputFormatter.withFunction((oldValue, newValue) {
    if (newValue.text.characters.length > maxGraphemes) {
      final truncated =
          newValue.text.characters.take(maxGraphemes).toString();
      return TextEditingValue(
        text: truncated,
        selection: TextSelection.collapsed(offset: truncated.length),
      );
    }
    return newValue;
  });
}

const _paletteColors = [
  Color(0xFFE5A93C), // Ámbar / Dorado (por defecto en ref)
  Color(0xFF00E5FF), // Cian neón
  AppColors.primary, // Carmesí Kyubi
  AppColors.accentTeal, // Verde esmeralda
  Color(0xFFD500F9), // Púrpura eléctrico
  Color(0xFFFF5252), // Rojo coral
  Color(0xFF448AFF), // Azul neón
  Color(0xFFFF4081), // Rosa fuerte
];

/// Pantalla para crear o editar un Rol/Personaje (Ref: Screenshot_20260729_212217_Gallery.jpg).
class RoleEditorScreen extends ConsumerStatefulWidget {
  const RoleEditorScreen({super.key, this.initialRole});

  final RoleCharacter? initialRole;

  @override
  ConsumerState<RoleEditorScreen> createState() => _RoleEditorScreenState();
}

class _RoleEditorScreenState extends ConsumerState<RoleEditorScreen> {
  bool _saving = false;
  final _nameController = TextEditingController();
  final _taglineController = TextEditingController();
  final _descriptionController = TextEditingController();

  String? _avatarPath;
  Color _selectedColor = const Color(0xFFE5A93C);

  @override
  void initState() {
    super.initState();
    if (widget.initialRole != null) {
      final role = widget.initialRole!;
      _nameController.text = role.name;
      _taglineController.text = role.tagline;
      _descriptionController.text = role.description;
      _avatarPath = role.avatarUrl;
      _selectedColor = role.color;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _taglineController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (image != null && mounted) {
        final ext = image.path.toLowerCase().split('.').last;
        if (!['jpg', 'jpeg', 'png', 'webp'].contains(ext)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Formato no permitido. Usa JPG, PNG o WebP.'),
              backgroundColor: AppColors.accentCrimson,
            ),
          );
          return;
        }
        setState(() => _avatarPath = image.path);
      }
    } catch (e) {
      debugPrint('Error picking avatar: $e');
    }
  }

  void _showColorPicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF141120),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Color del Rol',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: _paletteColors.map((c) {
                final isSelected = c == _selectedColor;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedColor = c);
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.transparent,
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: c.withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: isSelected
                        ? const Icon(
                            Icons.check_rounded,
                            color: Colors.black,
                            size: 24,
                          )
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _saveRole() async {
    if (_saving) return;

    final rawName = _nameController.text.trim();
    final name = rawName.characters.length > 20
        ? rawName.characters.take(20).toString()
        : rawName;
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor ingresa el nombre del rol')),
      );
      return;
    }

    final rawTagline = _taglineController.text.trim();
    final tagline = rawTagline.characters.length > 30
        ? rawTagline.characters.take(30).toString()
        : rawTagline;

    final rawDesc = _descriptionController.text.trim();
    final description = rawDesc.characters.length > 300
        ? rawDesc.characters.take(300).toString()
        : rawDesc;

    final hex =
        '#${_selectedColor.toARGB32().toRadixString(16).substring(2).toUpperCase()}';

    setState(() => _saving = true);

    String? uploadedAvatarUrl = _avatarPath;
    if (_avatarPath != null &&
        _avatarPath!.isNotEmpty &&
        !_avatarPath!.startsWith('http://') &&
        !_avatarPath!.startsWith('https://')) {
      try {
        final file = File(_avatarPath!);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          final ext = _avatarPath!.split('.').last;
          final filename =
              'avatar_${DateTime.now().millisecondsSinceEpoch}.$ext';
          uploadedAvatarUrl = await ref
              .read(uploadRepositoryProvider)
              .uploadFile(
                'avatar',
                bytes: bytes,
                filename: filename,
                contentType: 'image/$ext',
              );
        }
      } catch (e) {
        debugPrint('[ROLE_EDITOR] Error al subir avatar: $e');
      }
    }

    String finalRoleId = widget.initialRole?.id ?? '';
    if (widget.initialRole != null && finalRoleId.isNotEmpty) {
      try {
        await ref.read(characterRepositoryProvider).updateCharacter(
          finalRoleId,
          {
            'name': name,
            'tagline': tagline,
            'description': description,
            'avatarUrl': uploadedAvatarUrl,
            'themeColor': hex,
          },
        );
      } catch (e) {
        debugPrint('[ROLE_EDITOR] Error al actualizar personaje en backend: $e');
      }
    } else {
      try {
        final created = await ref.read(characterRepositoryProvider).createCharacter({
          'name': name,
          'tagline': tagline,
          'description': description,
          'avatarUrl': uploadedAvatarUrl,
          'themeColor': hex,
        });
        finalRoleId = created.id;
      } catch (e) {
        debugPrint('[ROLE_EDITOR] Error al crear personaje en backend: $e');
        finalRoleId = 'role_${DateTime.now().millisecondsSinceEpoch}';
      }
    }

    ref.invalidate(myCharactersProvider);

    final result = RoleCharacter(
      id: finalRoleId.isNotEmpty
          ? finalRoleId
          : 'role_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      avatarUrl: uploadedAvatarUrl,
      colorHex: hex,
      tagline: tagline,
      description: description,
    );

    if (mounted) {
      setState(() => _saving = false);
      context.pop(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialRole != null;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0B14),
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Bar ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Color(0xFF1E1A2B),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      isEditing ? 'Edit Role' : 'New Role',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _saving ? null : _saveRole,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Color(0xFF1E1A2B),
                        shape: BoxShape.circle,
                      ),
                      child: _saving
                          ? const Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.accentCyan,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 10),

                    // ── Hexagonal Avatar con borde punteado ──
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _pickAvatar,
                      child: Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          HexagonAvatar(
                            size: 140,
                            imageUrl: _avatarPath,
                            borderColor: _selectedColor.withValues(alpha: 0.8),
                            borderWidth: 2.5,
                            isDashed: _avatarPath == null,
                            onTap: _pickAvatar,
                            child: _avatarPath == null
                                ? Center(
                                    child: Icon(
                                      Icons.add_rounded,
                                      size: 48,
                                      color: Colors.white.withValues(alpha: 0.5),
                                    ),
                                  )
                                : null,
                          ),
                          if (_avatarPath != null)
                            Positioned(
                              bottom: 4,
                              right: 4,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: _selectedColor,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.5),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.edit_rounded,
                                  size: 16,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── Role Name Pill con Theme Color ──
                    Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: _selectedColor,
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: [
                          BoxShadow(
                            color: _selectedColor.withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _nameController,
                              maxLength: 20,
                              maxLengthEnforcement:
                                  MaxLengthEnforcement.none,
                              inputFormatters: [
                                _graphemeLimiter(20),
                              ],
                              onChanged: (_) => setState(() {}),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.black,
                              ),
                              decoration: const InputDecoration(
                                hintText: 'Role Name',
                                hintStyle: TextStyle(
                                  color: Color(0x99000000),
                                  fontWeight: FontWeight.w700,
                                ),
                                border: InputBorder.none,
                                counterText: '',
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: _showColorPicker,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.palette_rounded,
                                color: Colors.black,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_nameController.text.characters.length}/20',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF7A7A8A),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Tagline Field ──
                    TextField(
                      controller: _taglineController,
                      maxLength: 30,
                      maxLengthEnforcement: MaxLengthEnforcement.none,
                      inputFormatters: [
                        _graphemeLimiter(30),
                      ],
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      decoration: InputDecoration(
                        hintText: 'Tagline',
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                        enabledBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF2E2A3E)),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: _selectedColor),
                        ),
                        counterText: '',
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${_taglineController.text.characters.length}/30',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF7A7A8A),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Description Multiline Field (canonical max 300 chars) ──
                    TextField(
                      controller: _descriptionController,
                      maxLength: 300,
                      maxLengthEnforcement: MaxLengthEnforcement.none,
                      inputFormatters: [
                        _graphemeLimiter(300),
                      ],
                      maxLines: 6,
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        height: 1.4,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Description',
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                        border: InputBorder.none,
                        counterText: '',
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${_descriptionController.text.characters.length}/300',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF7A7A8A),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
