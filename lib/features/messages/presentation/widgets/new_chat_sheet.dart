import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../models/user.dart';
import '../../../../services/auth_controller.dart';
import '../../../../services/providers.dart';

/// Bottom sheet "Nuevo mensaje privado".
///
/// Lista los seguidos/seguidores (amigos) con buscador local en memoria.
/// Al tocar un contacto, abre o crea la conversación directa y navega a
/// `/dm/:id`, cerrando el sheet. No navega a la búsqueda global.
class NewChatSheet extends ConsumerStatefulWidget {
  const NewChatSheet({super.key});

  static Future<void> show(BuildContext context) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const NewChatSheet(),
    );
  }

  @override
  ConsumerState<NewChatSheet> createState() => _NewChatSheetState();
}

class _NewChatSheetState extends ConsumerState<NewChatSheet> {
  final TextEditingController _searchController = TextEditingController();

  List<FollowItem> _contacts = const <FollowItem>[];
  List<FollowItem> _filtered = const <FollowItem>[];
  bool _loading = true;
  String? _error;
  String? _openingId;

  @override
  void initState() {
    super.initState();
    _fetchContacts();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchContacts() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = ref.read(authControllerProvider).user;
      final usernameOrId = user?.username ?? user?.id ?? 'me';
      final repo = ref.read(userRepositoryProvider);

      final following = await repo.getFollowing(usernameOrId);
      final followers = await repo.getFollowers(usernameOrId);

      final Map<String, FollowItem> map = <String, FollowItem>{};
      for (final item in [...following.items, ...followers.items]) {
        if (item.id != user?.id &&
            item.username != user?.username &&
            item.id.isNotEmpty) {
          map.putIfAbsent(item.id, () => item);
        }
      }

      if (!mounted) return;
      setState(() {
        _contacts = map.values.toList();
        _filtered = _contacts;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudieron cargar tus contactos';
        _loading = false;
      });
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() => _filtered = _contacts);
      return;
    }
    setState(() {
      _filtered = _contacts.where((c) {
        return c.displayName.toLowerCase().contains(query) ||
            c.username.toLowerCase().contains(query);
      }).toList();
    });
  }

  Future<void> _openChat(FollowItem contact) async {
    if (_openingId != null) return;
    setState(() => _openingId = contact.id);
    try {
      final conversation = await ref
          .read(chatRepositoryProvider)
          .openOrCreateDirect(contact.id, username: contact.username);
      if (!mounted) return;
      Navigator.of(context).pop();
      context.push('/dm/${conversation.id}');
    } catch (_) {
      if (!mounted) return;
      setState(() => _openingId = null);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('No se pudo abrir el chat. Inténtalo de nuevo.'),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;
    final maxHeight = mediaQuery.size.height * 0.85;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: Color(0xFF13101E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: Color(0xFF2C2542), width: 1.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black87,
            blurRadius: 28,
            offset: Offset(0, -8),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.edit_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nuevo mensaje privado',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Elige un amigo para chatear',
                      style: TextStyle(fontSize: 12, color: Colors.white54),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white54),
                onPressed: () => Navigator.of(context).pop(),
                splashRadius: 20,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF1E192F),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white, fontSize: 13.5),
              decoration: InputDecoration(
                hintText: 'Buscar entre tus amigos...',
                hintStyle:
                    const TextStyle(color: Colors.white38, fontSize: 13),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: Colors.white38,
                  size: 20,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.clear_rounded,
                          color: Colors.white54,
                          size: 16,
                        ),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.white38,
              size: 36,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _fetchContacts,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Reintentar'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.accentTeal,
              ),
            ),
          ],
        ),
      );
    }

    if (_filtered.isEmpty) {
      final isSearching = _searchController.text.trim().isNotEmpty;
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSearching
                  ? Icons.search_off_rounded
                  : Icons.people_outline_rounded,
              color: Colors.white24,
              size: 40,
            ),
            const SizedBox(height: 10),
            Text(
              isSearching
                  ? 'Ningún amigo coincide con esa búsqueda'
                  : 'Aún no sigues a nadie. Sigue a usuarios para chatear.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: _filtered.length,
      separatorBuilder: (context, index) => const Divider(
        color: Colors.white10,
        height: 1,
        indent: 56,
      ),
      itemBuilder: (context, index) {
        final contact = _filtered[index];
        final opening = _openingId == contact.id;
        return InkWell(
          onTap: opening ? null : () => _openChat(contact),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFF2C2542),
                  backgroundImage: (contact.avatarUrl != null &&
                          contact.avatarUrl!.isNotEmpty)
                      ? NetworkImage(contact.avatarUrl!)
                      : null,
                  child: (contact.avatarUrl == null ||
                          contact.avatarUrl!.isEmpty)
                      ? Text(
                          contact.displayName.isNotEmpty
                              ? contact.displayName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contact.displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '@${contact.username}',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (opening)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  const Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: Colors.white54,
                    size: 20,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
