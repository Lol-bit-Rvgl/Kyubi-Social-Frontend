import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../services/providers.dart';

/// Pantalla para verificar el correo con token.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key, required this.token});

  final String token;

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  bool _working = true;
  bool _success = false;

  @override
  void initState() {
    super.initState();
    _verify();
  }

  Future<void> _verify() async {
    try {
      await ref.read(authRepositoryProvider).verifyEmail(widget.token);
      _success = true;
    } catch (_) {
      _success = false;
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Verificar correo')),
      body: Center(
        child: Padding(
          padding: AppDimens.pagePadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_working)
                const CircularProgressIndicator()
              else ...[
                Icon(
                  _success
                      ? Icons.verified_rounded
                      : Icons.error_outline_rounded,
                  size: 72,
                  color: _success
                      ? Theme.of(context).colorScheme.primary
                      : scheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  _success ? 'Correo verificado' : 'No se pudo verificar',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  _success
                      ? 'Tu cuenta está verificada. Ya puedes usar Kyubi.'
                      : 'El enlace no es válido o ha expirado.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                AppButton(
                  label: 'Continuar',
                  onPressed: () => context.go('/app/feed'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
