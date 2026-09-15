import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../services/auth_controller.dart';
import '../../../../services/providers.dart';

/// Encabezado superior fiel a la maqueta original de Kyubi / Project Z:
/// - Avatar + Nombre de usuario a la izquierda.
/// - Botón de Amigos/Comunidad y Botón de Notificaciones a la derecha en squircles oscuros.
class HeaderProfile extends ConsumerWidget {
  const HeaderProfile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final user = auth.user;
    final avatarUrl = user?.effectiveAvatarUrl;
    final displayName = user?.displayName ?? 'Lolbit';
    final unreadCount = ref.watch(unreadCountProvider);

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppDimens.md, 14, AppDimens.md, 6),
        child: Row(
          children: [
            // ── Avatar con punto de estado y tap para abrir Drawer / Perfil ──
            GestureDetector(
              onTap: () => Scaffold.of(context).openDrawer(),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF1E1E2A),
                    ),
                    padding: const EdgeInsets.all(1.5),
                    child: AppAvatar(
                      imageUrl: avatarUrl,
                      name: displayName,
                      radius: 19,
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: user?.isOnline ?? true
                            ? AppColors.success
                            : const Color(0xFF7A7A8A),
                        border: Border.all(
                          color: AppColors.backgroundBase,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // ── Nombre de usuario en blanco ──
            Expanded(
              child: Text(
                displayName,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // ── Botón 1: Amigos / Comunidad ──
            GestureDetector(
              onTap: () => context.push('/circles'),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF14141B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF22222E),
                    width: 0.8,
                  ),
                ),
                child: const Icon(
                  Icons.group_rounded,
                  size: 19,
                  color: Color(0xFF9E9EA8),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // ── Botón 2: Notificaciones (Campana) con badge ──
            GestureDetector(
              onTap: () {
                context.push('/app/notifications');
                ref.read(unreadCountProvider.notifier).clear();
              },
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF14141B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF22222E),
                    width: 0.8,
                  ),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    const Icon(
                      Icons.notifications_none_rounded,
                      size: 20,
                      color: Color(0xFF9E9EA8),
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.accentCrimson,
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
