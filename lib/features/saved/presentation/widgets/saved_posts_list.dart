import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../features/feed/presentation/widgets/post_card.dart';
import '../../../../models/post.dart';
import '../bookmarks_controller.dart';

/// Lista de publicaciones guardadas con estados de carga/vacío/error,
/// pull-to-refresh y scroll infinito. Reutilizable desde `SavedScreen` y el
/// tab "Guardados" del perfil.
class SavedPostsList extends ConsumerStatefulWidget {
  const SavedPostsList({super.key});

  @override
  ConsumerState<SavedPostsList> createState() => _SavedPostsListState();
}

class _SavedPostsListState extends ConsumerState<SavedPostsList> {
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
      ref.read(bookmarksControllerProvider.notifier).loadMore();
    }
  }

  Future<void> _onRefresh() {
    return ref.read(bookmarksControllerProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final BookmarksState state = ref.watch(bookmarksControllerProvider);

    if (state.error != null && state.posts.isEmpty) {
      return ErrorView(message: state.error!, onRetry: _onRefresh);
    }

    if (state.posts.isEmpty) {
      return RefreshIndicator(
        onRefresh: _onRefresh,
        color: Theme.of(context).colorScheme.primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: ClampingScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(16, 40, 16, 100),
          children: const [
            EmptyView(
              icon: Icons.bookmark_rounded,
              title: 'Sin publicaciones guardadas',
              message: 'Tus publicaciones guardadas aparecerán aquí.',
            ),
          ],
        ),
      );
    }

    final posts = state.posts;
    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: Theme.of(context).colorScheme.primary,
      child: ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: posts.length + 1,
        itemBuilder: (context, index) {
          if (index >= posts.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: state.loadingMore
                  ? const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const SizedBox.shrink(),
            );
          }
          final Post post = posts[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: AppDimens.md),
            child: PostCard(post: post),
          );
        },
      ),
    );
  }
}
