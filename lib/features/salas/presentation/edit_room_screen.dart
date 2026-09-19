import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/room_backgrounds.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../models/room.dart';
import '../../../../services/providers.dart';
import 'sala_detail_controller.dart';



/// Pantalla Completa de Edición de Sala (Ref: Admin / Co-Admin Settings).
class EditRoomScreen extends ConsumerStatefulWidget {
  const EditRoomScreen({
    super.key,
    this.room,
    this.initialCoverUrl,
    this.initialBgUrl,
    this.initialThemeColor,
  });

  static const int maxTags = 5;

  final Room? room;
  final String? initialCoverUrl;
  final String? initialBgUrl;
  final Color? initialThemeColor;

  @override
  ConsumerState<EditRoomScreen> createState() => _EditRoomScreenState();
}

class _EditRoomScreenState extends ConsumerState<EditRoomScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  late final TextEditingController _tagInputController;

  String? _coverUrl;
  String? _bgUrl;
  Uint8List? _coverBytes;
  Uint8List? _bgBytes;
  String? _coverFilename;
  String? _bgFilename;
  bool _saving = false;
  Color _themeColor = const Color(0xFF00E5FF);
  List<String> _tags = [];
  List<String> _rules = [];
  bool _isPrivate = false;

  @override
  void initState() {
    super.initState();
    final r = widget.room;
    final roomId = r?.id;
    final liveRoom = (roomId != null
        ? ref.read(salaDetailControllerProvider(roomId)).room
        : null) ?? r;
    _nameController = TextEditingController(text: liveRoom?.name ?? 'Sala de Kyubi');
    _descController = TextEditingController(
      text: liveRoom?.description ?? liveRoom?.lore ?? '',
    );
    _tagInputController = TextEditingController();

    _coverUrl =
        widget.initialCoverUrl ??
        liveRoom?.host.avatarUrl ??
        r?.host.avatarUrl ??
        'https://images.unsplash.com/photo-1578632767115-351597cf2477?w=500&auto=format&fit=crop&q=60';
    _bgUrl =
        widget.initialBgUrl ??
        liveRoom?.chatBackgroundUrl ??
        'https://images.unsplash.com/photo-1518531933037-91b2f5f229cc?w=500&auto=format&fit=crop&q=60';
    _themeColor = widget.initialThemeColor ?? const Color(0xFF00E5FF);
    if (liveRoom != null) {
      _tags = List<String>.from(liveRoom.tags);
      _rules = List<String>.from(liveRoom.rules);
    } else {
      _tags = ['Roleplay', 'Anime', 'Social'];
      _rules = [
        'Mantén el respeto y el ambiente de rol.',
        'No compartas información personal de otros.',
        'Sigue el lore y el turno de cada personaje.',
        'El host puede moderar la sala en cualquier momento.',
      ];
    }
    _isPrivate = (liveRoom ?? r)?.access == RoomAccess.private;
  }

  @override
  void didUpdateWidget(covariant EditRoomScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final roomId = widget.room?.id;
    final liveRoom = (roomId != null
        ? ref.read(salaDetailControllerProvider(roomId)).room
        : null) ?? widget.room;
    final liveDesc = liveRoom?.description ?? liveRoom?.lore;
    if (_descController.text.trim().isEmpty && liveDesc != null && liveDesc.trim().isNotEmpty) {
      _descController.value = TextEditingValue(
        text: liveDesc,
        selection: TextSelection.collapsed(offset: liveDesc.length),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _tagInputController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(
    void Function(String path, Uint8List bytes, String filename) onPicked,
  ) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final bytes = await image.readAsBytes();
      final filename = image.name;
      if (!mounted) return;
      setState(() => onPicked(image.path, bytes, filename));
    }
  }

  Future<void> _selectChatBackground() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF14111F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF00E5FF)),
              title: const Text(
                'Catálogo Jay Sen (Gradientes)',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
              subtitle: const Text(
                'Fondos oficiales atmosféricos optimizados',
                style: TextStyle(color: Colors.white60, fontSize: 12),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                final selected = await showRoomBackgroundSelector(
                  context,
                  currentAsset: _bgUrl,
                  title: 'Fondo del Chat',
                );
                if (selected != null) {
                  setState(() {
                    if (selected.id == 'default' || selected.assetPath.isEmpty) {
                      _bgUrl = null;
                      _bgBytes = null;
                      _bgFilename = null;
                    } else {
                      _bgUrl = selected.assetPath;
                      _bgBytes = null;
                      _bgFilename = null;
                    }
                  });
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: Colors.white70),
              title: const Text(
                'Elegir de la galería',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage((path, bytes, filename) {
                  _bgUrl = path;
                  _bgBytes = bytes;
                  _bgFilename = filename;
                });
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _addTag() {
    if (_tags.length >= EditRoomScreen.maxTags) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Límite máximo de 5 etiquetas alcanzado'),
          backgroundColor: Color(0xFF2A121E),
        ),
      );
      return;
    }
    final raw = _tagInputController.text.trim();
    final tag = raw.replaceAll(RegExp(r'^#+'), '').trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagInputController.clear();
      });
    }
  }

  void _addRuleDialog() {
    if (_rules.length >= 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Límite alcanzado: máximo 10 reglas por sala.'),
          backgroundColor: Color(0xFF2A121E),
        ),
      );
      return;
    }
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF14121F),
        title: const Text('Nueva Regla', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          maxLength: 140,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Escribe la norma de la sala...',
            hintStyle: TextStyle(color: Color(0xFF7A7A8E)),
            counterStyle: TextStyle(color: Color(0xFF9E9EAF), fontSize: 11),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty && _rules.length < 10) {
                setState(() => _rules.add(text));
              }
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accentCrimson,
            ),
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveChanges() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El nombre de la sala no puede estar vacío'),
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    if (_saving) return;
    setState(() => _saving = true);

    // Subir las imágenes recién seleccionadas (bytes locales) al storage y usar
    // las URLs públicas devueltas. Si no se cambió imagen, se conserva la
    // URL existente (Unsplash o un valor previamente persistido).
    String? resolvedCover = _coverUrl;
    String? resolvedBg = _bgUrl;
    try {
      final upload = ref.read(uploadRepositoryProvider);
      if (_coverBytes != null && _coverFilename != null) {
        resolvedCover = await upload.uploadFile(
          'media',
          bytes: _coverBytes!,
          filename: _coverFilename!,
        );
      }
      if (_bgBytes != null && _bgFilename != null) {
        resolvedBg = await upload.uploadFile(
          'media',
          bytes: _bgBytes!,
          filename: _bgFilename!,
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo subir las imágenes de la sala'),
          backgroundColor: Color(0xFF2A121E),
        ),
      );
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pop<Map<String, dynamic>>({
      'name': name,
      'description': _descController.text.trim(),
      'coverUrl': resolvedCover,
      'bgUrl': resolvedBg,
      'themeColor': _themeColor,
      'tags': _tags,
      'rules': _rules,
      'isPrivate': _isPrivate,
    });
  }

  @override
  Widget build(BuildContext context) {
    final roomId = widget.room?.id;
    if (roomId != null) {
      ref.listen(salaDetailControllerProvider(roomId), (prev, next) {
        final liveDesc = next.room?.description ?? next.room?.lore;
        if (_descController.text.trim().isEmpty &&
            liveDesc != null &&
            liveDesc.trim().isNotEmpty) {
          _descController.value = TextEditingValue(
            text: liveDesc,
            selection: TextSelection.collapsed(offset: liveDesc.length),
          );
        }
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D0C15),
      appBar: AppBar(
        backgroundColor: const Color(0xFF13101E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Editar Sala',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: TextButton(
              onPressed: _saveChanges,
              style: TextButton.styleFrom(
                backgroundColor: AppColors.accentCrimson,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Guardar',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── 1. PORTADA & FONDO DE PANTALLA ──
          _sectionTitle('Apariencia Visual'),
          const SizedBox(height: 10),
          Row(
            children: [
              // Portada
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Foto de Portada',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () => _pickImage((path, bytes, filename) {
                        _coverUrl = path;
                        _coverBytes = bytes;
                        _coverFilename = filename;
                      }),
                      child: Container(
                        height: 90,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B172B),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF2E2744),
                            width: 0.8,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: _coverBytes != null
                            ? Image.memory(
                                _coverBytes!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                              )
                            : _coverUrl != null
                            ? CachedNetworkImage(
                                imageUrl: _coverUrl!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                errorWidget: (_, _, _) => const Icon(
                                  Icons.image_rounded,
                                  color: Colors.white70,
                                ),
                              )
                            : const Center(
                                child: Icon(
                                  Icons.add_photo_alternate_rounded,
                                  color: AppColors.accentCyan,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              // Wallpaper de Chat
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Fondo del Chat',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: _selectChatBackground,
                      child: Container(
                        height: 90,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B172B),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF2E2744),
                            width: 0.8,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: _bgBytes != null
                            ? Image.memory(
                                _bgBytes!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                              )
                            : _bgUrl != null
                            ? (_bgUrl!.startsWith('assets/')
                                ? Image.asset(
                                    _bgUrl!,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    errorBuilder: (_, _, _) => const Icon(
                                      Icons.wallpaper_rounded,
                                      color: Colors.white70,
                                    ),
                                  )
                                : CachedNetworkImage(
                                    imageUrl: _bgUrl!,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    errorWidget: (_, _, _) => const Icon(
                                      Icons.wallpaper_rounded,
                                      color: Colors.white70,
                                    ),
                                  ))
                            : const Center(
                                child: Icon(
                                  Icons.add_photo_alternate_rounded,
                                  color: AppColors.accentCyan,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),
          const Divider(color: Color(0xFF221E32)),
          const SizedBox(height: 10),

          // ── 2. DATOS BÁSICOS ──
          _sectionTitle('Información General'),
          const SizedBox(height: 12),

          // Nombre
          const Text(
            'Nombre de la Sala',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _nameController,
            maxLength: 30,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: _inputDecoration('Ej. Viod returns party').copyWith(
              counterStyle: const TextStyle(
                color: Color(0xFF9E9EAF),
                fontSize: 11,
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Descripción
          const Text(
            'Descripción / Lore',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _descController,
            maxLength: 300,
            maxLines: 3,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: _inputDecoration(
              'Describe el tema y propósito de la sala...',
            ).copyWith(
              counterStyle: const TextStyle(
                color: Color(0xFF9E9EAF),
                fontSize: 11,
              ),
            ),
          ),

          const SizedBox(height: 22),
          const Divider(color: Color(0xFF221E32)),
          const SizedBox(height: 10),

          // ── 3. ETIQUETAS / TAGS ──
          _sectionTitle(
            'Etiquetas Temáticas (${_tags.length}/${EditRoomScreen.maxTags})',
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _tagInputController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  onSubmitted: (_) => _addTag(),
                  decoration: _inputDecoration(
                    'Agregar tag (#Cyberpunk, #Voz)...',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _tags.length >= EditRoomScreen.maxTags ? null : _addTag,
                style: IconButton.styleFrom(
                  backgroundColor: _tags.length >= EditRoomScreen.maxTags
                      ? AppColors.textSecondary.withValues(alpha: 0.25)
                      : AppColors.accentCyan,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: Icon(
                  Icons.add_rounded,
                  color: _tags.length >= EditRoomScreen.maxTags
                      ? Colors.white38
                      : Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _tags.map((t) {
              return Chip(
                backgroundColor: const Color(0xFF1B172B),
                label: Text(
                  '#$t',
                  style: const TextStyle(
                    color: AppColors.accentCyan,
                    fontSize: 12,
                  ),
                ),
                deleteIcon: const Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: Colors.white70,
                ),
                onDeleted: () => setState(() => _tags.remove(t)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: Color(0xFF2E2744), width: 0.8),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 22),
          const Divider(color: Color(0xFF221E32)),
          const SizedBox(height: 10),

          // ── 4. REGLAS DE LA SALA ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionTitle('Reglas de la Sala (${_rules.length}/10)'),
              TextButton.icon(
                onPressed: _rules.length >= 10 ? null : _addRuleDialog,
                icon: Icon(
                  Icons.add_rounded,
                  size: 16,
                  color: _rules.length >= 10
                      ? AppColors.textSecondary.withValues(alpha: 0.5)
                      : AppColors.accentCyan,
                ),
                label: Text(
                  '+ Regla',
                  style: TextStyle(
                    color: _rules.length >= 10
                        ? AppColors.textSecondary.withValues(alpha: 0.5)
                        : AppColors.accentCyan,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._rules.asMap().entries.map((entry) {
            final idx = entry.key;
            final rule = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF141122),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF241E34), width: 0.8),
              ),
              child: Row(
                children: [
                  Text(
                    '${idx + 1}.',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: AppColors.accentCrimson,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      rule,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.redAccent,
                      size: 20,
                    ),
                    splashRadius: 18,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    tooltip: 'Eliminar regla',
                    onPressed: () => setState(() => _rules.removeAt(idx)),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 3.5,
          height: 16,
          decoration: BoxDecoration(
            color: AppColors.accentCrimson,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF6A6A7E), fontSize: 13),
      filled: true,
      fillColor: const Color(0xFF1B172B),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF2E2744), width: 0.8),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.accentCyan, width: 1.2),
      ),
    );
  }
}
