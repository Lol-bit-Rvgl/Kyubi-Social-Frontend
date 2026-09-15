import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';

/// Muestra un toast VHS sutil en la parte superior de la pantalla.
void showVhsNotification(
  BuildContext context, {
  required String content,
  required String type,
  VoidCallback? onTap,
}) {
  final overlay = Overlay.of(context);
  late OverlayEntry entry;

  IconData getIcon() {
    switch (type) {
      case 'REACTION':
        return Icons.favorite_rounded;
      case 'COMMENT':
        return Icons.chat_bubble_rounded;
      case 'FOLLOW':
        return Icons.person_add_rounded;
      case 'MENTION':
        return Icons.alternate_email_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  String getLabel() {
    switch (type) {
      case 'REACTION':
        return 'NUEVA REACCIÓN';
      case 'COMMENT':
        return 'NUEVO COMENTARIO';
      case 'FOLLOW':
        return 'NUEVO SEGUIDOR';
      case 'MENTION':
        return 'MENCIÓN';
      default:
        return 'NOTIFICACIÓN';
    }
  }

  entry = OverlayEntry(
    builder: (_) => _VhsToastWidget(
      content: content,
      label: getLabel(),
      icon: getIcon(),
      onTap: () {
        entry.remove();
        onTap?.call();
      },
      onDismiss: () {
        if (entry.mounted) entry.remove();
      },
    ),
  );

  overlay.insert(entry);
}

class _VhsToastWidget extends StatefulWidget {
  const _VhsToastWidget({
    required this.content,
    required this.label,
    required this.icon,
    this.onTap,
    this.onDismiss,
  });

  final String content;
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;

  @override
  State<_VhsToastWidget> createState() => _VhsToastWidgetState();
}

class _VhsToastWidgetState extends State<_VhsToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppDimens.motionBase,
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, -1.2), end: Offset.zero).animate(
          CurvedAnimation(parent: _controller, curve: AppDimens.curveSnappy),
        );
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();

    Future.delayed(const Duration(seconds: 4), _dismiss);
  }

  void _dismiss() {
    if (!mounted) return;
    _controller.reverse().then((_) => widget.onDismiss?.call());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Positioned(
      top: topPadding + AppDimens.sm,
      left: AppDimens.md,
      right: AppDimens.md,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: GestureDetector(
            onTap: widget.onTap,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(AppDimens.md),
                decoration: BoxDecoration(
                  color: AppColors.ink800,
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      blurRadius: 16,
                      spreadRadius: -2,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        gradient: AppColors.brandGradient,
                        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                      ),
                      child: Icon(widget.icon, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: AppDimens.md),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.label,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.content,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
