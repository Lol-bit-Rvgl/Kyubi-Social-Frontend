import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../models/room_mode.dart';

/// Selector de modos interactivos de la sala (Voice Chat, Roleplay, Screening).
///
/// Solo el Admin/Co-Admin puede activar o alternar los modos; los miembros
/// comunes únicamente los ven (bloqueados con candado).
class RoomModeSelectorSheet extends StatelessWidget {
  const RoomModeSelectorSheet({
    super.key,
    required this.current,
    required this.onSelect,
    required this.canManage,
  });

  final RoomMode current;
  final ValueChanged<RoomMode> onSelect;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF14111F),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          const SizedBox(height: 16),
          const Text(
            'Modos de la sala',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            canManage
                ? 'Activa o cambia de modo para desplegar su stage superior.'
                : 'Solo el Admin/Co-Admin puede activar o cambiar los modos.',
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 18),

          _modeOption(
            context,
            emoji: '🎙️',
            title: 'Voice Chat',
            subtitle: 'Chat de voz en vivo del grupo',
            mode: RoomMode.voice,
          ),
          const SizedBox(height: 10),
          _modeOption(
            context,
            iconWidget: Image.asset(
              AppAssets.iconRoleplay,
              width: 22,
              height: 22,
              fit: BoxFit.contain,
            ),
            title: 'Roleplay',
            subtitle: 'Stage de rol con personajes',
            mode: RoomMode.roleplay,
          ),
          const SizedBox(height: 10),
          _modeOption(
            context,
            emoji: '🎬',
            title: 'Screening Room',
            subtitle: 'Ver contenido en pantalla',
            mode: RoomMode.screening,
          ),

          if (current != RoomMode.none) ...[
            const SizedBox(height: 18),
            const Divider(color: Color(0xFF2E2744), height: 1),
            const SizedBox(height: 14),
            // Apagar el modo actual
            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton.icon(
                onPressed: canManage ? () => onSelect(RoomMode.none) : null,
                icon: const Icon(Icons.power_settings_new_rounded, size: 18),
                label: const Text('Apagar modo actual'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accentCrimson,
                  side: BorderSide(
                    color: AppColors.accentCrimson.withValues(alpha: 0.5),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1E1A2E),
                foregroundColor: Colors.white70,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Cerrar'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeOption(
    BuildContext context, {
    String? emoji,
    Widget? iconWidget,
    required String title,
    required String subtitle,
    required RoomMode mode,
  }) {
    final isActive = current == mode;
    final canTap = canManage;

    return GestureDetector(
      onTap: () {
        if (!canTap) return;
        HapticFeedback.selectionClick();
        onSelect(mode);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.accentCyan.withValues(alpha: 0.10)
              : const Color(0xFF181428),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? AppColors.accentCyan : const Color(0xFF2C2544),
            width: isActive ? 1.2 : 0.8,
          ),
        ),
        child: Row(
          children: [
            if (iconWidget != null)
              SizedBox(
                width: 26,
                height: 26,
                child: Center(child: iconWidget),
              )
            else
              Text(emoji ?? '', style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isActive)
              const Icon(
                Icons.check_circle_rounded,
                size: 20,
                color: AppColors.accentCyan,
              )
            else if (!canTap)
              const Icon(
                Icons.lock_rounded,
                size: 16,
                color: Color(0xFF5A5A70),
              )
            else
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: Color(0xFF5A5A70),
              ),
          ],
        ),
      ),
    );
  }
}
