import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../models/character.dart';

/// Tarjeta squircle de Personaje / OC en el estante de perfil.
class OcCardWidget extends StatelessWidget {
  const OcCardWidget({super.key, required this.character});

  final Character character;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showCharacterDetail(context, character),
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF14141B),
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
          border: Border.all(color: const Color(0xFF22222E), width: 0.8),
          boxShadow: [
            BoxShadow(
              color: AppColors.accentCyan.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [AppColors.accentCyan, AppColors.accentPurple],
                ),
              ),
              padding: const EdgeInsets.all(1.5),
              child: AppAvatar(
                imageUrl: character.avatarUrl,
                name: character.name,
                radius: 20,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    character.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    character.species ?? character.role ?? 'OC',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accentCyan,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCharacterDetail(BuildContext context, Character char) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF14141B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (_, scrollController) {
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(
                AppDimens.md,
                12,
                AppDimens.md,
                32,
              ),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0x33FFFFFF),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [AppColors.accentCrimson, AppColors.accentCyan],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accentCrimson.withValues(alpha: 0.3),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(3),
                    child: AppAvatar(
                      imageUrl: char.avatarUrl,
                      name: char.name,
                      radius: 40,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    char.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (char.species != null || char.role != null) ...[
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      '${char.species ?? ''}${char.species != null && char.role != null ? ' · ' : ''}${char.role ?? ''}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accentCyan,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                _buildInfoSection(
                  'Biografía & Lore',
                  char.bio ?? char.background ?? 'Sin lore especificado.',
                ),
                if (char.personality != null &&
                    char.personality!.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _buildInfoSection(
                    'Personalidad & Alineamiento',
                    '${char.personality!} (${char.alignment ?? "Neutral"})',
                  ),
                ],
                if (char.abilities.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Text(
                    'Habilidades',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: char.abilities.map((ability) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accentCrimson.withValues(
                            alpha: 0.15,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.accentCrimson.withValues(
                              alpha: 0.4,
                            ),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          '⚡ $ability',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildInfoSection(String title, String content) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2A),
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        border: Border.all(color: const Color(0xFF2E2E3E), width: 0.8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF9A9AAA),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            content,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.4,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
