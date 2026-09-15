import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';

class _FolderItem {
  const _FolderItem({
    required this.label,
    required this.asset,
    required this.route,
  });

  final String label;
  final String asset;
  final String route;
}

const _folders = [
  _FolderItem(label: 'Círculos', asset: AppAssets.groups, route: '/circles'),
  _FolderItem(label: 'Salas', asset: AppAssets.iconSalas, route: '/salas'),
  _FolderItem(label: 'Tienda', asset: AppAssets.store, route: '/store'),
  _FolderItem(label: 'Guardados', asset: AppAssets.coin, route: '/saved'),
];

/// Cuadrícula 2x2 de tarjetas estilo "carpeta" con contenedor inmersivo.
///
/// Cada tarjeta tiene fondo translúcido, borde de acento sutil
/// y un asset visual en lugar de iconos planos de Material.
class FeatureFolderCards extends StatelessWidget {
  const FeatureFolderCards({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg),
      sliver: SliverGrid.count(
        crossAxisCount: 2,
        mainAxisSpacing: AppDimens.md,
        crossAxisSpacing: AppDimens.md,
        childAspectRatio: 1.0,
        children: _folders.map((item) => _FolderCard(item: item)).toList(),
      ),
    );
  }
}

class _FolderCard extends StatelessWidget {
  const _FolderCard({required this.item});

  final _FolderItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => context.push(item.route),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceGlass,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
          border: Border.all(color: AppColors.borderGlow, width: 1),
          boxShadow: [
            BoxShadow(
              color: AppColors.accentCrimson.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                gradient: AppColors.crimsonGlow,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  item.asset,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => Icon(
                    Icons.category_rounded,
                    color: scheme.onSurfaceVariant,
                    size: 28,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppDimens.sm),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
