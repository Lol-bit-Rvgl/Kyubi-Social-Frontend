import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/widgets/chat_bubble.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/widgets/state_views.dart';
import '../../../../core/widgets/sticker_catalog.dart';
import '../../../../core/widgets/swipe_to_reply.dart';
import '../../../../models/character.dart';
import '../../../../models/chat_conversation.dart';
import '../../../../models/chat_message.dart';
import '../../../../models/role_character.dart';
import '../../../../services/auth_controller.dart';
import '../../../../services/providers.dart';
import '../../roles/presentation/role_library_screen.dart';
import '../../salas/presentation/widgets/chat_message_input_bar.dart';
import '../../salas/presentation/widgets/role_chat_bubble.dart';
import 'conversation_controller.dart';
import 'conversation_info_screen.dart';
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
  Map<String, dynamic>? _replyingToMessage;
  Map<String, dynamic>? _editingMessage;
  bool _isRoleplayMode = false;
  RoleCharacter? _activeRole;

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
    try {
      final prefs = await SharedPreferences.getInstance();
      final isRp = prefs.getBool('roleplay_mode_${widget.conversationId}') ?? false;
      final activeRoleId = prefs.getString('active_role_${widget.conversationId}');
      RoleCharacter? restoredRole;
      if (isRp && activeRoleId != null && activeRoleId.isNotEmpty) {
        final myChars = ref.read(myCharactersProvider).valueOrNull ?? [];
        final foundChar = myChars.where((c) => c.id == activeRoleId).firstOrNull;
        final user = ref.read(authControllerProvider).user;
        final myName = user?.displayName.isNotEmpty == true
            ? user!.displayName
            : (user?.username ?? 'Tú');
        if (foundChar != null) {
          restoredRole = foundChar.toRoleCharacter(
            currentUserId: user?.id,
            currentUsername: myName,
          );
        }
      }
      if (mounted) {
        setState(() {
          _isRoleplayMode = isRp;
          if (restoredRole != null) {
            _activeRole = restoredRole;
          }
        });
      }
    } catch (_) {}
  }

  Map<String, dynamic>? _buildRoleExtensions(Map<String, dynamic>? base) {
    if (!_isRoleplayMode || _activeRole == null) return base;
    return <String, dynamic>{
      ...?base,
      'role': _activeRole!.toJson(),
      'roleColor': _activeRole!.colorHex,
      'roleColorHex': _activeRole!.colorHex,
      'roleName': _activeRole!.name,
      'roleAvatarUrl': _activeRole!.avatarUrl,
    };
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
        title: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () async {
            HapticFeedback.lightImpact();
            await ConversationInfoScreen.show(
              context,
              conversationId: widget.conversationId,
              onRoleplayModeChanged: (enabled) {
                if (mounted) setState(() => _isRoleplayMode = enabled);
              },
            );
            final prefs = await SharedPreferences.getInstance();
            final isRp = prefs.getBool('roleplay_mode_${widget.conversationId}') ?? false;
            final activeRoleId = prefs.getString('active_role_${widget.conversationId}');
            RoleCharacter? restoredRole = _activeRole;
            if (activeRoleId != null && activeRoleId.isNotEmpty) {
              final myChars = ref.read(myCharactersProvider).valueOrNull ?? [];
              final foundChar = myChars.where((c) => c.id == activeRoleId).firstOrNull;
              final user = ref.read(authControllerProvider).user;
              final myName = user?.displayName.isNotEmpty == true
                  ? user!.displayName
                  : (user?.username ?? 'Tú');
              if (foundChar != null) {
                restoredRole = foundChar.toRoleCharacter(
                  currentUserId: user?.id,
                  currentUsername: myName,
                );
              }
            }
            if (mounted) {
              setState(() {
                _isRoleplayMode = isRp;
                _activeRole = restoredRole;
              });
            }
          },
          child: Column(
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
    final currentUser = ref.watch(authControllerProvider).user;
    final myName = currentUser?.displayName.isNotEmpty == true
        ? currentUser!.displayName
        : (currentUser?.username ?? 'Tú');

    final items = <_ConvItem>[];
    final messages = state.messages;
    for (var i = messages.length - 1; i >= 0; i--) {
      final current = messages[i];
      items.add(_ConvItem.message(current));
      if (i == 0) {
        items.add(_ConvItem.date(current.createdAt));
      } else {
        final prev = messages[i - 1];
        final isTemp = current.id.startsWith('local-');
        final same = isTemp
            ? (_sameDay(current.createdAt, prev.createdAt) ||
                _sameDay(DateTime.now(), prev.createdAt))
            : _sameDay(current.createdAt, prev.createdAt);
        if (!same) {
          items.add(_ConvItem.date(current.createdAt));
        }
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
        final replyMsg = message.replyToId != null
            ? state.messages.where((m) => m.id == message.replyToId).firstOrNull
            : null;
        final replySenderName = replyMsg != null
            ? (replyMsg.sender.displayName.isNotEmpty
                ? replyMsg.sender.displayName
                : replyMsg.sender.username)
            : message.extensions?['replyTo']?['senderName'] as String?;
        final replyBody = replyMsg?.body ??
            message.extensions?['replyTo']?['body'] as String?;
        final replyMediaUrl = replyMsg?.mediaUrl ??
            message.extensions?['replyTo']?['mediaUrl'] as String?;

        RoleCharacter? messageRole;
        final roleRaw = message.extensions?['role'];
        if (roleRaw is Map) {
          messageRole = RoleCharacter.fromJson(Map<String, dynamic>.from(roleRaw));
        } else if (_isRoleplayMode && (message.senderId == myId) && _activeRole != null) {
          messageRole = _activeRole;
        }

        final Widget bubble;
        if (_isRoleplayMode || messageRole != null) {
          final isMine = message.senderId == myId;
          final authorRealName = isMine
              ? myName
              : (message.sender.displayName.isNotEmpty
                  ? message.sender.displayName
                  : message.sender.username);
          bubble = RoleChatBubble(
            key: ValueKey(message.id),
            body: message.body,
            senderName: messageRole != null ? messageRole.name : authorRealName,
            userName: authorRealName,
            role: messageRole,
            userAvatarUrl: messageRole?.avatarUrl ?? message.sender.avatarUrl,
            isMine: isMine,
            timestamp: _timeLabel(message.createdAt),
            messageType: (message.mediaType == 'dice' ||
                    message.extensions?['dice'] != null)
                ? 'dice'
                : (message.mediaType == 'sticker' ||
                        message.extensions?['stickerId'] != null)
                    ? 'sticker'
                    : (message.mediaType == 'poll' ||
                            message.extensions?['poll'] != null)
                        ? 'poll'
                        : (message.mediaType == 'audio' ||
                                message.extensions?['voice'] != null)
                            ? 'voice'
                            : (message.mediaType == 'image')
                                ? 'image'
                                : 'message',
            contentUrl: message.mediaUrl ?? message.media?.url,
            metadata: message.extensions,
            isDiceRoll: message.mediaType == 'dice' ||
                message.extensions?['dice'] != null,
            diceResult: message.extensions?['dice']?['result']?.toString(),
            diceEmoji: message.extensions?['dice']?['emoji']?.toString(),
            isSticker: message.mediaType == 'sticker' ||
                message.extensions?['stickerId'] != null,
            stickerAsset: message.mediaUrl ??
                (message.extensions?['assetPath'] as String?),
            stickerEmoji: message.extensions?['emoji'] as String?,
            replyToId: message.replyToId,
            replyToName: replySenderName,
            replyToBody: replyBody,
            replyToMediaUrl: replyMediaUrl,
            isEdited: message.isEdited,
            editedAt: message.editedAt,
            onPollVote: (optId) => ref
                .read(conversationChatProvider(widget.conversationId).notifier)
                .votePoll(message.id, optId),
            onUserTap: () {
              if (message.sender.username.isNotEmpty) {
                context.push('/profile/${message.sender.username}');
              }
            },
          );
        } else {
          bubble = ChatMessageBubble(
            key: ValueKey(message.id),
            displayName: '',
            body: message.body,
            timestamp: _timeLabel(message.createdAt),
            avatarUrl: message.sender.avatarUrl,
            avatarName: message.sender.displayName,
            isMine: message.senderId == myId,
            isDeleted: message.isDeleted,
            isEdited: message.isEdited,
            editedAt: message.editedAt,
            isSending: message.isSending,
            replyToId: message.replyToId,
            replyToName: replySenderName,
            replyToBody: replyBody,
            replyToMediaUrl: replyMediaUrl,
            media: message.media,
            mediaUrl: message.mediaUrl,
            mediaType: message.mediaType,
            type: message.extensions?['type'] as String?,
            extensions: message.extensions,
            currentUserId: myId,
            onPollVote: (optId) => ref
                .read(conversationChatProvider(widget.conversationId).notifier)
                .votePoll(message.id, optId),
          );
        }

        return SwipeToReply(
          key: ValueKey('swipe_${message.id}'),
          onReply: () => _startReply(message),
          threshold: 64.0,
          onThresholdCrossed: () => HapticFeedback.lightImpact(),
          child: GestureDetector(
            onLongPress: () => _showMessageContextMenu(message),
            child: bubble,
          ),
        );
      },
    );
  }

  void _startReply(Message msg) {
    HapticFeedback.lightImpact();
    setState(() {
      _editingMessage = null;
      _replyingToMessage = {
        'id': msg.id,
        'senderName': msg.sender.displayName.isNotEmpty
            ? msg.sender.displayName
            : msg.sender.username,
        'body': msg.body,
        'mediaUrl': msg.mediaUrl ?? msg.media?.url,
        'type': msg.mediaType,
      };
    });
  }

  void _cancelReply() {
    setState(() {
      _replyingToMessage = null;
    });
  }

  void _startEdit(Message msg) {
    HapticFeedback.lightImpact();
    setState(() {
      _replyingToMessage = null;
      _editingMessage = {
        'id': msg.id,
        'body': msg.body,
      };
    });
  }

  void _cancelEdit() {
    setState(() {
      _editingMessage = null;
    });
  }

  Future<void> _submitEdit(String messageId, String newText) async {
    setState(() {
      _editingMessage = null;
    });
    final ok = await ref
        .read(conversationChatProvider(widget.conversationId).notifier)
        .editMessage(messageId, newText);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo editar el mensaje')),
      );
    }
  }

  Future<void> _confirmDeleteMessage(Message msg) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B172B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Eliminar mensaje', style: TextStyle(color: Colors.white)),
        content: const Text(
          '¿Estás seguro de que deseas eliminar este mensaje?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white60)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar', style: TextStyle(color: AppColors.accentCrimson)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final ok = await ref
        .read(conversationChatProvider(widget.conversationId).notifier)
        .deleteMessage(msg.id);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo eliminar el mensaje')),
      );
    }
  }

  Future<void> _saveImageToGallery(String imageUrl) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Descargando imagen...'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 1),
        ),
      );
      final dio = Dio();
      final response = await dio.get<List<int>>(
        imageUrl,
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = response.data;
      if (bytes != null && bytes.isNotEmpty) {
        await Gal.putImageBytes(Uint8List.fromList(bytes));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Imagen guardada en la galería'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColors.accentTeal,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar imagen: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.accentCrimson,
          ),
        );
      }
    }
  }

  void _showMessageContextMenu(Message msg) {
    if (msg.isDeleted) return;
    HapticFeedback.mediumImpact();
    final myId = ref.read(authControllerProvider).user?.id ?? '';
    final isMine = msg.senderId == myId;
    final text = msg.body.trim();
    final mediaUrl = msg.mediaUrl ?? msg.media?.url;
    final isImage = (msg.mediaType == 'image' ||
            (mediaUrl != null && DirectChatMessageBubble.isLikelyImageUrl(mediaUrl))) ||
        (text.startsWith('http') && DirectChatMessageBubble.isLikelyImageUrl(text));
    final effectiveImageUrl =
        (mediaUrl != null && mediaUrl.isNotEmpty) ? mediaUrl : (isImage ? text : '');

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF13101E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
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
            if (text.isNotEmpty && !isImage)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Text(
                  text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF9E9EA8),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ListTile(
              leading: const Icon(Icons.reply_rounded, color: AppColors.accentCyan),
              title: const Text(
                'Responder',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _startReply(msg);
              },
            ),
            if (isImage && effectiveImageUrl.isNotEmpty) ...[
              ListTile(
                leading: const Icon(Icons.download_rounded, color: AppColors.accentTeal),
                title: const Text(
                  'Guardar imagen',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Descargar a la galería del dispositivo',
                  style: TextStyle(color: Color(0xFF8A8A9A), fontSize: 11),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _saveImageToGallery(effectiveImageUrl);
                },
              ),
              ListTile(
                leading: const Icon(Icons.link_rounded, color: Color(0xFF9E9EA8)),
                title: const Text(
                  'Copiar enlace de imagen',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  Clipboard.setData(ClipboardData(text: effectiveImageUrl));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Enlace de imagen copiado al portapapeles'),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
              ),
            ] else if (text.isNotEmpty) ...[
              ListTile(
                leading: const Icon(Icons.copy_rounded, color: Color(0xFF9E9EA8)),
                title: const Text(
                  'Copiar texto',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  Clipboard.setData(ClipboardData(text: text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Mensaje copiado al portapapeles'),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
              ),
            ],
            if (isMine && !isImage && text.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.edit_rounded, color: Color(0xFFFFB300)),
                title: const Text(
                  'Editar mensaje',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _startEdit(msg);
                },
              ),
            if (isMine)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: AppColors.accentCrimson),
                title: const Text(
                  'Eliminar mensaje',
                  style: TextStyle(color: AppColors.accentCrimson, fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDeleteMessage(msg);
                },
              ),
          ],
        ),
      ),
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
    final replyId = _replyingToMessage?['id'] as String?;
    setState(() {
      _replyingToMessage = null;
    });
    _scrollToBottom();
    final ok = await ref
        .read(conversationChatProvider(widget.conversationId).notifier)
        .send(
          body,
          mediaUrl: mediaUrl,
          mediaType: mediaType,
          replyToId: replyId,
          extensions: _buildRoleExtensions(extensions),
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
      extensions: _buildRoleExtensions({
        'dice': {
          'name': diceName,
          'result': result,
          'emoji': emoji,
        },
      }),
    );
    _scrollToBottom();
  }

  void _sendPoll(String question, List<String> options) {
    ref.read(conversationChatProvider(widget.conversationId).notifier).send(
      '📊 Encuesta: $question\n${options.map((o) => '• $o').join('\n')}',
      mediaType: 'poll',
      extensions: _buildRoleExtensions({
        'poll': {
          'question': question,
          'options': options
              .asMap()
              .entries
              .map((e) => {'id': 'opt_${e.key}', 'text': e.value, 'votes': 0})
              .toList(),
          'totalVotes': 0,
        },
      }),
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
      extensions: _buildRoleExtensions({
        'isAnimated': true,
        'stickerId': sticker.id,
        'assetPath': sticker.assetPath,
        'emoji': sticker.emoji,
        'name': sticker.name,
      }),
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
          const SnackBar(content: Text('No se pudo leer el archivo seleccionado')),
        );
        return;
      }

      final bytes = await file.readAsBytes();
      final filename = resolvedPath.split(RegExp(r'[\\/]')).last;
      final lower = resolvedPath.toLowerCase();

      // Si el archivo seleccionado es un audio, delegar a _sendAudio
      final isAudio = lower.endsWith('.mp3') ||
          lower.endsWith('.m4a') ||
          lower.endsWith('.aac') ||
          lower.endsWith('.wav');
      if (isAudio) {
        return await _sendAudio(10000, bytes, filename);
      }

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
          const SnackBar(content: Text('No se pudo subir el archivo')),
        );
        return;
      }

      final isVideo = lower.endsWith('.mp4');
      final isPdf = lower.endsWith('.pdf');
      final mediaType = isVideo ? 'video' : (isPdf ? 'file' : 'image');
      final msgType = isPdf ? 'FILE' : (isVideo ? 'VIDEO' : 'IMAGE');

      final ok = await ref
          .read(conversationChatProvider(widget.conversationId).notifier)
          .send(
            isPdf ? '📄 $filename' : '',
            mediaUrl: url,
            mediaType: mediaType,
            type: msgType,
            extensions: _buildRoleExtensions(
              isPdf ? {'fileName': filename, 'fileSize': bytes.length} : null,
            ),
          );

      if (!mounted) return;
      if (ok) {
        _scrollToBottom();
        ref.read(conversationsControllerProvider.notifier).refresh();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo enviar el archivo')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al procesar el archivo')),
      );
    }
  }

  String? _contentTypeForFilename(String filename) {
    final ext = filename.toLowerCase();
    if (ext.endsWith('.jpg') || ext.endsWith('.jpeg')) return 'image/jpeg';
    if (ext.endsWith('.png')) return 'image/png';
    if (ext.endsWith('.webp')) return 'image/webp';
    if (ext.endsWith('.gif')) return 'image/gif';
    if (ext.endsWith('.mp4')) return 'video/mp4';
    if (ext.endsWith('.pdf')) return 'application/pdf';
    if (ext.endsWith('.mp3')) return 'audio/mpeg';
    if (ext.endsWith('.m4a')) return 'audio/m4a';
    if (ext.endsWith('.aac')) return 'audio/aac';
    if (ext.endsWith('.wav')) return 'audio/wav';
    return 'image/jpeg';
  }

  Future<void> _sendAudio(int durationMs, Uint8List bytes, String filename) async {
    if (bytes.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo grabar o leer el audio')),
        );
      }
      return;
    }
    try {
      final uploadRepo = ref.read(uploadRepositoryProvider);
      final lower = filename.toLowerCase();
      final isKnownExt = lower.endsWith('.m4a') ||
          lower.endsWith('.mp3') ||
          lower.endsWith('.aac') ||
          lower.endsWith('.wav');
      final effectiveName = isKnownExt ? filename : '$filename.m4a';
      final contentType = lower.endsWith('.mp3')
          ? 'audio/mpeg'
          : (lower.endsWith('.aac')
              ? 'audio/aac'
              : (lower.endsWith('.wav') ? 'audio/wav' : 'audio/m4a'));
      final url = await uploadRepo.uploadFile(
        'media',
        bytes: bytes,
        filename: effectiveName,
        contentType: contentType,
      );
      if (url.isNotEmpty) {
        final ok = await ref
            .read(conversationChatProvider(widget.conversationId).notifier)
            .send(
              '🎤 [Audio: $effectiveName]',
              mediaUrl: url,
              mediaType: 'audio',
              extensions: _buildRoleExtensions({
                'voice': true,
                'durationMs': durationMs,
                'audioUrl': url,
                'fileName': effectiveName,
              }),
            );
        if (ok) {
          _scrollToBottom();
          ref.read(conversationsControllerProvider.notifier).refresh();
          return;
        }
      }
    } catch (e) {
      debugPrint('[AUDIO_DEBUG] Error subiendo audio: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al enviar el archivo de audio')),
        );
      }
    }
  }

  Widget _buildComposer(ConversationChatState state) {
    final user = ref.watch(authControllerProvider).user;
    final myName = user?.displayName.isNotEmpty == true
        ? user!.displayName
        : (user?.username ?? 'Tú');
    final myId = user?.id ?? '';

    final List<RoleCharacter> availableRoles;
    if (_isRoleplayMode) {
      final myCharacters = ref.watch(myCharactersProvider).valueOrNull ?? [];
      availableRoles = myCharacters
          .map((c) => c.toRoleCharacter(
                currentUserId: myId,
                currentUsername: myName,
              ))
          .toList();

      if (_activeRole != null &&
          !availableRoles.any((r) => r.id == _activeRole!.id)) {
        availableRoles.add(_activeRole!);
      }
    } else {
      availableRoles = const [];
    }

    return ChatMessageInputBar(
      enabled: true,
      disabledHint: 'Escribe un mensaje...',
      isRoleplay: _isRoleplayMode,
      userName: myName,
      userAvatarUrl: user?.avatarUrl,
      currentRole: _activeRole,
      availableRoles: availableRoles,
      currentUserId: myId,
      onRoleChanged: (role) async {
        setState(() => _activeRole = role);
        final prefs = await SharedPreferences.getInstance();
        if (role != null) {
          await prefs.setString(
            'active_role_${widget.conversationId}',
            role.id,
          );
        } else {
          await prefs.remove('active_role_${widget.conversationId}');
        }
      },
      onIdentityChanged: (role) async {
        setState(() => _activeRole = role);
        final prefs = await SharedPreferences.getInstance();
        if (role != null) {
          await prefs.setString(
            'active_role_${widget.conversationId}',
            role.id,
          );
        } else {
          await prefs.remove('active_role_${widget.conversationId}');
        }
      },
      onSendMessage: (text) => _send(text),
      onSendImage: (imagePath) => _sendImage(imagePath),
      onSendAudio: (durationMs, bytes, filename) =>
          _sendAudio(durationMs, bytes, filename),
      onSendDiceRoll: (diceName, result, emoji) =>
          _sendDiceRoll(diceName, result, emoji),
      onSendPoll: (question, options) => _sendPoll(question, options),
      onSendSticker: (sticker) => _sendSticker(sticker),
      // El "+" ya abre el sheet unificado (Galería/Cámara/Encuestas).
      hideQuickImageButton: true,
      replyingToMessage: _replyingToMessage,
      onCancelReply: _cancelReply,
      editingMessage: _editingMessage,
      onCancelEdit: _cancelEdit,
      onSendEdit: (messageId, newText) => _submitEdit(messageId, newText),
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
            SwitchListTile.adaptive(
              secondary: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _isRoleplayMode
                      ? const Color(0xFFE5A93C).withValues(alpha: 0.15)
                      : const Color(0xFF1E1930),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _isRoleplayMode
                        ? const Color(0xFFE5A93C)
                        : const Color(0xFF332B4F),
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.theater_comedy_rounded,
                  color: _isRoleplayMode ? const Color(0xFFE5A93C) : Colors.white60,
                  size: 18,
                ),
              ),
              title: const Text(
                'Modo Roleplay',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Fichas de personaje y burbujas de rol',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
              value: _isRoleplayMode,
              activeThumbColor: const Color(0xFFE5A93C),
              activeTrackColor: const Color(0xFFE5A93C).withValues(alpha: 0.35),
              onChanged: (val) async {
                setState(() => _isRoleplayMode = val);
                Navigator.pop(context);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('roleplay_mode_${widget.conversationId}', val);
              },
            ),
            if (_isRoleplayMode)
              ListTile(
                leading: const Icon(
                  Icons.person_pin_circle_rounded,
                  color: Color(0xFFE5A93C),
                ),
                title: const Text(
                  'Elegir personaje activo',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  _activeRole != null ? _activeRole!.name : 'Sin personaje asignado (toca para elegir)',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  final picked = await RoleLibraryScreen.showPicker(context);
                  if (picked != null && mounted) {
                    final myUser = ref.read(authControllerProvider).user;
                    final roleToUse = picked.copyWith(
                      isTaken: true,
                      takenByUserId: myUser?.id,
                      takenByUsername: myUser?.displayName.isNotEmpty == true
                          ? myUser!.displayName
                          : myUser?.username,
                    );
                    setState(() => _activeRole = roleToUse);
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString(
                      'active_role_${widget.conversationId}',
                      roleToUse.id,
                    );
                  }
                },
              ),
            const Divider(height: 1, color: Color(0x14FFFFFF)),
            ListTile(
              leading: Icon(
                conversation.muted
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_off_rounded,
                color: Colors.white70,
              ),
              title: Text(
                conversation.muted
                    ? 'Reactivar notificaciones'
                    : 'Silenciar conversación',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _toggleMute(conversation);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.danger,
              ),
              title: const Text(
                'Eliminar conversación',
                style: TextStyle(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _confirmDeleteConversation();
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteConversation() {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF14141B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Eliminar conversación',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        content: const Text(
          '¿Deseas eliminar esta conversación? Los mensajes se borrarán de tu bandeja.',
          style: TextStyle(color: Color(0xFF9E9EA8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Color(0xFF7A7A8A)),
            ),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              _deleteConversation();
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Eliminar',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
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
  final la = a.toLocal();
  final lb = b.toLocal();
  return la.year == lb.year && la.month == lb.month && la.day == lb.day;
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
