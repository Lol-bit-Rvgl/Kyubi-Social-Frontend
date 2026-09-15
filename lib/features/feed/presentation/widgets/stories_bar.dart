import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../models/story.dart';
import '../../../../services/auth_controller.dart';
import '../../../stories/presentation/story_controller.dart';

/// Barra horizontal de historias efímeras (stories 24h).
///
/// Muestra primero la burbuja "Tu historia" del usuario actual, seguida de los
/// grupos de historias activas devueltos por `GET /stories/feed`:
/// - Borde con gradiente Nebulæ (#D100D1 → #00D4B4) si el autor tiene historias
///   no vistas.
/// - Borde atenuado (#3F2A7C) cuando ya fueron todas vistas.
class StoriesBar extends ConsumerWidget {
  const StoriesBar({super.key});

  static const double _avatarSize = 62;
  static const double _ringWidth = 2.4;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storyState = ref.watch(storyControllerProvider);
    final currentUser = ref.watch(authControllerProvider).user;

    return SizedBox(
      height: 112,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: storyState.groups.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _AddStoryBubble(
              username: currentUser?.username ?? 'Tú',
              avatarUrl: currentUser?.effectiveAvatarUrl,
              onTap: () => context.push('/create-story'),
            );
          }

          final group = storyState.groups[index - 1];
          return _StoryBubble(
            group: group,
            onTap: () => context.push('/story-viewer', extra: group),
          );
        },
      ),
    );
  }
}

/// Burbuja de usuario con avatar y borde según estado de visualización.
class _StoryBubble extends StatelessWidget {
  const _StoryBubble({required this.group, required this.onTap});

  final StoryGroup group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final displayName = group.author.displayName.isNotEmpty
        ? group.author.displayName
        : group.author.username;

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: SizedBox(
          width: 74,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _GradientRingAvatar(
                avatarUrl: group.author.avatarUrl,
                hasUnseen: group.hasUnseen,
                size: StoriesBar._avatarSize,
                ringWidth: StoriesBar._ringWidth,
              ),
              const SizedBox(height: 6),
              Text(
                displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: group.hasUnseen
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: group.hasUnseen
                      ? Colors.white
                      : const Color(0xFF9E9EA8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Burbuja "Tu historia" con botón (+).
class _AddStoryBubble extends StatelessWidget {
  const _AddStoryBubble({
    required this.username,
    this.avatarUrl,
    required this.onTap,
  });

  final String username;
  final String? avatarUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: SizedBox(
          width: 74,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: StoriesBar._avatarSize,
                height: StoriesBar._avatarSize,
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.borderNight,
                          width: StoriesBar._ringWidth,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(3),
                        child: CircleAvatar(
                          radius: 25,
                          backgroundColor: AppColors.surfaceAlt,
                          backgroundImage:
                              avatarUrl != null && avatarUrl!.isNotEmpty
                              ? CachedNetworkImageProvider(avatarUrl!)
                              : null,
                          child: avatarUrl == null || avatarUrl!.isEmpty
                              ? Text(
                                  username.isNotEmpty
                                      ? username[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF4A3E7A),
                          border: Border.all(
                            color: AppColors.backgroundBase,
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.add_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Tu historia',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Avatar circular rodeado por el borde que indica estado de las historias:
/// gradiente Nebulæ (#D100D1 → #00D4B4) si hay historias no vistas,
/// atenuado (#3F2A7C) si ya fueron vistas.
class _GradientRingAvatar extends StatelessWidget {
  const _GradientRingAvatar({
    required this.avatarUrl,
    required this.hasUnseen,
    required this.size,
    required this.ringWidth,
  });

  final String? avatarUrl;
  final bool hasUnseen;
  final double size;
  final double ringWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: hasUnseen
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF9B6FCB), Color(0xFF5BC8AF)],
              )
            : null,
        color: hasUnseen ? null : AppColors.surfaceAlt,
      ),
      padding: EdgeInsets.all(ringWidth),
      child: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.backgroundBase,
        ),
        padding: const EdgeInsets.all(2.5),
        child: CircleAvatar(
          radius: (size - ringWidth * 2 - 5) / 2,
          backgroundColor: AppColors.surfaceAlt,
          backgroundImage: avatarUrl != null && avatarUrl!.isNotEmpty
              ? CachedNetworkImageProvider(avatarUrl!)
              : null,
          child: avatarUrl == null || avatarUrl!.isEmpty
              ? const Icon(
                  Icons.person_rounded,
                  color: Color(0xFF6E6E78),
                  size: 26,
                )
              : null,
        ),
      ),
    );
  }
}
