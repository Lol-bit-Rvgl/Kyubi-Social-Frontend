import 'package:flutter/material.dart';

import '../theme/app_dimensions.dart';
import 'app_button.dart';
import 'asset_frame.dart';
import 'kyubi_blob.dart';
import 'liquid_glass_button.dart';

/// Estado de error con reintento, en lenguaje visual Kyubi.
class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.message,
    this.onRetry,
    this.title = 'Algo salió mal',
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _FadeUp(
      child: Center(
        child: Padding(
          padding: AppDimens.pagePadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _BlobIcon(
                size: 104,
                icon: Icons.cloud_off_rounded,
                iconColor: scheme.primary,
                blobColor: scheme.error.withValues(alpha: 0.10),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 20),
                AppButton(
                  label: 'Reintentar',
                  icon: Icons.refresh_rounded,
                  onPressed: onRetry,
                  isOutlined: true,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Estado vacío con icono y mensaje, en lenguaje visual Kyubi.
///
/// Si se provee [imageWidget], se renderiza centrado sobre un aura/glow
/// circular difuminada según el color primario del usuario o morado cósmico.
/// Si se provee [illustration], se muestra ese asset enmarcado en [AssetFrame].
class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    this.icon = Icons.info_outline_rounded,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.actionWidget,
    this.illustration,
    this.illustrationWidth = 200,
    this.illustrationHeight = 134,
    this.imageWidget,
    this.glowColor,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? actionWidget;

  /// Asset de ilustración opcional (estados vacíos ilustrados).
  final String? illustration;
  final double illustrationWidth;
  final double illustrationHeight;

  /// Widget de imagen oficial o personalizado (ej. Image.asset con 90x90).
  final Widget? imageWidget;

  /// Color del resplandor/aura difuminada.
  final Color? glowColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = scheme.primary;

    // Detectar si el color primario es magenta/fucsia legado (#D100D1, #FF007F o similar)
    // para sustituirlo por el morado cósmico (#BA68C8 / #7B1FA2).
    final isMagenta = primaryColor.toARGB32() == 0xFFD100D1 ||
        primaryColor.toARGB32() == 0xFFFF007F ||
        (primaryColor.r > 0.75 && primaryColor.g < 0.15 && primaryColor.b > 0.65);

    final effectivePrimary = isMagenta ? const Color(0xFFBA68C8) : primaryColor;
    final effectiveGlowColor =
        glowColor ?? effectivePrimary.withValues(alpha: isDark ? 0.18 : 0.12);

    final illustration = this.illustration;
    final imageWidget = this.imageWidget;

    return _FadeUp(
      child: Center(
        child: Padding(
          padding: AppDimens.pagePadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (imageWidget != null)
                SizedBox(
                  width: 110,
                  height: 110,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Aura / Glow difuminada detrás del asset oficial
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: effectiveGlowColor,
                          boxShadow: [
                            BoxShadow(
                              color: effectiveGlowColor,
                              blurRadius: 32,
                              spreadRadius: 8,
                            ),
                          ],
                        ),
                      ),
                      imageWidget,
                    ],
                  ),
                )
              else if (illustration != null)
                AssetFrame(
                  asset: illustration,
                  width: illustrationWidth,
                  height: illustrationHeight,
                )
              else
                _BlobIcon(
                  size: 112,
                  icon: icon,
                  iconColor: effectivePrimary,
                  blobColor: effectiveGlowColor,
                ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              if (message != null) ...[
                const SizedBox(height: 8),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (actionWidget != null) ...[
                const SizedBox(height: 20),
                actionWidget!,
              ] else if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 20),
                LiquidGlassButton(
                  label: actionLabel!,
                  icon: Icons.arrow_forward_rounded,
                  borderRadius: 18.0,
                  height: 46,
                  customGradient: isMagenta
                      ? const LinearGradient(
                          colors: [Color(0xFFBA68C8), Color(0xFF7B1FA2)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : LinearGradient(
                          colors: [
                            scheme.primary,
                            scheme.secondary,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  borderColor:
                      isMagenta ? const Color(0xFFBA68C8) : scheme.primary,
                  onTap: onAction,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Blob orgánico con cola que envuelve el icono de un estado.
class _BlobIcon extends StatelessWidget {
  const _BlobIcon({
    required this.size,
    required this.icon,
    required this.iconColor,
    required this.blobColor,
  });

  final double size;
  final IconData icon;
  final Color iconColor;
  final Color blobColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          KyubiBlob(size: size, color: blobColor, tail: true),
          Icon(icon, size: size * 0.42, color: iconColor),
        ],
      ),
    );
  }
}

/// Aparición suave: desvanecido con ligero desplazamiento vertical.
class _FadeUp extends StatelessWidget {
  const _FadeUp({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppDimens.motionBase,
      curve: AppDimens.curveStandard,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - value)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
