import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/widgets/chat_bubble.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../core/widgets/sticker_catalog.dart';
import '../../../../models/chat_conversation.dart';
import '../../../../models/chat_message.dart';
import '../../../../services/auth_controller.dart';
import '../../../../services/providers.dart';
import '../../salas/presentation/widgets/chat_message_input_bar.dart';
import 'conversation_controller.dart';
import 'conversations_controller.dart';
import 'widgets/match_decision_bar.dart';

/// Conversación individual / grupal con mensajes en tiempo real.
class ConversationScreen extends ConsumerStatefulWidget {
  const ConversationScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final notifier = ref.read(
      conversationChatProvider(widget.conversationId).notifier,
    );
    await notifier.loadFor(widget.conversationId);
  }

  @override
  void dispose() {
    try {
      ref.read(conversationChatProvider(widget.conversationId).notifier).leave();
    } catch (_) {}
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(conversationChatProvider(widget.conversationId));
    ref.listen<ConversationChatState>(
      conversationChatProvider(widget.conversationId),
      (previous, next) {
        final prevLast = previous == null || previous.messages.isEmpty
            ? null
            : previous.messages.last.id;
        final nextLast = next.messages.isEmpty ? null : next.messages.last.id;
        if (nextLast == null || nextLast == prevLast) return;
        _scrollToBottom();
      },
    );
    final conversation = state.conversation;
    final myId = ref.watch(authControllerProvider).user?.id ?? '';
    // Resolución dinámica del destinatario: otherMember → members. Evita
    // 'Conversación' y '@usuario' cuando otherMember viene nulo (socket/caché).
    final otherUser = conversation?.resolveOtherMember(myId);
    final isGroup = conversation?.isGroup ?? false;
    final String title;
    if (isGroup) {
      final t = conversation?.title ?? '';
      title = t.isNotEmpty ? t : 'Conversación';
    } else {
      final name = otherUser?.displayName ?? '';
      final uname = otherUser?.username ?? '';
      title = name.isNotEmpty
          ? name
          : uname.isNotEmpty
              ? uname
              : 'Usuario';
    }
    final subtitle = (otherUser?.username.isNotEmpty ?? false)
        ? '@${otherUser!.username}'
        : null;
    final isOnline = otherUser?.isOnline ?? false;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFF0A0912),
      appBar: AppBar(
        backgroundColor: const Color(0xFF12101C),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (state.typingUsers.isNotEmpty)
              const Text(
                'escribiendo...',
                style: TextStyle(
                  fontSize: 11.5,
                  color: AppColors.accentCyan,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            else if (subtitle != null)
              Text(
                isOnline ? '$subtitle · 🟢 En línea' : subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: isOnline
                      ? AppColors.accentTeal
                      : const Color(0xFF8A8A9A),
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white70),
            onPressed: () => _showOptions(state),
          ),
        ],
      ),
      body: Column(
        children: [
          if (conversation != null && conversation.isMatch)
            MatchDecisionBar(
              conversation: conversation,
              myUserId: ref.watch(authControllerProvider).user?.id ?? '',
              onAccept: () {
                ref
                    .read(
                      conversationChatProvider(widget.conversationId).notifier,
                    )
                    .acceptMatch();
              },
              onReject: () {
                ref
                    .read(
                      conversationChatProvider(widget.conversationId).notifier,
                    )
                    .rejectMatch();
              },
              onNext: () {
                ref
                    .read(
                      conversationChatProvider(widget.conversationId).notifier,
                    )
                    .nextMatch();
                context.pushReplacement('/matchmaking');
              },
            ),
          Expanded(child: _buildBody(state)),
          SafeArea(top: false, bottom: true, child: _buildComposer(state)),
        ],
      ),
    );
  }

  Widget _buildBody(ConversationChatState state) {
    if (state.loading && state.messages.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFA594F9)),
      );
    }
    if (state.error != null && state.messages.isEmpty) {
      return ErrorView(
        message: state.error!,
        onRetry: () => _init(),
        title: 'No se pudo cargar la conversación',
      );
    }
    if (state.messages.isEmpty) {
      return EmptyView(
        imageWidget: Image.asset(
          AppAssets.iconMensajesVacios,
          width: 90,
          height: 90,
          fit: BoxFit.contain,
        ),
        title: 'Sin mensajes',
        message: 'Envía el primer mensaje para iniciar la conversación.',
      );
    }
    final myId = ref.watch(authControllerProvider).user?.id ?? '';
    final showLoader = state.hasMore;

    final items = <_ConvItem>[];
    final messages = state.messages;
    for (var i = messages.length - 1; i >= 0; i--) {
      final current = messages[i];
      items.add(_ConvItem.message(current));
      if (i == 0 || !_sameDay(current.createdAt, messages[i - 1].createdAt)) {
        items.add(_ConvItem.date(current.createdAt));
      }
    }

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: AppDimens.pagePadding,
      itemCount: items.length + (showLoader ? 1 : 0),
      itemBuilder: (context, index) {
        if (showLoader && index == items.length) {
          return _OlderLoader(
            onTap: () {
              ref
                  .read(
                    conversationChatProvider(widget.conversationId).notifier,
                  )
                  .loadOlder();
            },
          );
        }
        final item = items[index];
        if (item.isDate) {
          return _DateSeparator(date: item.date!);
        }

        final message = item.message!;
        // DM 1:1: sin nombre dentro de la burbuja para mantener burbujas
        // compactas y proporcionales (especialmente con textos muy cortos).
        return ChatMessageBubble(
          displayName: '',
          body: message.body,
          timestamp: _timeLabel(message.createdAt),
          avatarUrl: message.sender.avatarUrl,
          avatarName: message.sender.displayName,
          isMine: message.senderId == myId,
          isDeleted: message.isDeleted,
          media: message.media,
          mediaUrl: message.mediaUrl,
          mediaType: message.mediaType,
          type: message.extensions?['type'] as String?,
          extensions: message.extensions,
        );
      },
    );
  }

  Future<void> _send(
    String? customText, {
    String? mediaUrl,
    String? mediaType,
    Map<String, dynamic>? extensions,
  }) async {
    final body = customText ?? _inputController.text;
    if (body.trim().isEmpty && mediaUrl == null && extensions == null) return;
    _inputController.clear();
    final ok = await ref
        .read(conversationChatProvider(widget.conversationId).notifier)
        .send(
          body,
          mediaUrl: mediaUrl,
          mediaType: mediaType,
          extensions: extensions,
        );
    if (!mounted) return;
    if (ok) {
      _scrollToBottom();
      ref.read(conversationsControllerProvider.notifier).refresh();
    }
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo enviar el mensaje')),
      );
    }
  }

  void _sendDiceRoll(String diceName, String result, String emoji) {
    ref.read(conversationChatProvider(widget.conversationId).notifier).send(
      '$emoji Ha lanzado $diceName: $result',
      mediaType: 'dice',
      extensions: {
        'dice': {
          'name': diceName,
          'result': result,
          'emoji': emoji,
        },
      },
    );
    _scrollToBottom();
  }

  void _sendPoll(String question, List<String> options) {
    ref.read(conversationChatProvider(widget.conversationId).notifier).send(
      '📊 Encuesta: $question\n${options.map((o) => '• $o').join('\n')}',
      mediaType: 'poll',
      extensions: {
        'poll': {
          'question': question,
          'options': options
              .asMap()
              .entries
              .map((e) => {'id': 'opt_${e.key}', 'text': e.value, 'votes': 0})
              .toList(),
          'totalVotes': 0,
        },
      },
    );
    _scrollToBottom();
  }

  void _sendSticker(StickerItem sticker) {
    final fallbackText = sticker.name.isNotEmpty
        ? ':${sticker.name}:'
        : (sticker.emoji.isNotEmpty ? sticker.emoji : '🎨');
    ref.read(conversationChatProvider(widget.conversationId).notifier).send(
      fallbackText,
      mediaUrl: sticker.assetPath,
      mediaType: 'sticker',
      extensions: {
        'isAnimated': true,
        'stickerId': sticker.id,
        'assetPath': sticker.assetPath,
        'emoji': sticker.emoji,
        'name': sticker.name,
      },
    );
    _scrollToBottom();
  }

  Future<void> _sendImage(String imagePath, [ImageSource source = ImageSource.gallery]) async {
    String resolvedPath = imagePath;
    if (resolvedPath.isEmpty) {
      try {
        final picker = ImagePicker();
        final picked = await picker.pickImage(source: source);
        if (picked == null) return;
        resolvedPath = picked.path;
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo acceder a las imágenes')),
        );
        return;
      }
    }

    try {
      final file = File(resolvedPath);
      if (!await file.exists()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo leer la imagen seleccionada')),
        );
        return;
      }

      final bytes = await file.readAsBytes();
      final filename = resolvedPath.split(RegExp(r'[\\/]')).last;
      final uploadRepo = ref.read(uploadRepositoryProvider);
      final url = await uploadRepo.uploadFile(
        'media',
        bytes: bytes,
        filename: filename,
        contentType: _contentTypeForFilename(resolvedPath),
      );

      if (url.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo subir la imagen')),
        );
        return;
      }

      final ok = await ref
          .read(conversationChatProvider(widget.conversationId).notifier)
          .send('', mediaUrl: url, mediaType: 'image');

      if (!mounted) return;
      if (ok) {
        _scrollToBottom();
        ref.read(conversationsControllerProvider.notifier).refresh();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo enviar la imagen')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al procesar la imagen')),
      );
    }
  }

  String? _contentTypeForFilename(String filename) {
    final ext = filename.toLowerCase();
    if (ext.endsWith('.jpg') || ext.endsWith('.jpeg')) return 'image/jpeg';
    if (ext.endsWith('.png')) return 'image/png';
    if (ext.endsWith('.webp')) return 'image/webp';
    if (ext.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  Future<void> _sendAudio(int durationMs, Uint8List bytes, String filename) async {
    if (bytes.isNotEmpty) {
      try {
        final uploadRepo = ref.read(uploadRepositoryProvider);
        final url = await uploadRepo.uploadFile(
          'media',
          bytes: bytes,
          filename: filename,
          contentType: 'audio/m4a',
        );
        if (url.isNotEmpty) {
          final ok = await ref
              .read(conversationChatProvider(widget.conversationId).notifier)
              .send(
                '🎤 [Nota de voz (${durationMs ~/ 1000}s)]',
                mediaUrl: url,
                mediaType: 'audio',
                extensions: {
                  'voice': true,
                  'durationMs': durationMs,
                  'audioUrl': url,
                },
              );
          if (ok) {
            _scrollToBottom();
            ref.read(conversationsControllerProvider.notifier).refresh();
            return;
          }
        }
      } catch (_) {}
    }
    _send(
      '🎤 [Nota de voz (${durationMs ~/ 1000}s)]',
      mediaType: 'audio',
      extensions: {
        'voice': true,
        'durationMs': durationMs,
      },
    );
  }

  void _showAttachmentsModal() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF141220),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: Color(0xFF2E2746), width: 1)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: AppColors.accentCyan),
                title: const Text('Galería de fotos', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  _sendImage('', ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFFBA68C8)),
                title: const Text('Cámara', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  _sendImage('', ImageSource.camera);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComposer(ConversationChatState state) {
    final user = ref.watch(authControllerProvider).user;
    final myName = user?.displayName.isNotEmpty == true
        ? user!.displayName
        : (user?.username ?? 'Tú');

    return ChatMessageInputBar(
      enabled: !state.sending,
      disabledHint: state.sending ? 'Enviando...' : 'Escribe un mensaje...',
      isRoleplay: false,
      userName: myName,
      userAvatarUrl: user?.avatarUrl,
      onSendMessage: (text) => _send(text),
      onSendImage: (imagePath) => _sendImage(imagePath),
      onSendAudio: (durationMs, bytes, filename) =>
          _sendAudio(durationMs, bytes, filename),
      onSendDiceRoll: (diceName, result, emoji) =>
          _sendDiceRoll(diceName, result, emoji),
      onSendPoll: (question, options) => _sendPoll(question, options),
      onSendSticker: (sticker) => _sendSticker(sticker),
      onOpenModesTap: _showAttachmentsModal,
      // El "+" ya abre el sheet unificado (Galería/Cámara): se oculta el
      // acceso rápido duplicado a galería.
      hideQuickImageButton: true,
      onTypingChanged: (typing) {
        if (typing) {
          ref
              .read(conversationChatProvider(widget.conversationId).notifier)
              .sendTyping();
        }
      },
    );
  }

  void _showOptions(ConversationChatState state) {
    final conversation = state.conversation;
    if (conversation == null) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceCards,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF3A3A4A),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Icon(
                conversation.muted
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_off_rounded,
                color: Colors.white70,
              ),
              title: Text(
                conversation.muted ? 'Activar notificaciones' : 'Silenciar',
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _toggleMute(conversation);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline_rounded,
                color: Color(0xFF9B6FCB),
              ),
              title: const Text(
                'Eliminar conversación',
                style: TextStyle(color: Color(0xFF9B6FCB)),
              ),
              onTap: () {
                Navigator.pop(context);
                _deleteConversation();
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleMute(Conversation conversation) async {
    final repo = ref.read(chatRepositoryProvider);
    try {
      await repo.setMuted(widget.conversationId, !conversation.muted);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            conversation.muted
                ? 'Notificaciones activadas'
                : 'Conversación silenciada',
          ),
        ),
      );
    } catch (_) {}
  }

  Future<void> _deleteConversation() async {
    final repo = ref.read(chatRepositoryProvider);
    final notifier = ref.read(conversationsControllerProvider.notifier);
    try {
      await repo.deleteConversation(widget.conversationId);
      notifier.removeConversation(widget.conversationId);
      if (!mounted) return;
      context.pop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo eliminar la conversación')),
      );
    }
  }
}

String _timeLabel(DateTime dt) {
  final local = dt.toLocal();
  final h = local.hour.toString().padLeft(2, '0');
  final m = local.minute.toString().padLeft(2, '0');
  return '$h:$m';
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

class _ConvItem {
  const _ConvItem.message(this.message) : isDate = false, date = null;
  const _ConvItem.date(this.date) : isDate = true, message = null;

  final bool isDate;
  final Message? message;
  final DateTime? date;
}

bool _sameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DateSeparator extends StatelessWidget {
  const _DateSeparator({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final local = date.toLocal();
    String label;
    if (_sameDay(local, now)) {
      label = 'Hoy';
    } else if (_sameDay(local, now.subtract(const Duration(days: 1)))) {
      label = 'Ayer';
    } else {
      final day = local.day.toString().padLeft(2, '0');
      final month = local.month.toString().padLeft(2, '0');
      label = '$day/$month/${local.year}';
    }

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.surfaceCards,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2A2640), width: 0.8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 4,
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Color(0xFF9E9EA8),
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}
