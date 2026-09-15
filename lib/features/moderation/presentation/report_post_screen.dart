import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../services/providers.dart';

/// Reporte de una publicación.
class ReportPostScreen extends ConsumerStatefulWidget {
  const ReportPostScreen({super.key, required this.postId});

  final String postId;

  @override
  ConsumerState<ReportPostScreen> createState() => _ReportPostScreenState();
}

class _ReportPostScreenState extends ConsumerState<ReportPostScreen> {
  String? _reason;
  bool _sending = false;

  static const _reasons = [
    ('Spam', Icons.campaign_rounded, 'SPAM'),
    ('Contenido ofensivo', Icons.do_not_disturb_alt_rounded, 'HATE_SPEECH'),
    ('Violencia', Icons.warning_amber_rounded, 'VIOLENCE'),
    ('Contenido sexual', Icons.eighteen_mp_rounded, 'ADULT_CONTENT'),
    ('Acercamiento inapropiado', Icons.person_off_rounded, 'HARASSMENT'),
    ('Otro', Icons.flag_rounded, 'OTHER'),
  ];

  Future<void> _submit() async {
    if (_reason == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Selecciona un motivo')));
      return;
    }
    final reason = _reasons.firstWhere((r) => r.$1 == _reason).$3;
    setState(() => _sending = true);
    try {
      await ref
          .read(postRepositoryProvider)
          .reportPost(widget.postId, reason: reason);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gracias, revisaremos tu reporte')),
      );
      context.pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo enviar el reporte')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reportar publicación')),
      body: ListView(
        padding: AppDimens.pagePadding,
        children: [
          Text(
            '¿Por qué reportas esta publicación?',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppDimens.md),
          RadioGroup<String>(
            groupValue: _reason,
            onChanged: (v) => setState(() => _reason = v),
            child: Column(
              children: [
                for (final reason in _reasons)
                  RadioListTile<String>(
                    value: reason.$1,
                    title: Row(
                      children: [
                        Icon(reason.$2, size: 20, color: AppColors.primary),
                        const SizedBox(width: 10),
                        Text(reason.$1),
                      ],
                    ),
                    controlAffinity: ListTileControlAffinity.trailing,
                    contentPadding: EdgeInsets.zero,
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppDimens.lg),
          AppButton(
            label: 'Enviar reporte',
            icon: Icons.flag_rounded,
            danger: true,
            loading: _sending,
            onPressed: _submit,
          ),
          const SizedBox(height: AppDimens.sm),
          Text(
            'Los reportes son confidenciales y se revisan por moderadores.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
