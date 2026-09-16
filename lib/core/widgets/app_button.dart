import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_dimensions.dart';

/// Botón primario con estado de carga.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.icon,
    this.isOutlined = false,
    this.danger = false,
    this.backgroundColor,
    this.foregroundColor,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final bool isOutlined;
  final bool danger;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = backgroundColor ?? (danger ? scheme.error : scheme.primary);
    final isLightColor = color.computeLuminance() > 0.5;
    final defaultContentColor =
        isLightColor ? const Color(0xFF0D0A14) : Colors.white;
    final contentColor =
        foregroundColor ?? (isOutlined ? color : defaultContentColor);

    final child = loading
        ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: contentColor,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: contentColor),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: contentColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          );

    if (isOutlined) {
      return OutlinedButton(
        onPressed: loading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: contentColor,
          side: BorderSide(color: danger ? color : scheme.outline),
        ),
        child: child,
      );
    }

    return FilledButton(
      // Gamefeel: vibración ligera al pulsar el botón primario de acción.
      onPressed: loading
          ? null
          : () {
              HapticFeedback.lightImpact();
              onPressed?.call();
            },
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: contentColor,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.xl,
          vertical: AppDimens.md,
        ),
      ),
      child: child,
    );
  }
}

/// Cargador circular centrado con mensaje opcional.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
