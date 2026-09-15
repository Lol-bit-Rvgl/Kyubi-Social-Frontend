import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../models/character.dart';
import '../../../../models/role_slot.dart';
import '../../../../repositories/character_repository.dart';
import '../../../../services/auth_controller.dart';
import 'role_slots_controller.dart';

/// Detalle de una vacante de rol: muestra estado, intérprete asignado y
/// acciones según el rol del usuario:
/// - Autor del post: editar / cerrar-abrir / liberar.
/// - Visitante: postular con un personaje.
/// - Intérprete asignado: abandonar la vacante.
class RoleSlotDetailScreen extends ConsumerWidget {
  const RoleSlotDetailScreen({
    super.key,
    required this.slot,
    this.isPostAuthor = false,
  });

  final RoleSlot slot;
  final bool isPostAuthor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(roleSlotsControllerProvider(slot.postId));
    final latest = state.slots.firstWhere(
      (s) => s.id == slot.id,
      orElse: () => slot,
    );
    final meId = ref.watch(authControllerProvider).user?.id;
    final isMine =
        latest.assignedUserId != null && latest.assignedUserId == meId;
    final isBusy = state.isBusy(latest.id);
    final notifier = ref.read(
      roleSlotsControllerProvider(slot.postId).notifier,
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0D0B14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0B14),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Vacante de rol',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          if (isPostAuthor)
            IconButton(
              tooltip: 'Editar',
              icon: const Icon(
                Icons.edit_outlined,
                color: Colors.white,
                size: 20,
              ),
              onPressed: () => context.push(
                '/role-slots/editor/${slot.postId}',
                extra: latest,
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppDimens.md),
        children: [
          // ── Estado ────────────────────────────────────────────────
          _StatusChip(isOpen: latest.isOpen && !latest.isAssigned),
          const SizedBox(height: AppDimens.md),

          // ── Título y descripción ──────────────────────────────────
          Text(
            latest.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          if ((latest.description ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: AppDimens.sm),
            Text(
              latest.description!,
              style: const TextStyle(
                color: Color(0xFFC4C4D4),
                fontSize: 14,
                height: 1.45,
              ),
            ),
          ],
          if ((latest.requirements ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: AppDimens.md),
            _SectionCard(
              icon: Icons.fact_check_outlined,
              title: 'Requisitos',
              child: Text(
                latest.requirements!,
                style: const TextStyle(color: Color(0xFFC4C4D4), fontSize: 13),
              ),
            ),
          ],

          const SizedBox(height: AppDimens.md),

          // ── Intérprete asignado ───────────────────────────────────
          _SectionCard(
            icon: Icons.person_outline_rounded,
            title: 'Intérprete',
            child: latest.assignedUser == null
                ? const Text(
                    'Sín asignar',
                    style: TextStyle(color: Color(0xFF8A8A9A), fontSize: 13),
                  )
                : Row(
                    children: [
                      AppAvatar(
                        imageUrl:
                            latest.assignedCharacter?.avatarUrl ??
                            latest.assignedUser?.avatarUrl,
                        name:
                            latest.assignedCharacter?.name ??
                            latest.assignedUser?.displayName ??
                            '?',
                        radius: 20,
                      ),
                      const SizedBox(width: AppDimens.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              latest.assignedCharacter?.name ??
                                  latest.assignedUser?.displayName ??
                                  '',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            if (latest.assignedUser != null)
                              Text(
                                '@${latest.assignedUser!.username}',
                                style: const TextStyle(
                                  color: Color(0xFF8A8A9A),
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),

          const SizedBox(height: AppDimens.lg),

          // ── Acciones ─────────────────────────────────────────────
          if (isBusy)
            const Center(child: CircularProgressIndicator())
          else ...[
            if (isPostAuthor) ...[
              _ActionButton(
                label: latest.isOpen ? 'Cerrar vacante' : 'Reabrir vacante',
                icon: latest.isOpen
                    ? Icons.lock_outline_rounded
                    : Icons.lock_open_rounded,
                color: AppColors.accentTeal,
                onTap: () =>
                    notifier.updateSlot(latest.id, isOpen: !latest.isOpen),
              ),
              if (latest.isAssigned) ...[
                const SizedBox(height: AppDimens.sm),
                _ActionButton(
                  label: 'Liberar vacante',
                  icon: Icons.person_remove_alt_1_outlined,
                  color: AppColors.warning,
                  onTap: () => _confirm(
                    context,
                    message:
                        '¿Liberar la vacante? Quedará disponible de nuevo.',
                    onConfirm: () => notifier.leaveSlot(latest.id),
                  ),
                ),
              ],
            ] else if (latest.isOpen && !latest.isAssigned) ...[
              _ActionButton(
                label: 'Postular personaje',
                icon: Icons.bolt_rounded,
                color: AppColors.accentCrimson,
                onTap: () => _pickCharacter(context, ref, notifier, latest),
              ),
            ] else if (isMine) ...[
              _ActionButton(
                label: 'Abandonar rol',
                icon: Icons.logout_rounded,
                color: AppColors.danger,
                onTap: () => _confirm(
                  context,
                  message: '¿Abandonar este rol? La vacante volverá a abrirse.',
                  onConfirm: () => notifier.leaveSlot(latest.id),
                ),
              ),
            ],
          ],

          const SizedBox(height: AppDimens.lg),
        ],
      ),
    );
  }

  Future<void> _pickCharacter(
    BuildContext context,
    WidgetRef ref,
    RoleSlotsNotifier notifier,
    RoleSlot slot,
  ) async {
    // `null` = cancelado; Character con id vacío = "sin personaje".
    final selection = await showModalBottomSheet<Character?>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CharacterPickerSheet(),
    );
    if (selection == null || !context.mounted) return;

    final characterId = selection.id.isEmpty ? null : selection.id;
    final success = await notifier.applyToSlot(
      slot.id,
      characterId: characterId,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? 'Te postulaste a la vacante' : 'No se pudo postular',
        ),
      ),
    );
  }

  Future<void> _confirm(
    BuildContext context, {
    required String message,
    required Future<bool> Function() onConfirm,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF14141B),
        title: const Text('Confirmar', style: TextStyle(color: Colors.white)),
        content: Text(
          message,
          style: const TextStyle(color: Color(0xFFB3B3C4)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Aceptar',
              style: TextStyle(color: AppColors.accentCrimson),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) await onConfirm();
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.isOpen});

  final bool isOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: (isOpen ? AppColors.accentTeal : AppColors.danger).withValues(
          alpha: 0.15,
        ),
        borderRadius: BorderRadius.circular(AppDimens.radiusFull),
        border: Border.all(
          color: (isOpen ? AppColors.accentTeal : AppColors.danger).withValues(
            alpha: 0.4,
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOpen ? Icons.lock_open_rounded : Icons.lock_rounded,
            size: 14,
            color: isOpen ? AppColors.accentTeal : AppColors.danger,
          ),
          const SizedBox(width: 6),
          Text(
            isOpen ? 'Vacante abierta' : 'Vacante ocupada',
            style: TextStyle(
              color: isOpen ? AppColors.accentTeal : AppColors.danger,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimens.md),
      decoration: BoxDecoration(
        color: const Color(0xFF14141B),
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.accentTeal),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: color.withValues(alpha: 0.16),
          foregroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          ),
        ),
      ),
    );
  }
}

/// Selector de personajes del usuario actual para postular una vacante.
class _CharacterPickerSheet extends ConsumerWidget {
  const _CharacterPickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(authControllerProvider).user;
    final charactersFuture = ref
        .read(characterRepositoryProvider)
        .getUserCharacters(me?.id ?? '');

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF14141B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(AppDimens.md, 12, AppDimens.md, 24),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF3A3A4A),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppDimens.md),
            const Text(
              'Elige tu personaje',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppDimens.md),
            Flexible(
              child: FutureBuilder<List<Character>>(
                future: charactersFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final characters = snapshot.data ?? const [];
                  return ListView(
                    shrinkWrap: true,
                    children: [
                      ListTile(
                        leading: const Icon(
                          Icons.person_outline_rounded,
                          color: Colors.white,
                        ),
                        title: const Text(
                          'Sin personaje (participar como usuario)',
                          style: TextStyle(color: Colors.white, fontSize: 14),
                        ),
                        onTap: () => Navigator.of(
                          context,
                        ).pop(const Character(id: '', userId: '', name: '')),
                      ),
                      for (final c in characters)
                        ListTile(
                          leading: AppAvatar(
                            imageUrl: c.avatarUrl,
                            name: c.name,
                            radius: 18,
                          ),
                          title: Text(
                            c.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: (c.role ?? '').isNotEmpty
                              ? Text(
                                  c.role!,
                                  style: const TextStyle(
                                    color: Color(0xFF8A8A9A),
                                    fontSize: 12,
                                  ),
                                )
                              : null,
                          onTap: () => Navigator.of(context).pop(c),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
