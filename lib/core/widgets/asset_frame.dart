import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';

/// Marco oscuro para assets con fondo opaco (PNG sin canal alfa).
///
/// Los assets de `assets/assets/` traen fondo negro; este marco los presenta
/// dentro de un tile oscuro redondeado con borde sutil y resplandor de marca,
/// manteniendo la identidad Kyubi en ambos temas (claro y oscuro).
class AssetFrame extends StatelessWidget {
  const AssetFrame({
    super.key,
    required this.asset,
    this.width = 200,
    this.height = 134,
    this.borderRadius = AppDimens.radiusMd,
  });

  final String asset;
  final double width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isMagenta = scheme.primary.toARGB32() == 0xFFD100D1 ||
        scheme.primary.toARGB32() == 0xFFFF007F;
    final glowColor = isMagenta ? const Color(0xFFBA68C8) : scheme.primary;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.ink900,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: 0.18),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        asset,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => Icon(
          Icons.broken_image_rounded,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
