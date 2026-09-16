import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/liquid_glass_container.dart';
import '../../../../models/badge.dart';
import '../../../../models/user.dart';

/// Modal canónico de insignias, compartido por el perfil propio y el visitado.
///
/// Título estándar "🥇 Insignias y Medallas". Itera sobre
/// [BadgeCatalog.allBadges] y marca cada insignia como desbloqueada cuando
/// su [BadgeItem.id] está en `user.badges`. Si el usuario es VIP se anexa
/// la insignia dinámica [BadgeCatalog.vip].
class BadgesModalSheet extends StatelessWidget {
  const BadgesModalSheet({super.key, required this.user});

  final User user;

  /// Presenta el bottom sheet unificado de insignias.
  static Future<void> show(BuildContext context, User user) {
    HapticFeedback.selectionClick();
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1E1B2E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
          child: BadgesModalSheet(user: user),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ownedBadges = user.badges;
    final items = [
      ...BadgeCatalog.allBadges,
      if (user.isVip) BadgeCatalog.vip,
    ];

    return Column(
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
        const SizedBox(height: 14),
        const Row(
          children: [
            Icon(
              Icons.military_tech_rounded,
              color: Color(0xFFFFD600),
              size: 22,
            ),
            SizedBox(width: 8),
            Text(
              '🥇 Insignias y Medallas',
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ...items.map((badge) {
          final owned = ownedBadges.contains(badge.id);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: LiquidGlassContainer(
              borderRadius: 12,
              blur: 8,
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Opacity(
                    opacity: owned ? 1 : 0.3,
                    child: Text(
                      badge.icon,
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          badge.title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: owned
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.45),
                          ),
                        ),
                        Text(
                          badge.description,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (!owned) ...[
                          const SizedBox(height: 3),
                          const Text(
                            'Bloqueada',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                              color: Color(0xFF9E9EA8),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (owned)
                    const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.accentCyan,
                      size: 18,
                    )
                  else
                    const Icon(
                      Icons.lock_outline_rounded,
                      color: Color(0xFF6E6E78),
                      size: 18,
                    ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
