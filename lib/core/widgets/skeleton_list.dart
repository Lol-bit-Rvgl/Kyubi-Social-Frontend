import 'package:flutter/material.dart';

import '../theme/app_dimensions.dart';

/// Esqueleto de carga para listas.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.itemCount = 6});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: AppDimens.pagePadding,
      itemCount: itemCount,
      itemBuilder: (_, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppDimens.xs),
        child: Container(
          padding: AppDimens.cardPadding,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          ),
          child: Row(
            children: [
              _box(scheme, 44, 44, BoxShape.circle),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _box(scheme, 120, 12),
                    const SizedBox(height: 10),
                    _box(scheme, double.infinity, 12),
                    const SizedBox(height: 8),
                    _box(scheme, double.infinity, 12),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _box(
    ColorScheme scheme,
    double width,
    double height, [
    BoxShape shape = BoxShape.rectangle,
  ]) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: scheme.onSurface.withValues(alpha: 0.08),
        shape: shape,
        borderRadius: shape == BoxShape.circle
            ? null
            : BorderRadius.circular(AppDimens.radiusSm),
      ),
    );
  }
}
