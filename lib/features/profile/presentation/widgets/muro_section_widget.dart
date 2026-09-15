import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_view/photo_view.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/kyubi_rich_text.dart';
import '../../../../models/wall_entry.dart';
import '../../../../services/auth_controller.dart';
import '../../../../services/providers.dart';

/// Módulo de Muro de firmas interactivo estilo Clover Space / Kubi-Space.
class MuroSectionWidget extends ConsumerStatefulWidget {
  const MuroSectionWidget({
    super.key,
    required this.ownerId,
    this.onSpecialTextTap,
  });

  final String ownerId;
  final void Function(String text)? onSpecialTextTap;

  @override
  ConsumerState<MuroSectionWidget> createState() => _MuroSectionWidgetState();
}

class _MuroSectionWidgetState extends ConsumerState<MuroSectionWidget> {
  final _controller = TextEditingController();
  List<WallEntry> _entries = [];
  bool _loading = true;
  bool _posting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(wallRepositoryProvider);
      final page = await repo.getWall(widget.ownerId, page: 1);
      if (!mounted) return;
      setState(() {
        _entries = page.entries;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _post() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    // Gamefeel: impacto medio al firmar en el muro (acción principal).
    HapticFeedback.mediumImpact();
    setState(() => _posting = true);
    try {
      final repo = ref.read(wallRepositoryProvider);
      final entry = await repo.createEntry(widget.ownerId, text: text);
      if (!mounted) return;
      _controller.clear();
      setState(() {
        _entries = [entry, ..._entries];
        _posting = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _posting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo firmar en el muro')),
      );
    }
  }

  Future<void> _toggleLike(WallEntry entry) async {
    // Gamefeel: respuesta háptica ligera al dar like en el muro.
    HapticFeedback.lightImpact();
    try {
      final repo = ref.read(wallRepositoryProvider);
      final counts = await repo.toggleReaction(entry.id, 'like');
      if (!mounted) return;
      setState(() {
        _entries = [
          for (final e in _entries)
            if (e.id == entry.id)
              WallEntry(
                id: e.id,
                authorId: e.authorId,
                authorName: e.authorName,
                authorAvatarUrl: e.authorAvatarUrl,
                authorEmoji: e.authorEmoji,
                isAuthor: e.isAuthor,
                text: e.text,
                createdAt: e.createdAt,
                imageUrl: e.imageUrl,
                parentId: e.parentId,
                replyToUsername: e.replyToUsername,
                likes: counts.total,
                isLikedByMe: !e.isLikedByMe,
                myReaction: e.isLikedByMe ? null : 'like',
                repliesCount: e.repliesCount,
              )
            else
              e,
        ];
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No se pudo reaccionar')));
    }
  }

  Future<void> _delete(WallEntry entry) async {
    try {
      final repo = ref.read(wallRepositoryProvider);
      await repo.deleteEntry(entry.id);
      if (!mounted) return;
      setState(() => _entries.removeWhere((e) => e.id == entry.id));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No se pudo eliminar')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final myId = ref.watch(authControllerProvider).user?.id;

    return Container(
      padding: const EdgeInsets.all(AppDimens.md),
      decoration: BoxDecoration(
        color: const Color(0xFF14141B).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        border: Border.all(color: const Color(0xFF22222E), width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Composer / Caja de firma rápida ──
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  minLines: 1,
                  maxLines: 3,
                  maxLength: 2000,
                  buildCounter: (
                    context, {
                    required currentLength,
                    required isFocused,
                    maxLength,
                  }) =>
                      currentLength > 1800
                          ? Text(
                              '$currentLength/$maxLength',
                              style: const TextStyle(
                                color: Color(0xFF9E9EAF),
                                fontSize: 10,
                              ),
                            )
                          : null,
                  style: const TextStyle(fontSize: 13.5, color: Colors.white),
                  decoration: InputDecoration(
                    hintText: '✍️ Escribe una publicación en el muro...',
                    hintStyle: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF6A6A7A),
                    ),
                    isDense: true,
                    filled: true,
                    fillColor: const Color(0xFF1A1A26),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: Color(0xFF2E2E3E),
                        width: 0.8,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: Color(0xFF2E2E3E),
                        width: 0.8,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: AppColors.accentCrimson,
                        width: 1,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _posting ? null : _post,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: AppColors.crimsonGlow,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accentCrimson.withValues(alpha: 0.3),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: _posting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.send_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.accentCrimson,
                  ),
                ),
              ),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'No se pudieron cargar las publicaciones del muro',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ),
            )
          else if (_entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.article_outlined,
                      size: 32,
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'El muro no tiene publicaciones aún.\n¡Sé el primero en firmar o compartir!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _entries.length,
              itemBuilder: (context, index) {
                final entry = _entries[index];
                final canDelete =
                    entry.authorId == myId || widget.ownerId == myId;

                return _WallEntryTile(
                  entry: entry,
                  canDelete: canDelete,
                  onLike: () => _toggleLike(entry),
                  onDelete: () => _delete(entry),
                  onSpecialTextTap: widget.onSpecialTextTap,
                );
              },
            ),
        ],
      ),
    );
  }
}

class _WallEntryTile extends StatelessWidget {
  const _WallEntryTile({
    required this.entry,
    required this.canDelete,
    required this.onLike,
    required this.onDelete,
    this.onSpecialTextTap,
  });

  final WallEntry entry;
  final bool canDelete;
  final VoidCallback onLike;
  final VoidCallback onDelete;
  final void Function(String text)? onSpecialTextTap;

  @override
  Widget build(BuildContext context) {
    final hasImage =
        entry.imageUrl != null && entry.imageUrl!.trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161622),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF262638), width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: Avatar, Autor, Fecha y Botón Eliminar si es propio ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.accentCrimson.withValues(alpha: 0.4),
                    width: 1.2,
                  ),
                ),
                padding: const EdgeInsets.all(1.5),
                child: AppAvatar(
                  name: entry.authorName,
                  imageUrl: entry.authorAvatarUrl,
                  radius: 17,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            entry.authorName,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (entry.authorEmoji.isNotEmpty) ...[
                          const SizedBox(width: 5),
                          Text(
                            entry.authorEmoji,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 1),
                    Text(
                      _formatTime(entry.createdAt),
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF7A7A8E),
                      ),
                    ),
                  ],
                ),
              ),
              if (canDelete)
                GestureDetector(
                  onTap: onDelete,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      size: 15,
                      color: AppColors.danger,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // ── Cuerpo de texto multilínea legible ──
          if (entry.text.trim().isNotEmpty)
            KyubiRichText(
              text: entry.text,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.45,
                color: Colors.white.withValues(alpha: 0.9),
              ),
              onTap: onSpecialTextTap,
            ),

          // ── Imagen adjunta (Si NO hay imagen, NO renderizar contenedor gris; auto-height) ──
          if (hasImage) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      backgroundColor: Colors.black,
                      appBar: AppBar(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                      ),
                      body: PhotoView(
                        imageProvider: NetworkImage(entry.imageUrl!),
                        minScale: PhotoViewComputedScale.contained,
                        maxScale: PhotoViewComputedScale.covered * 2,
                        backgroundDecoration: const BoxDecoration(
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: entry.imageUrl!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  placeholder: (_, _) => const SizedBox(
                    height: 160,
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.accentCrimson,
                      ),
                    ),
                  ),
                  errorWidget: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
          ],

          const SizedBox(height: 10),

          // ── Footer: Botón de Reacción / Like ──
          GestureDetector(
            onTap: onLike,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: entry.isLikedByMe
                    ? AppColors.accentCrimson.withValues(alpha: 0.15)
                    : const Color(0xFF1E1E2C),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: entry.isLikedByMe
                      ? AppColors.accentCrimson.withValues(alpha: 0.4)
                      : const Color(0xFF2E2E3E),
                  width: 0.7,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    entry.isLikedByMe
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    size: 13,
                    color: entry.isLikedByMe
                        ? AppColors.accentCrimson
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    entry.likes > 0 ? '${entry.likes}' : 'Like',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: entry.isLikedByMe
                          ? AppColors.accentCrimson
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(String iso) {
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return '';
    final now = DateTime.now();
    final diff = now.difference(parsed);
    if (diff.inSeconds < 60) return 'Ahora';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return DateUtilsX.formatShortDate(parsed.toLocal());
  }
}
