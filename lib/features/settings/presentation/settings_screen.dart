import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/widgets/kyubi_logo.dart';
import '../../../../routing/app_router.dart';
import '../../../../services/theme_controller.dart';
import '../../../../services/auth_controller.dart';

/// Configuración de la aplicación.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _confirmDeleteAccount(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Estás seguro?'),
        content: const Text(
          'Esta acción eliminará permanentemente tu cuenta, '
          'todos tus datos y publicaciones no podrán recuperarse.\n\n'
          'Escribe "ELIMINAR" para confirmar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          _DeleteConfirmButton(),
        ],
      ),
    );
    if (!context.mounted || confirmed != true) return;
    await ref.read(authControllerProvider.notifier).deleteAccount();
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF14141B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Cerrar sesión',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        content: const Text(
          '¿Estás seguro de que deseas salir de tu cuenta?',
          style: TextStyle(color: Color(0xFF9E9EA8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Color(0xFF7A7A8A)),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Salir',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(authControllerProvider.notifier).logout();
    if (context.mounted) {
      context.go('/login');
    } else {
      ref.read(routerProvider).go('/login');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeControllerProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: ListView(
        padding: AppDimens.pagePadding,
        children: [
          const _SectionHeader(title: 'Apariencia'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.brightness_6_rounded),
                  title: const Text('Tema'),
                  subtitle: Text(_themeLabel(themeMode)),
                  // Modo oscuro fijo — el selector ha sido removido
                  trailing: const Icon(
                    Icons.brightness_6_rounded,
                    color: Colors.white,
                  ),
                  enabled: false,
                ),
              ],
            ),
          ),
          const _SectionHeader(title: 'Cuenta'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.person_outline_rounded),
                  title: const Text('Editar perfil'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/edit-profile'),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: Icon(Icons.logout_rounded, color: scheme.error),
                  title: Text(
                    'Cerrar sesión',
                    style: TextStyle(color: scheme.error),
                  ),
                  onTap: () => _confirmLogout(context, ref),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: Icon(Icons.delete_rounded, color: scheme.error),
                  title: Text(
                    'Eliminar cuenta',
                    style: TextStyle(color: scheme.error),
                  ),
                  onTap: () => _confirmDeleteAccount(context, ref),
                ),
              ],
            ),
          ),
          const _SectionHeader(title: 'Legal y transparencia'),
          Card(
            child: ListTile(
              leading: Icon(Icons.shield_outlined, color: scheme.primary),
              title: const Text('Legal y transparencia'),
              subtitle: const Text('Términos, privacidad y sobre Kyubi'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push('/legal'),
            ),
          ),
          const _SectionHeader(title: 'Acerca de'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppDimens.md),
              child: Row(
                children: [
                  const KyubiLogo(size: 44, showGlow: false),
                  const SizedBox(width: AppDimens.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppConstants.appName,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          AppConstants.tagline,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Versión ${AppConstants.appVersion}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppDimens.lg),
        ],
      ),
    );
  }

  String _themeLabel(ThemeMode mode) => switch (mode) {
    ThemeMode.dark => 'Oscuro',
    ThemeMode.light => 'Claro',
    _ => 'Desconocido',
  };
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              gradient: AppColors.brandGradient,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: Theme.of(context).colorScheme.primary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Botón para confirmar la eliminación ──────────────────────────────────────

class _DeleteConfirmButton extends StatefulWidget {
  const _DeleteConfirmButton();

  @override
  State<_DeleteConfirmButton> createState() => _DeleteConfirmButtonState();
}

class _DeleteConfirmButtonState extends State<_DeleteConfirmButton> {
  final _controller = TextEditingController();
  bool get _confirmed => _controller.text == 'ELIMINAR';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          onChanged: (_) => setState(() {}),
          style: TextStyle(color: scheme.onSurface),
          decoration: InputDecoration(
            hintText: 'Escribe "ELIMINAR"',
            hintStyle: TextStyle(color: scheme.onSurfaceVariant),
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _confirmed ? () => Navigator.pop(context, true) : null,
          child: Text(
            'Eliminar cuenta',
            style: TextStyle(
              color: _confirmed
                  ? scheme.error
                  : scheme.onSurfaceVariant.withValues(alpha: 0.5),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
