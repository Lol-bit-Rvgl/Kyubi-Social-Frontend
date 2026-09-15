import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/hexagon_avatar.dart';
import '../../../../models/role_character.dart';

/// Modal inferior de Información de Rol y Adopción (Ref: Screenshot_20260726_200519_Gallery.jpg).
class RoleInfoModal extends StatelessWidget {
  const RoleInfoModal({
    super.key,
    required this.role,
    required this.onTakeRole,
    this.onEditRole,
    this.onDeleteRole,
    this.isCurrentRole = false,
    this.isOccupied = false,
    this.occupiedByUsername,
  });

  final RoleCharacter role;
  final VoidCallback? onTakeRole;
  final VoidCallback? onEditRole;
  final VoidCallback? onDeleteRole;
  final bool isCurrentRole;
  final bool isOccupied;
  final String? occupiedByUsername;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF100E1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Barra de agarre
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Título
          const Text(
            'Role Info',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),

          // ── Tarjeta Central con Avatar Hexagonal y Destellos ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            decoration: BoxDecoration(
              color: const Color(0xFF171424),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF262038), width: 0.8),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Destellos visuales
                Positioned(
                  top: 10,
                  left: 20,
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: 16,
                    color: role.color.withValues(alpha: 0.7),
                  ),
                ),
                Positioned(
                  top: 40,
                  right: 30,
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: 12,
                    color: role.color.withValues(alpha: 0.5),
                  ),
                ),
                if (onEditRole != null || onDeleteRole != null)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.more_horiz_rounded,
                        color: Colors.white70,
                      ),
                      color: const Color(0xFF1E1A2E),
                      onSelected: (value) {
                        if (value == 'edit' && onEditRole != null) {
                          onEditRole!();
                        } else if (value == 'delete' && onDeleteRole != null) {
                          onDeleteRole!();
                        }
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(
                                Icons.edit_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Edit Role',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline_rounded,
                                size: 16,
                                color: AppColors.danger,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Delete',
                                style: TextStyle(color: AppColors.danger),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                Column(
                  children: [
                    // Avatar Hexagonal
                    HexagonAvatar(
                      size: 80,
                      imageUrl: role.avatarUrl,
                      borderColor: role.color,
                      borderWidth: 2.5,
                    ),
                    const SizedBox(height: 14),

                    // Role Name Pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: role.color,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: role.color.withValues(alpha: 0.4),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Text(
                        role.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    const Divider(color: Color(0xFF2E2744), height: 1),
                    const SizedBox(height: 16),

                    // Character Info
                    _infoRow('Name:', role.name),
                    const SizedBox(height: 8),
                    _infoRow(
                      'Language:',
                      role.tagline.isNotEmpty ? role.tagline : role.language,
                    ),
                    const SizedBox(height: 14),

                    // Description
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Description',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        role.description.isNotEmpty
                            ? role.description
                            : 'No Content Yet',
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: Colors.white,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Botón de Acción Inferior: Take / Leave / Occupied ──
          if (isOccupied && !isCurrentRole)
            // Rol ocupado por otro: mostrar quién lo tiene.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1A2E),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white24, width: 1),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.person_rounded,
                    size: 16,
                    color: Colors.white54,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Tomado por: @${occupiedByUsername ?? '?'}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: onTakeRole,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isCurrentRole
                      ? const Color(0xFF2A121E)
                      : const Color(0xFF183338),
                  side: BorderSide(
                    color: isCurrentRole
                        ? AppColors.accentCrimson.withValues(alpha: 0.6)
                        : AppColors.accentCyan,
                    width: 1,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  isCurrentRole ? 'Dejar Rol' : 'Take This Role',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isCurrentRole
                        ? AppColors.accentCrimson
                        : AppColors.accentCyan,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 76,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}
