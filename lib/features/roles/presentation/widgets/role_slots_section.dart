import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../models/role_slot.dart';
import '../role_slots_controller.dart';

/// Sección inline dentro del detalle de una publicación que muestra las
/// vacantes de rol (RoleSlots) del post y permite al autor gestionarlas.
class RoleSlotsSection extends ConsumerWidget {
  const RoleSlotsSection({
    super.key,
    required this.postId,
    required this.isPostAuthor,
  });

  final String postId;
  final bool isPostAuthor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(roleSlotsControllerProvider(postId));

    // Si no hay vacantes y el usuario no es el autor, no mostramos nada.
    if (!isPostAuthor && !state.loading && state.slots.isEmpty) {
      return const SizedBox.shrink();
    }
    if (state.loading && !isPostAuthor) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimens.md),
      decoration: BoxDecoration(
        color: const Color(0xFF14141B),
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        border: Border.all(color: const Color(0xFF22222E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.theaters_rounded,
                size: 16,
                color: AppColors.accentTeal,
              ),
              const SizedBox(width: 6),
              Text(
                'Vacantes de rol (${state.slots.length})',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              if (isPostAuthor)
                GestureDetector(
                  onTap: () => context.push('/role-slots/editor/$postId'),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFF1E1E2B),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          if (state.loading) ...[
            const SizedBox(height: AppDimens.sm),
            const Center(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ] else if (state.slots.isEmpty) ...[
            const SizedBox(height: AppDimens.sm),
            Text(
              isPostAuthor
                  ? 'Todavía no hay vacantes. Añade una para invitar a otros a participar.'
                  : 'No hay vacantes abiertas en esta publicación.',
              style: const TextStyle(color: Color(0xFF8A8A9A), fontSize: 12),
            ),
          ] else ...[
            const SizedBox(height: AppDimens.sm),
            for (final slot in state.slots)
              _SlotRow(
                slot: slot,
                onTap: () => context.push(
                  '/role-slots/${slot.id}?author=${isPostAuthor ? 1 : 0}',
                  extra: slot,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _SlotRow extends ConsumerWidget {
  const _SlotRow({required this.slot, required this.onTap});

  final RoleSlot slot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = slot.isOpen && !slot.isAssigned;
    return InkWell(
      borderRadius: BorderRadius.circular(AppDimens.radiusSm),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            AppAvatar(
              imageUrl:
                  slot.assignedCharacter?.avatarUrl ??
                  slot.assignedUser?.avatarUrl,
              name:
                  slot.assignedCharacter?.name ??
                  slot.assignedUser?.displayName ??
                  slot.title,
              radius: 18,
            ),
            const SizedBox(width: AppDimens.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    slot.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    open
                        ? 'Disponible'
                        : (slot.assignedUser != null
                              ? 'Intérprete: ${slot.assignedUser!.displayName ?? slot.assignedUser!.username}'
                              : 'No disponible'),
                    style: TextStyle(
                      color: open
                          ? AppColors.accentTeal
                          : const Color(0xFF8A8A9A),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              open ? Icons.add_circle_outline_rounded : Icons.check_circle,
              size: 18,
              color: open ? AppColors.accentTeal : const Color(0xFF8A8A9A),
            ),
          ],
        ),
      ),
    );
  }
}
