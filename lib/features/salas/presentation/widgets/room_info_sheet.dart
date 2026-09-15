import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../models/room.dart';

/// Hoja modal inferior con información y reglas de una sala en vivo.
class RoomInfoSheet extends StatelessWidget {
  const RoomInfoSheet({
    super.key,
    this.room,
    this.canEdit = false,
    this.onEditTap,
  });

  final Room? room;
  final bool canEdit;
  final VoidCallback? onEditTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF13101E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Barra de agarre ──
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

            // ── Título y Botón Editar (Solo Admin / Co-Admin) ──
            Row(
              children: [
                const Text(
                  'Info de la sala',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                if (canEdit)
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      onEditTap?.call();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accentCrimson.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.accentCrimson,
                          width: 0.8,
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.edit_note_rounded,
                            color: AppColors.accentCrimson,
                            size: 16,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Editar Sala',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.accentCrimson,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),

            if (room == null) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'Cargando información de la sala…',
                    style: TextStyle(color: Color(0xFF8A8A9A)),
                  ),
                ),
              ),
            ] else ...[
              _infoCard(
                icon: Icons.theater_comedy_rounded,
                iconColor: AppColors.accentCyan,
                label: 'Nombre',
                value: room!.name,
              ),
              const SizedBox(height: 10),
              _infoCard(
                icon: Icons.person_rounded,
                iconColor: AppColors.accentTeal,
                label: 'Host',
                value: room!.host.displayName.isNotEmpty
                    ? room!.host.displayName
                    : room!.host.username,
              ),
              const SizedBox(height: 10),
              _infoCard(
                icon: Icons.lock_rounded,
                iconColor: AppColors.accentPurple,
                label: 'Acceso',
                value: room!.access == RoomAccess.private
                    ? 'Privada'
                    : 'Pública',
              ),
              const SizedBox(height: 10),
              _infoCard(
                icon: Icons.fiber_manual_record_rounded,
                iconColor: room!.status == RoomStatus.active
                    ? AppColors.success
                    : const Color(0xFF6A6A7A),
                label: 'Estado',
                value: room!.status == RoomStatus.active
                    ? 'En vivo'
                    : 'Finalizada',
              ),
              const SizedBox(height: 10),
              _infoCard(
                icon: Icons.people_alt_rounded,
                iconColor: const Color(0xFF9E9EA8),
                label: 'Participantes',
                value:
                    '${room!.participantCount > 0 ? room!.participantCount : room!.participants.length}',
              ),
              if (room!.tags.isNotEmpty) ...[
                const SizedBox(height: 10),
                _infoCard(
                  icon: Icons.sell_rounded,
                  iconColor: AppColors.accentCrimson,
                  label: 'Etiquetas',
                  value: room!.tags.join(', '),
                ),
              ],
              if (room!.description != null &&
                  room!.description!.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Descripción',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF8A8A9A),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  room!.description!,
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.35,
                    color: Colors.white,
                  ),
                ),
              ],
            ],

            // ── Acciones de Compartir y Copiar Enlace ──
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.accentCyan,
                      side: const BorderSide(color: AppColors.accentCyan, width: 0.8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: const Icon(Icons.link_rounded, size: 18),
                    label: const Text('Copiar enlace', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    onPressed: () {
                      final id = room?.id ?? '';
                      if (id.isEmpty) return;
                      Clipboard.setData(ClipboardData(text: 'https://kyubi.app/salas/$id'));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('¡Enlace de la sala copiado al portapapeles!'),
                          behavior: SnackBarBehavior.floating,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E1932),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: Color(0xFF352C52), width: 0.8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: const Icon(Icons.share_rounded, size: 18, color: Color(0xFFA594F9)),
                    label: const Text('Compartir', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    onPressed: () {
                      final id = room?.id ?? '';
                      if (id.isEmpty) return;
                      final name = room?.name ?? 'esta sala';
                      Share.share('¡Únete a $name en Kyubi!\nhttps://kyubi.app/salas/$id', subject: 'Únete a mi sala en Kyubi');
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),
            const Divider(color: Color(0xFF2E2744), height: 1),
            const SizedBox(height: 16),

            // ── Reglas de la sala ──
            const Text(
              'Reglas de la sala',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            if (room?.rules != null && room!.rules.isNotEmpty) ...[
              for (var i = 0; i < room!.rules.length; i++)
                _ruleRow('${i + 1}', room!.rules[i]),
            ] else if (room != null) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'Sin reglas definidas para esta sala',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF7A7A8E),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ] else ...[
              _ruleRow('1', 'Mantén el respeto y el ambiente de rol.'),
              _ruleRow('2', 'No compartas información personal de otros.'),
              _ruleRow('3', 'Sigue el lore y el turno de cada personaje.'),
              _ruleRow('4', 'El host puede cerrar la sala en cualquier momento.'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF181428),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2C2544), width: 0.8),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 17, color: iconColor),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF8A8A9A),
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
      ),
    );
  }

  Widget _ruleRow(String number, String rule) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.accentCrimson.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.accentCrimson,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              rule,
              style: const TextStyle(
                fontSize: 13,
                height: 1.3,
                color: Color(0xFFC8C8D8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
