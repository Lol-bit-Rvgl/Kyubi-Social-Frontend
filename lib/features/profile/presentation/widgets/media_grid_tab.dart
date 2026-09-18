import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/kyubi_shimmer.dart';
import '../../../../models/media.dart';
import '../../../../models/post.dart';
import '../user_posts_controller.dart';

/// Pestaña "Multimedia" del perfil: grid de fotos/videos extraídos de las
/// publicaciones del usuario ([userPostsProvider]).
class MediaGridTab extends ConsumerWidget {
  const MediaGridTab({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(userPostsProvider(userId));

    if (state.loading && state.posts.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    final items = _collectMedia(state.posts);

    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.photo_library_outlined,
                size: 44,
                color: Colors.white.withValues(alpha: 0.2),
              ),
              const SizedBox(height: 10),
              const Text(
                'Sin contenido multimedia aún',
                style: TextStyle(fontSize: 13, color: Color(0xFF7A7A8E)),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(
        parent: ClampingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            color: AppColors.surfaceCards,
            child: CachedNetworkImage(
              imageUrl: item,
              fit: BoxFit.cover,
              placeholder: (_, _) =>
                  const KyubiShimmer(color: AppColors.surfaceCards),
              errorWidget: (_, _, _) => const Icon(
                Icons.broken_image_outlined,
                color: Color(0xFF6E6E78),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Extrae URLs de imágenes de las publicaciones del usuario.
  List<String> _collectMedia(List<Post> posts) {
    final urls = <String>[];
    for (final post in posts) {
      urls.addAll(post.mediaUrls);
      if (post.coverImageUrl != null && post.coverImageUrl!.isNotEmpty) {
        urls.add(post.coverImageUrl!);
      }
      for (final media in post.media) {
        if (media.type == MediaType.image && media.url.isNotEmpty) {
          urls.add(media.url);
        }
      }
    }
    return urls.toSet().toList();
  }
}
