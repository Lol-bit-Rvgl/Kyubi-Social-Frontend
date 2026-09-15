import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../models/role_character.dart';
import 'widgets/role_info_modal.dart';

/// Pantalla completa de detalle de una Ficha de Rol / OC.
/// Reutiliza el contenido de [RoleInfoModal] a pantalla completa.
class RoleDetailScreen extends StatelessWidget {
  const RoleDetailScreen({super.key, required this.roleId, this.role});

  final String roleId;
  final RoleCharacter? role;

  @override
  Widget build(BuildContext context) {
    final currentRole = role;
    return Scaffold(
      backgroundColor: const Color(0xFF0D0B14),
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Bar ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Color(0xFF1E1A2B),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'Role Info',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () =>
                        context.push('/characters/create', extra: currentRole),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Color(0xFF1E1A2B),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.edit_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            Expanded(
              child: currentRole == null
                  ? _buildNotFound(context)
                  : SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: RoleInfoModal(
                        role: currentRole,
                        isCurrentRole: true,
                        onTakeRole: () => context.pop(),
                        onEditRole: () => context.push(
                          '/characters/create',
                          extra: currentRole,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotFound(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.person_off_outlined,
            size: 56,
            color: Color(0xFF5A5A6A),
          ),
          const SizedBox(height: 14),
          const Text(
            'Personaje no encontrado',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'No se pudo cargar esta ficha de rol.',
            style: TextStyle(fontSize: 13, color: Color(0xFF8A8A9A)),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => context.push('/characters/create'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Crear nuevo rol'),
          ),
        ],
      ),
    );
  }
}
