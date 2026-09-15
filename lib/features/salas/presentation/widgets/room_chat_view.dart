import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/chat_bubble.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../models/room.dart';
import '../../../../services/auth_controller.dart';
import '../sala_chat_controller.dart';
import '../sala_detail_controller.dart';

/// Pestaña de chat en vivo de una sala: historial con roles, autoscroll y
/// compositor. Solo se puede escribir siendo participante de una sala activa.
class RoomChatView extends ConsumerStatefulWidget {
  const RoomChatView({super.key, required this.roomId});

  final String roomId;

  @override
  ConsumerState<RoomChatView> createState() => _RoomChatViewState();
}

class _RoomChatViewState extends ConsumerState<RoomChatView>
    with AutomaticKeepAliveClientMixin {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  bool get wantKeepAlive => true;

  Future<void> _send() async {
    final body = _inputController.text;
    if (body.trim().isEmpty) return;
    _inputController.clear();
    final ok = await ref
        .read(salaChatControllerProvider(widget.roomId).notifier)
        .send(body);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo enviar el mensaje')),
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.minScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final state = ref.watch(salaChatControllerProvider(widget.roomId));
    final room = ref.watch(salaDetailControllerProvider(widget.roomId)).room;

    ref.listen<SalaChatState>(salaChatControllerProvider(widget.roomId), (
      previous,
      next,
    ) {
      final prevLast = previous == null || previous.messages.isEmpty
          ? null
          : previous.messages.last.id;
      final nextLast = next.messages.isEmpty ? null : next.messages.last.id;
      if (nextLast == null || nextLast == prevLast) return;
      _scrollToBottom();
    });

    final roleMap = <String, String>{
      for (final p in (room?.participants ?? const <RoomParticipant>[]))
        p.user.id: p.role,
    };

    return Column(
      children: [
        Expanded(child: _buildMessages(state, roleMap)),
        _buildComposer(state, room),
      ],
    );
  }

  Widget _buildMessages(SalaChatState state, Map<String, String> roleMap) {
    if (state.loading && state.messages.isEmpty) {
      return const LoadingView(message: 'Cargando mensajes...');
    }
    if (state.error != null && state.messages.isEmpty) {
      return ErrorView(
        message: state.error!,
        onRetry: () => ref
            .read(salaChatControllerProvider(widget.roomId).notifier)
            .retry(),
        title: 'No se pudo cargar el chat',
      );
    }
    if (state.messages.isEmpty) {
      return const EmptyView(
        icon: Icons.forum_outlined,
        title: 'Sin mensajes',
        message:
            'Envía el primer mensaje para hablar con los participantes de la sala.',
      );
    }
    final myId = ref.watch(authControllerProvider).user?.id ?? '';
    final showLoader = state.hasMore;
    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: AppDimens.pagePadding,
      itemCount: state.messages.length + (showLoader ? 1 : 0),
      itemBuilder: (context, index) {
        if (showLoader && index == state.messages.length) {
          return _OlderLoader(
            onTap: () {
              ref
                  .read(salaChatControllerProvider(widget.roomId).notifier)
                  .loadOlder();
            },
          );
        }
        final message = state.messages[state.messages.length - 1 - index];
        final role = roleMap[message.senderId];
        return ChatMessageBubble(
          displayName: message.sender.displayName,
          body: message.body,
          timestamp: _timeLabel(message.createdAt),
          avatarUrl: message.sender.avatarUrl,
          avatarName: message.sender.displayName,
          isMine: message.senderId == myId,
          roleLabel: _roleLabel(role),
          roleColor: _roleColor(role),
        );
      },
    );
  }

  Widget _buildComposer(SalaChatState state, Room? room) {
    if (room == null) return const SizedBox.shrink();
    if (room.status == RoomStatus.ended) {
      return _ComposerGate(
        message: 'La sala ha terminado. El chat es de solo lectura.',
        icon: Icons.flag_rounded,
      );
    }
    if (!room.isParticipant) {
      return _ComposerGate(
        message: 'Únete a la sala para enviar mensajes.',
        icon: Icons.lock_outline_rounded,
      );
    }
    final sending = state.sending;

    return Container(
      padding: EdgeInsets.fromLTRB(
        AppDimens.md,
        8,
        AppDimens.md,
        8 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              minLines: 1,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Escribe un mensaje...',
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: sending ? null : _send,
            icon: sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_rounded),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  String? _roleLabel(String? role) {
    if (role == 'HOST') return 'Anfitrión';
    if (role != null && (role.contains('ADMIN') || role.contains('CO_COST'))) {
      return 'Co-Admin';
    }
    return null;
  }

  Color? _roleColor(String? role) {
    if (role == 'HOST') return AppColors.warning;
    if (role != null && (role.contains('ADMIN') || role.contains('CO_COST'))) {
      return AppColors.vhsCyan;
    }
    return null;
  }
}

String _timeLabel(DateTime dt) {
  final local = dt.toLocal();
  final h = local.hour.toString().padLeft(2, '0');
  final m = local.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

class _ComposerGate extends StatelessWidget {
  const _ComposerGate({required this.message, required this.icon});

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppDimens.md),
      width: double.infinity,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _OlderLoader extends StatelessWidget {
  const _OlderLoader({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.keyboard_arrow_up_rounded),
        label: const Text('Ver mensajes anteriores'),
      ),
    );
  }
}
