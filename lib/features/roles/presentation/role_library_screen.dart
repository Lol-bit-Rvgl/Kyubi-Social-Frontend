import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/kyubi_shimmer.dart';
import '../../../../core/widgets/liquid_glass_container.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../models/character.dart';
import '../../../../models/role_character.dart';
import '../../../../services/auth_controller.dart';

/// Pantalla y Modal de Biblioteca de Roles / Fichas de Personaje (Estilo Project Z).
class RoleLibraryScreen extends ConsumerWidget {
  const RoleLibraryScreen({
    super.key,
    this.isPicker = false,
  });

  /// Si es true, actúa como selector retornando la ficha elegida al hacer tap.
  final bool isPicker;

  /// Abre un modal tipo bottom sheet para seleccionar una ficha de personaje al instante.
  static Future<RoleCharacter?> showPicker(BuildContext context) {
    return showModalBottomSheet<RoleCharacter>(
      context: context,
      backgroundColor: const Color(0xFF13101E),
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const FractionallySizedBox(
        heightFactor: 0.85,
        child: RoleLibraryScreen(isPicker: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final charactersAsync = ref.watch(myCharactersProvider);
    final user = ref.watch(authControllerProvider).user;

    return Scaffold(
      backgroundColor: isPicker ? Colors.transparent : AppColors.obsidianBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          isPicker ? 'Seleccionar Personaje' : 'Mis Fichas de Rol',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Nueva Ficha',
            icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.accentCyan),
            onPressed: () async {
              await context.push('/characters/create');
              ref.invalidate(myCharactersProvider);
            },
          ),
        ],
      ),
      body: charactersAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accentCyan),
        ),
        error: (err, _) => ErrorView(
          title: 'Error al cargar fichas',
          message: err.toString(),
          onRetry: () => ref.invalidate(myCharactersProvider),
        ),
        data: (characters) {
          if (characters.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF1E1A2E),
                        border: Border.all(
                          color: const Color(0xFFFFD600).withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.theater_comedy_rounded,
                        color: Color(0xFFFFD600),
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Aún no tienes fichas de rol',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Crea tu primer personaje (OC) para participar en escenarios de roleplay con una identidad personalizada.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Crear Ficha de Personaje'),
                      onPressed: () async {
                        await context.push('/characters/create');
                        ref.invalidate(myCharactersProvider);
                      },
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(myCharactersProvider),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(AppDimens.md, 8, AppDimens.md, 90),
              itemCount: characters.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final character = characters[index];
                return _CharacterCard(
                  character: character,
                  isPicker: isPicker,
                  onSelect: () {
                    final role = character.toRoleCharacter(
                      currentUserId: user?.id,
                      currentUsername: user?.displayName.isNotEmpty == true
                          ? user!.displayName
                          : user?.username,
                    );
                    Navigator.of(context).pop(role);
                  },
                  onEdit: () async {
                    await context.push(
                      '/characters/create',
                      extra: character.toRoleCharacter(
                        currentUserId: user?.id,
                        currentUsername: user?.displayName,
                      ),
                    );
                    ref.invalidate(myCharactersProvider);
                  },
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Crear Ficha', style: TextStyle(fontWeight: FontWeight.w700)),
        onPressed: () async {
          await context.push('/characters/create');
          ref.invalidate(myCharactersProvider);
        },
      ),
    );
  }
}

class _CharacterCard extends StatelessWidget {
  const _CharacterCard({
    required this.character,
    required this.isPicker,
    required this.onSelect,
    required this.onEdit,
  });

  final Character character;
  final bool isPicker;
  final VoidCallback onSelect;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isPicker ? onSelect : onEdit,
      child: LiquidGlassContainer(
        borderRadius: 16,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Avatar con resplandor cósmico
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFFFD600).withValues(alpha: 0.7),
                  width: 1.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFD600).withValues(alpha: 0.2),
                    blurRadius: 8,
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: character.avatarUrl != null && character.avatarUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: character.avatarUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => const KyubiShimmer(),
                      errorWidget: (_, _, _) => AppAvatar(name: character.name, radius: 27),
                    )
                  : AppAvatar(name: character.name, radius: 27),
            ),
            const SizedBox(width: 14),

            // Nombre y detalles del personaje
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          character.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD600).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: const Color(0xFFFFD600).withValues(alpha: 0.5),
                            width: 0.7,
                          ),
                        ),
                        child: const Text(
                          'OC',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFFFD600),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    character.role != null && character.role!.isNotEmpty
                        ? character.role!
                        : (character.bio != null && character.bio!.isNotEmpty
                            ? character.bio!
                            : 'Personaje de Rol'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // Botón de acción
            if (isPicker)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E1A2E),
                  foregroundColor: AppColors.accentCyan,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: AppColors.accentCyan, width: 0.8),
                  ),
                ),
                onPressed: onSelect,
                child: const Text('Elegir', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              )
            else
              IconButton(
                icon: const Icon(Icons.edit_rounded, size: 18, color: AppColors.textSecondary),
                onPressed: onEdit,
              ),
          ],
        ),
      ),
    );
  }
}
