import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../models/user.dart';
import '../../../../services/providers.dart';

/// Lista de usuarios que visitaron un perfil (Historial de visitas).
///
/// Muestra, por cada visitante: avatar, nombre, @username y la fecha relativa
/// de la última visita. Solo se registra la visita a perfiles ajenos (nunca el
/// propio), por lo que esta pantalla lista únicamente visitantes reales.
class VisitorListScreen extends ConsumerStatefulWidget {
  const VisitorListScreen({super.key, required this.username});

  final String username;

  @override
  ConsumerState<VisitorListScreen> createState() => _VisitorListScreenState();
}

class _VisitorListScreenState extends ConsumerState<VisitorListScreen> {
  List<VisitItem> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(userRepositoryProvider);
      final visits = await repo.getVisits(widget.username);
      if (!mounted) return;
      setState(() {
        _items = visits;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Retorno seguro: al salir (botón atrás o gesto del sistema) se devuelve
    // el conteo real para que el perfil no caiga a 0 al volver.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.of(context).pop(_items.isNotEmpty ? _items.length : null);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Visitas'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).pop(_items.isNotEmpty ? _items.length : null),
          ),
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const LoadingView(message: 'Cargando visitas...');
    if (_error != null) {
      return ErrorView(message: _error!, onRetry: _load);
    }
    if (_items.isEmpty) {
      return const EmptyView(
        icon: Icons.visibility_off_outlined,
        title: 'Sin visitas todavía',
        message: 'Nadie ha visitado tu perfil recientemente.',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: AppDimens.pagePadding,
        itemCount: _items.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppDimens.xs),
        itemBuilder: (context, index) {
          final item = _items[index];
          return _VisitorTile(
            item: item,
            onTap: () => context.push('/profile/${item.username}'),
          );
        },
      ),
    );
  }
}

class _VisitorTile extends StatelessWidget {
  const _VisitorTile({required this.item, required this.onTap});

  final VisitItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final nameColor = AppColors.fromHex(item.usernameColor);
    final visitedLabel = DateUtilsX.isoToRelative(item.visitedAt) ?? '';

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: AppAvatar(
          imageUrl: item.avatarUrl,
          name: item.displayName,
          radius: AppDimens.avatarMd / 2,
          showOnline: true,
          isOnline: item.isOnline,
          onTap: onTap,
        ),
        title: Text(
          item.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontWeight: FontWeight.w700, color: nameColor),
        ),
        subtitle: Text(
          item.username.isNotEmpty ? '@${item.username}' : item.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
        trailing: visitedLabel.isEmpty
            ? null
            : Text(
                visitedLabel,
                style: TextStyle(
                  fontSize: 11,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                ),
              ),
        onTap: onTap,
      ),
    );
  }
}