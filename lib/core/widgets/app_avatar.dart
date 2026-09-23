import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';

/// Avatar con soporte de URL, iniciales y estado online.
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    this.imageUrl,
    required this.name,
    this.radius = AppDimens.avatarMd / 2,
    this.showOnline = false,
    this.isOnline = false,
    this.borderColor,
    this.onTap,
    this.cacheVersion,
    this.cacheKey,
  });

  final String? imageUrl;
  final String name;
  final double radius;
  final bool showOnline;
  final bool isOnline;
  final Color? borderColor;
  final VoidCallback? onTap;
  final int? cacheVersion;
  final String? cacheKey;

  String get _initial {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length > 1) {
      return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
    }
    return trimmed[0].toUpperCase();
  }

  /// Añade parámetros de cache-buster a la URL preservando query existente.
  /// Se evita el caso roto `$url?v=..?t=..` (doble `?`) al reusar `Uri`.
  String _cacheBusted(String url) {
    if (cacheVersion == null && cacheKey == null) return url;
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    final params = Map<String, String>.from(uri.queryParameters);
    if (cacheVersion != null) params['v'] = '$cacheVersion';
    if (cacheKey != null) params['t'] = cacheKey!;
    return uri.replace(queryParameters: params).toString();
  }

  @override
  Widget build(BuildContext context) {
    final double size = radius * 2;

    final Widget avatar = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: borderColor != null
            ? Border.all(color: borderColor!, width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: size,
          height: size,
          child: imageUrl != null && imageUrl!.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: _cacheBusted(imageUrl!),
                  cacheKey: cacheKey ?? imageUrl,
                  memCacheWidth: (radius * 4).round().clamp(64, 256),
                  memCacheHeight: (radius * 4).round().clamp(64, 256),
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => _placeholder(size),
                  errorWidget: (_, _, _) => _placeholder(size),
                )
              : _placeholder(size),
        ),
      ),
    );

    final Widget core = showOnline
        ? Stack(
            clipBehavior: Clip.none,
            children: [
              avatar,
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: radius * 0.6,
                  height: radius * 0.6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isOnline
                        ? AppColors.success
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    border: Border.all(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ],
          )
        : avatar;

    final Widget interactive = onTap != null
        ? GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: core,
          )
        : core;

    return SizedBox(
      width: size,
      height: size,
      child: AspectRatio(
        aspectRatio: 1.0,
        child: interactive,
      ),
    );
  }

  Widget _placeholder(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.avatarColor(name),
      ),
      alignment: Alignment.center,
      child: Text(
        _initial,
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.8,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
