import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../feed/presentation/widgets/post_card.dart';
import '../user_posts_controller.dart';

/// Pestaña de publicaciones del perfil, alimentada por [userPostsProvider].
///
/// Implementada como un scrollable [ListView] independiente compatible con [NestedScrollView].
class PostsTabSection extends ConsumerWidget {
  const PostsTabSection({
    super.key,
    required this.userId,
    this.withCreateOption = false,
  });

  /// Id del usuario cuyas publicaciones se muestran.
  final String userId;

  /// Si es `true` (perfil propio) el estado vacío ofrece "Crear Primer Post".
  final bool withCreateOption;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(userPostsProvider(userId));
    final notifier = ref.read(userPostsProvider(userId).notifier);

    if (state.loading && state.posts.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 40, 16, 100),
        children: const [
          Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.accentCrimson,
              ),
            ),
          ),
        ],
      );
    }

    if (state.error != null && state.posts.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 30, 16, 100),
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                state.error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: notifier.refresh,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ],
      );
    }

    if (state.posts.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 30, 16, 100),
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.auto_stories_outlined,
                  size: 40,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
                const SizedBox(height: 10),
                Text(
                  withCreateOption
                      ? 'No hay publicaciones compartidas aún'
                      : 'Este usuario no ha compartido publicaciones aún',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (withCreateOption) ...[
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => context.push('/create-post'),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Crear Primer Post'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentCrimson,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.extentAfter < 320) {
          notifier.loadMore();
        }
        return false;
      },
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: state.posts.length + (state.loadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= state.posts.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: AppDimens.md),
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
            );
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: PostCard(post: state.posts[index]),
          );
        },
      ),
    );
  }
}
