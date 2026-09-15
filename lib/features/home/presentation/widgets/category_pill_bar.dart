import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_dimensions.dart';

/// Barra horizontal de categorías tipo píldora.
///
/// [selected] es la clave del mapa [AppConstants.feedCategories].
/// Estado activo: fondo blanco + texto negro.
/// Estado inactivo: fondo transparente + borde sutil + texto secundario.
class CategoryPillBar extends StatelessWidget {
  const CategoryPillBar({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 44,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg),
          itemCount: AppConstants.feedCategories.length,
          separatorBuilder: (_, _) => const SizedBox(width: AppDimens.xs),
          itemBuilder: (context, index) {
            final entry = AppConstants.feedCategories.entries.elementAt(index);
            return _Pill(
              label: entry.value,
              isActive: selected == entry.key,
              onTap: () => onSelected(entry.key),
            );
          },
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final primaryColor = scheme.primary;
    final secondaryColor = scheme.secondary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDimens.motionBase,
        curve: AppDimens.curveStandard,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          gradient: isActive
              ? LinearGradient(
                  colors: [primaryColor, secondaryColor],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : null,
          color: isActive ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(AppDimens.radiusFull),
          border: Border.all(
            color: isActive
                ? primaryColor.withValues(alpha: 0.4)
                : scheme.outlineVariant.withValues(alpha: 0.5),
            width: 1.2,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: AnimatedDefaultTextStyle(
          duration: AppDimens.motionFast,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            color: isActive ? Colors.white : scheme.onSurfaceVariant,
          ),
          child: Text(label),
        ),
      ),
    );
  }
}
