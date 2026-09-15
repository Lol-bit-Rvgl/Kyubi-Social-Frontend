import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../services/auth_controller.dart';
import 'widgets/wall_tab_section.dart';

/// Pantalla completa del muro de un usuario, reutilizando [WallTabSection]
/// que ya consume [userWallCommentsProvider] con paginación.
class UserWallDetailScreen extends ConsumerWidget {
  const UserWallDetailScreen({
    super.key,
    required this.username,
    required this.userId,
  });

  final String username;
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOwnWall =
        ref.watch(authControllerProvider).user?.username == username;
    final title = isOwnWall ? 'Mi muro' : 'Muro de @$username';

    return Scaffold(
      backgroundColor: AppColors.backgroundBase,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundBase,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back_rounded, size: 18),
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: WallTabSection(
        ownerId: userId,
        onSpecialTextTap: (text) {
          if (text.startsWith('#')) {
            context.push('/search?q=${Uri.encodeComponent(text)}');
          } else if (text.startsWith('@')) {
            final uname = text.substring(1);
            context.push('/profile/$uname');
          }
        },
      ),
    );
  }
}
