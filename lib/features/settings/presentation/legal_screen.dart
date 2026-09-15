import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/utils/open_url.dart';
import '../../../../core/widgets/kyubi_logo.dart';

/// Legal y transparencia: parte importante de la experiencia de Kyubi.
///
/// Muestra la identidad (Kyubi, desarrollada por Nodo Apps) y da acceso a
/// los documentos oficiales. No inventa contenido legal: usa las URLs
/// oficiales de Nodo Apps.
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Legal y transparencia')),
      body: ListView(
        padding: AppDimens.pagePadding,
        children: [
          const SizedBox(height: AppDimens.md),
          const Center(
            child: KyubiLogo(size: 84, withWordmark: true, showGlow: false),
          ),
          const SizedBox(height: AppDimens.md),
          Text(
            'Transparencia',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.sm),
            child: Text(
              'Kyubi nació de la comunidad y se construye con transparencia. '
              'Estos documentos son parte de ese compromiso.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: AppDimens.xl),
          const _SectionHeader(title: 'Documentos oficiales'),
          Card(
            child: Column(
              children: [
                _DocTile(
                  icon: Icons.description_outlined,
                  title: 'Términos y condiciones',
                  subtitle: 'Documento oficial de Nodo Apps',
                  url: AppConstants.termsUrl,
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                _DocTile(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Política de privacidad',
                  subtitle: 'Documento oficial de Nodo Apps',
                  url: AppConstants.privacyUrl,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimens.xl),
          const _SectionHeader(title: 'Sobre Kyubi'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppDimens.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                          'Desarrollado por ${AppConstants.companyName}',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Una plataforma de la comunidad, para la comunidad.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppDimens.lg),
          Center(
            child: Text(
              AppConstants.appSlogan,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: AppDimens.xl),
        ],
      ),
    );
  }
}

class _DocTile extends StatelessWidget {
  const _DocTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.url,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String url;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.open_in_new_rounded, size: 18),
      onTap: () async {
        final ok = await openUrl(url);
        if (!ok && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo abrir el documento')),
          );
        }
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
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
