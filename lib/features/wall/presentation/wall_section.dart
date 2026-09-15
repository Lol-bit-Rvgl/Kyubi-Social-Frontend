import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/kyubi_blob.dart';
import '../../../../models/wall_entry.dart';
import '../../../../services/auth_controller.dart';
import '../../../../services/providers.dart';

/// Muro de publicaciones de un perfil (backend real: /wall/[userId]).
class WallSection extends ConsumerStatefulWidget {
  const WallSection({super.key, required this.ownerId});

  /// Id o username del dueño del muro. Acepta 'me'.
  final String ownerId;

  @override
  ConsumerState<WallSection> createState() => _WallSectionState();
}

class _WallSectionState extends ConsumerState<WallSection> {
  final _controller = TextEditingController();
  List<WallEntry> _entries = [];
  bool _loading = true;
  bool _posting = false;
  bool _hasMore = true;
  bool _loadingMore = false;
  int _page = 1;
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
        _page = 1;
        _hasMore = page.entries.length >= 20 && page.pages > 1;
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

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final repo = ref.read(wallRepositoryProvider);
      final page = await repo.getWall(widget.ownerId, page: _page + 1);
      if (!mounted) return;
      setState(() {
        _entries = [..._entries, ...page.entries];
        _page += 1;
        _hasMore = page.entries.isNotEmpty && page.pages > _page;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  Future<void> _post() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
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
        const SnackBar(content: Text('No se pudo publicar en el muro')),
      );
    }
  }

  Future<void> _toggleLike(WallEntry entry) async {
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo eliminar la publicación')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppDimens.sm),
        Text(
          'Muro',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppDimens.sm),
        _buildComposer(),
        const SizedBox(height: AppDimens.sm),
        _buildContent(),
      ],
    );
  }

  Widget _buildComposer() {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            minLines: 1,
            maxLines: 4,
            maxLength: 2000,
            decoration: InputDecoration(
              hintText: 'Escribe en el muro...',
              counterText: '',
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppDimens.md,
                vertical: AppDimens.sm,
              ),
              filled: true,
              fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppDimens.xs),
        _posting
            ? const Padding(
                padding: EdgeInsets.all(AppDimens.sm),
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
              )
            : IconButton.filled(
                icon: const Icon(Icons.send_rounded),
                onPressed: _post,
                tooltip: 'Publicar',
              ),
      ],
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppDimens.xl),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppDimens.sm),
        child: _InlineRetry(message: _error!, onRetry: _load),
      );
    }
    if (_entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppDimens.lg),
        child: Column(
          children: [
            SizedBox(
              width: 84,
              height: 84,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  KyubiBlob(
                    size: 84,
                    color: AppColors.primary.withValues(alpha: 0.12),
                    tail: true,
                  ),
                  Icon(
                    Icons.edit_note_rounded,
                    size: 36,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimens.sm),
            Text(
              'Sin publicaciones en el muro',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      children: [
        for (final entry in _entries) ...[
          _WallTile(
            entry: entry,
            onLike: () => _toggleLike(entry),
            onDelete: entry.isAuthor || _canDelete(entry) || _isOwner
                ? () => _delete(entry)
                : null,
          ),
          Divider(
            height: 1,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ],
        if (_hasMore)
          _loadingMore
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppDimens.sm),
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : TextButton(onPressed: _loadMore, child: const Text('Ver más')),
      ],
    );
  }

  bool get _isOwner {
    final myId = ref.read(authControllerProvider).user?.id;
    return myId != null && myId == widget.ownerId;
  }

  bool _canDelete(WallEntry entry) {
    final myId = ref.read(authControllerProvider).user?.id;
    return myId != null && entry.authorId == myId;
  }
}

class _WallTile extends StatelessWidget {
  const _WallTile({required this.entry, required this.onLike, this.onDelete});

  final WallEntry entry;
  final VoidCallback onLike;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppAvatar(
            imageUrl: entry.authorAvatarUrl,
            name: entry.authorName,
            radius: AppDimens.avatarSm / 2,
          ),
          const SizedBox(width: AppDimens.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.authorName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (entry.isAuthor)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Icon(
                          Icons.verified_rounded,
                          size: 14,
                          color: AppColors.primary,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDate(entry.createdAt),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                Text(entry.text, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _ReactionButton(
                      icon: entry.isLikedByMe
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: entry.isLikedByMe ? AppColors.danger : null,
                      label: entry.likes > 0 ? '${entry.likes}' : 'Me gusta',
                      onTap: onLike,
                    ),
                    if (onDelete != null)
                      _ReactionButton(
                        icon: Icons.delete_outline_rounded,
                        label: 'Eliminar',
                        color: scheme.error,
                        onTap: onDelete!,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return '';
    final now = DateTime.now();
    final diff = now.difference(parsed);
    if (diff.inSeconds < 60) return 'Ahora';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
    if (diff.inDays < 7) return 'Hace ${diff.inDays} d';
    return DateUtilsX.formatDayMonthYear(parsed.toLocal());
  }
}

class _ReactionButton extends StatelessWidget {
  const _ReactionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final effective = color ?? scheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimens.radiusFull),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: effective),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: effective,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineRetry extends StatelessWidget {
  const _InlineRetry({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.error,
          ),
        ),
        const SizedBox(height: AppDimens.xs),
        TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Reintentar'),
        ),
      ],
    );
  }
}
