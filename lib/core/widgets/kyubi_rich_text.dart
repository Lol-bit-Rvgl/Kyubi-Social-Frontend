import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Widget de texto enriquecido que procesa automáticamente:
/// - Hashtags (`#tema`)
/// - Menciones (`@usuario`)
/// - Negrita (`**texto**`)
/// - Acciones de rolplay (`*acción*`)
/// - Diálogo/narración (`«texto»`)
class KyubiRichText extends StatelessWidget {
  const KyubiRichText({
    super.key,
    required this.text,
    this.style,
    this.onTap,
    this.maxLines,
    this.overflow = TextOverflow.clip,
  });

  final String text;
  final TextStyle? style;
  final void Function(String tagOrMention)? onTap;
  final int? maxLines;
  final TextOverflow overflow;

  static final RegExp _pattern = RegExp(
    r'(\#[a-zA-Z0-9_áéíóúÁÉÍÓÚñÑ]+)|(@[a-zA-Z0-9_]+)|(\*\*[^*]+\*\*)|(\*[^*]+\*)|(«[^»]*»)',
  );

  @override
  Widget build(BuildContext context) {
    final defaultStyle =
        style ??
        TextStyle(
          fontSize: 14,
          height: 1.4,
          color: Theme.of(context).colorScheme.onSurface,
        );

    final spans = <InlineSpan>[];

    text.splitMapJoin(
      _pattern,
      onMatch: (Match match) {
        final matchText = match[0]!;
        if (matchText.startsWith('#')) {
          spans.add(
            TextSpan(
              text: matchText,
              style: defaultStyle.copyWith(
                color: AppColors.accentCyan,
                fontWeight: FontWeight.w600,
              ),
              recognizer: onTap != null
                  ? (TapGestureRecognizer()..onTap = () => onTap!(matchText))
                  : null,
            ),
          );
        } else if (matchText.startsWith('@')) {
          spans.add(
            TextSpan(
              text: matchText,
              style: defaultStyle.copyWith(
                color: AppColors.accentPurple,
                fontWeight: FontWeight.w700,
              ),
              recognizer: onTap != null
                  ? (TapGestureRecognizer()..onTap = () => onTap!(matchText))
                  : null,
            ),
          );
        } else if (matchText.startsWith('**') && matchText.endsWith('**')) {
          final content = matchText.substring(2, matchText.length - 2);
          spans.add(
            TextSpan(
              text: content,
              style: defaultStyle.copyWith(fontWeight: FontWeight.bold),
            ),
          );
        } else if (matchText.startsWith('*') && matchText.endsWith('*')) {
          final content = matchText.substring(1, matchText.length - 1);
          spans.add(
            TextSpan(
              text: content,
              style: defaultStyle.copyWith(
                fontStyle: FontStyle.italic,
                color: AppColors.accentCyan.withValues(alpha: 0.9),
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        } else if (matchText.startsWith('«') && matchText.endsWith('»')) {
          final content = matchText.substring(1, matchText.length - 1);
          spans.add(
            TextSpan(
              text: content,
              style: defaultStyle.copyWith(
                fontStyle: FontStyle.italic,
                color: AppColors.accentTeal.withValues(alpha: 0.85),
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        } else {
          spans.add(TextSpan(text: matchText, style: defaultStyle));
        }
        return '';
      },
      onNonMatch: (String nonMatch) {
        if (nonMatch.isNotEmpty) {
          spans.add(TextSpan(text: nonMatch, style: defaultStyle));
        }
        return '';
      },
    );

    return Text.rich(
      TextSpan(children: spans),
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}
