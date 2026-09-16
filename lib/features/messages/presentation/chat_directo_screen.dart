import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/constants/room_backgrounds.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/fullscreen_image_viewer.dart';
import '../../../core/widgets/kyubi_rich_text.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/sticker_catalog.dart';
import '../../../models/chat_conversation.dart';
import '../../../models/chat_message.dart';
import '../../../models/media.dart';
import '../../../services/auth_controller.dart';
import '../../../services/providers.dart';
import '../../salas/presentation/widgets/chat_message_input_bar.dart';
import '../../salas/presentation/widgets/room_user_profile_sheet.dart';
import 'conversation_controller.dart';
import 'conversations_controller.dart';

/// Pantalla dedicada de Mensajería Directa (DM) 1-a-1.
///
/// Refleja el rediseño visual moderno de Kyubi:
/// - AppBar inmersivo con avatar real del destinatario, badge de estado (🟢 En línea / Últ. vez), @handle y nombre en negrita.
/// - Scroll y teclado responsivos: `resizeToAvoidBottomInset: true`, `reverse: true`, `keyboardDismissBehavior: onDrag`.
/// - Separadores de fecha centrados ("Hoy", "Ayer", "DD/MM/YYYY") entre días distintos.
/// - Burbujas estilizadas:
///   * Propias: fondo carmesí/vino oscuro (`#28101D`), bordes redondeados y doble check.
///   * Receptor: fondo obsidiana (`#14141E`), bordes redondeados y avatar con toque rápido.
class ChatDirectoScreen extends ConsumerStatefulWidget {
  const ChatDirectoScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<ChatDirectoScreen> createState() => _ChatDirectoScreenState();
}

class _ChatDirectoScreenState extends ConsumerState<ChatDirectoScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  String? _chatBgAsset;

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
      if (mounted) {
        setState(() {
          _chatBgAsset = prefs.getString('chat_bg_${widget.conversationId}');
        });
      }
    } catch (_) {}
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

  Future<void> _send([String? customText]) async {
    final body = customText ?? _inputController.text;
    if (body.trim().isEmpty) return;
    _inputController.clear();
    final ok = await ref
        .read(conversationChatProvider(widget.conversationId).notifier)
        .send(body);
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
    _send('$emoji Ha lanzado $diceName: $result');
  }

  void _sendPoll(String question, List<String> options) {
    _send('📊 Encuesta: $question\n${options.map((o) => '• $o').join('\n')}');
  }

  void _sendSticker(StickerItem sticker) {
    _send(sticker.emoji.isNotEmpty ? sticker.emoji : '✨ ${sticker.name}');
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
          .send('📷 [Imagen adjunta]', mediaUrl: url, mediaType: 'image');

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

  void _sendAudio(int durationMs, Uint8List bytes, String filename) {
    _send('🎤 [Nota de voz (${durationMs ~/ 1000}s)]');
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

  void _openUserProfile(BuildContext context, ChatAuthor? member) {
    if (member == null) return;
    HapticFeedback.lightImpact();
    RoomUserProfileSheet.show(
      context,
      displayName: member.displayName.isNotEmpty
          ? member.displayName
          : member.username,
      username: member.username,
      userId: member.id,
      avatarUrl: member.avatarUrl,
      isOnline: member.isOnline,
      onViewProfile: () {
        if (member.username.isNotEmpty) {
          context.push('/profile/${member.username}');
        }
      },
    );
  }

  int _calculateStreakFromMessages(List<Message> messages) {
    if (messages.isEmpty) return 0;
    final daysSet = <String>{};
    for (final m in messages) {
      if (m.isDeleted) continue;
      final d = m.createdAt.toLocal();
      daysSet.add(
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
      );
    }
    if (daysSet.isEmpty) return 0;
    final now = DateTime.now();
    var current = DateTime(now.year, now.month, now.day);
    var checkStr =
        '${current.year}-${current.month.toString().padLeft(2, '0')}-${current.day.toString().padLeft(2, '0')}';

    if (!daysSet.contains(checkStr)) {
      current = current.subtract(const Duration(days: 1));
      checkStr =
          '${current.year}-${current.month.toString().padLeft(2, '0')}-${current.day.toString().padLeft(2, '0')}';
      if (!daysSet.contains(checkStr)) {
        return 0;
      }
    }

    int streak = 0;
    while (daysSet.contains(checkStr)) {
      streak++;
      current = current.subtract(const Duration(days: 1));
      checkStr =
          '${current.year}-${current.month.toString().padLeft(2, '0')}-${current.day.toString().padLeft(2, '0')}';
    }
    return streak;
  }

  Widget _buildStreakBadge(
    BuildContext context, {
    required int streakDays,
    required int streakLevel,
    required String streakIcon,
  }) {
    return Tooltip(
      message: 'Racha de amistad: $streakDays días (Nivel $streakLevel)',
      triggerMode: TooltipTriggerMode.longPress,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.lightImpact();
          _showStreakModal(
            context,
            streakDays: streakDays,
            streakLevel: streakLevel,
            streakIcon: streakIcon,
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFFA594F9).withValues(alpha: 0.22),
                const Color(0xFF6C5CE7).withValues(alpha: 0.12),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFA594F9).withValues(alpha: 0.45),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                streakIcon,
                width: 20,
                height: 20,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 4),
              Text(
                '$streakDays d',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFF1E6FF),
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showStreakModal(
    BuildContext context, {
    required int streakDays,
    required int streakLevel,
    required String streakIcon,
  }) {
    final title = AppFriendshipIcons.titleForLevel(streakLevel);
    final nextDays = AppFriendshipIcons.daysUntilNextLevel(streakDays);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF14141E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(color: Color(0x33A594F9), width: 1),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFA594F9).withValues(alpha: 0.35),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Center(
                  child: Image.asset(
                    streakIcon,
                    width: 60,
                    height: 60,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Racha de amistad: $streakDays días (Nivel $streakLevel)',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFA594F9),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E172F),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.local_fire_department_rounded,
                          color: Color(0xFFFF6584),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '$streakDays días consecutivos enviándose mensajes',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (nextDays != null) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(
                            Icons.trending_up_rounded,
                            color: Color(0xFF5BC8AF),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Faltan $nextDays días para desbloquear el Nivel ${streakLevel + 1}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF5BC8AF),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      const SizedBox(height: 10),
                      const Row(
                        children: [
                          Icon(
                            Icons.workspace_premium_rounded,
                            color: Color(0xFFFFD700),
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '¡Han alcanzado el nivel máximo de racha de amistad!',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFFFFD700),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFA594F9),
                    foregroundColor: const Color(0xFF0F0A1E),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: const Text(
                    'Entendido',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
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
    final other = conversation?.otherMember;
    final displayName =
        other?.displayName ?? conversation?.displayName ?? 'Conversación';
    final username = other?.username ?? 'usuario';
    final avatarUrl = other?.avatarUrl ?? conversation?.avatarUrl;
    final isOnline = other?.isOnline ?? false;
    final myId = ref.watch(authControllerProvider).user?.id ?? '';

    final rawStreak = conversation?.streakDays ?? 0;
    final streakDays = rawStreak > 0
        ? rawStreak
        : _calculateStreakFromMessages(state.messages);
    final streakIcon = AppFriendshipIcons.iconForStreakDays(streakDays);
    final streakLevel = AppFriendshipIcons.levelForStreakDays(streakDays);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFF0A0912),
      appBar: AppBar(
        backgroundColor: const Color(0xFF12101C),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/app/messages');
            }
          },
        ),
        titleSpacing: 0,
        title: GestureDetector(
          onTap: () => _openUserProfile(context, other),
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: [
              // Avatar con Halo y estado online
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isOnline
                            ? AppColors.accentTeal
                            : const Color(0xFF2C2542),
                        width: 1.5,
                      ),
                      boxShadow: isOnline
                          ? [
                              BoxShadow(
                                color: const Color(
                                  0xFF00E676,
                                ).withValues(alpha: 0.3),
                                blurRadius: 6,
                              ),
                            ]
                          : null,
                    ),
                    child: AppAvatar(
                      imageUrl: avatarUrl,
                      name: displayName,
                      radius: 19,
                      showOnline: false,
                    ),
                  ),
                  if (isOnline)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: AppColors.accentTeal,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF12101C),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                        if (streakDays >= 1 && streakIcon != null) ...[
                          const SizedBox(width: 6),
                          _buildStreakBadge(
                            context,
                            streakDays: streakDays,
                            streakLevel: streakLevel,
                            streakIcon: streakIcon,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 1.5),
                    if (state.typingUsers.isNotEmpty)
                      const Text(
                        'escribiendo...',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.accentCyan,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    else if (isOnline)
                      Text(
                        '@$username · 🟢 En línea',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.accentTeal,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    else
                      Text(
                        '@$username · Últ. vez reciente',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white70),
            onPressed: () => _showOptions(conversation),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Fondo de pantalla personalizado Jay Sen
          if (_chatBgAsset != null && _chatBgAsset!.isNotEmpty) ...[
            Positioned.fill(
              child: Image.asset(
                _chatBgAsset!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
            Positioned.fill(
              child: Container(
                color: const Color(0xCC0A0912), // Overlay oscuro translúcido
              ),
            ),
          ],
          Column(
            children: [
              // ── Feed de Mensajes / Chat Flow ──
              Expanded(child: _buildBody(state, myId, other)),

              // ── Barra de Entrada (Input Composer) ──
              SafeArea(top: false, bottom: true, child: _buildComposer(state)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    ConversationChatState state,
    String myId,
    ChatAuthor? otherMember,
  ) {
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

    final showLoader = state.hasMore;

    // Construcción de items en orden cronológico inverso para reverse: true
    final items = <_ChatItem>[];
    final messages = state.messages;
    for (var i = messages.length - 1; i >= 0; i--) {
      final current = messages[i];
      items.add(_ChatItem.message(current));

      // Si es el mensaje más antiguo o cambia de día respecto al anterior, agregamos el separador
      if (i == 0 || !_sameDay(current.createdAt, messages[i - 1].createdAt)) {
        items.add(_ChatItem.date(current.createdAt));
      }
    }

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
        final isMine = message.senderId == myId;

        return _DirectMessageBubble(
          body: message.body,
          timestamp: _timeLabel(message.createdAt),
          isMine: isMine,
          senderName: message.sender.displayName,
          avatarUrl: message.sender.avatarUrl,
          media: message.media,
          mediaUrl: message.mediaUrl,
          mediaType: message.mediaType,
          isDeleted: message.isDeleted,
          onAvatarTap: () => _openUserProfile(context, message.sender),
        );
      },
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
      onTypingChanged: (typing) {
        if (typing) {
          ref
              .read(conversationChatProvider(widget.conversationId).notifier)
              .sendTyping();
        }
      },
    );
  }

  void _showOptions(Conversation? conversation) {
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
              leading: const Icon(
                Icons.person_outline_rounded,
                color: Colors.white70,
              ),
              title: const Text(
                'Ver perfil',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                final username = conversation.otherMember?.username;
                if (username != null && username.isNotEmpty) {
                  context.push('/profile/$username');
                }
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.wallpaper_rounded,
                color: Colors.white70,
              ),
              title: const Text(
                'Fondo de pantalla',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: const Text(
                'Gradientes atmosféricos Jay Sen',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 12,
                ),
              ),
              onTap: () async {
                Navigator.pop(context);
                final selected = await showRoomBackgroundSelector(
                  context,
                  currentAsset: _chatBgAsset,
                  title: 'Fondo del Chat',
                );
                if (selected != null) {
                  final prefs = await SharedPreferences.getInstance();
                  if (selected.id == 'default' || selected.assetPath.isEmpty) {
                    await prefs.remove('chat_bg_${widget.conversationId}');
                    if (mounted) setState(() => _chatBgAsset = null);
                  } else {
                    await prefs.setString(
                      'chat_bg_${widget.conversationId}',
                      selected.assetPath,
                    );
                    if (mounted) setState(() => _chatBgAsset = selected.assetPath);
                  }
                }
              },
            ),
            ListTile(
              leading: Icon(
                conversation.muted
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_off_rounded,
                color: Colors.white70,
              ),
              title: Text(
                conversation.muted
                    ? 'Activar notificaciones'
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
                color: Color(0xFF9B6FCB),
              ),
              title: const Text(
                'Eliminar conversación',
                style: TextStyle(
                  color: Color(0xFF9B6FCB),
                  fontWeight: FontWeight.w700,
                ),
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

/// Burbuja moderna y pulida de Mensaje Directo (Ref: Requerimiento de DMs).
class _DirectMessageBubble extends StatelessWidget {
  const _DirectMessageBubble({
    required this.body,
    required this.timestamp,
    required this.isMine,
    required this.senderName,
    this.avatarUrl,
    this.media,
    this.mediaUrl,
    this.mediaType,
    this.isDeleted = false,
    this.onAvatarTap,
  });

  final String body;
  final String timestamp;
  final bool isMine;
  final String senderName;
  final String? avatarUrl;
  final Media? media;
  final String? mediaUrl;
  final String? mediaType;
  final bool isDeleted;
  final VoidCallback? onAvatarTap;

  /// Renderiza la imagen del mensaje si la hay (media o mediaUrl de tipo
  /// imagen). Tap abre el visor a pantalla completa con `BoxFit.contain`.
  Widget? _buildImage(BuildContext context) {
    final url = media?.url ?? mediaUrl;
    if (url == null || url.isEmpty) return null;
    final type = media?.type ?? MediaType.fromValue(mediaType);
    if (type != MediaType.image) return null;
    return GestureDetector(
      onTap: () => showFullscreenImage(context, url),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: CachedNetworkImage(
          imageUrl: url,
          width: 200,
          height: 220,
          fit: BoxFit.cover,
          placeholder: (_, _) => Container(
            width: 200,
            height: 220,
            color: Colors.black26,
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          errorWidget: (_, _, _) => Container(
            width: 200,
            height: 220,
            color: Colors.black26,
            child: const Icon(
              Icons.broken_image_outlined,
              color: Colors.white54,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final image = _buildImage(context);

    if (isMine) {
      // ── Mensaje Propio: Fondo morado noche calmo (#231B38), alineado a la derecha ──
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              constraints: BoxConstraints(maxWidth: screenWidth * 0.78),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFF231B38),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(4),
                ),
                border: Border.all(
                  color: const Color(0xFF9E8CD9).withValues(alpha: 0.35),
                  width: 0.9,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF9B6FCB).withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (isDeleted)
                    const Text(
                      'Mensaje eliminado',
                      style: TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: AppColors.textSecondary,
                      ),
                    )
                  else ...[
                    ?image,
                    if (body.trim().isNotEmpty)
                      _buildFormattedText(body, isMine: true),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        timestamp,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFD4A0B0),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.done_all_rounded,
                        size: 13,
                        color: Color(0xFF00E5FF),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // ── Mensaje Receptor: Fondo gris/azulado obsidiana (#14141E), alineado a la izquierda ──
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          GestureDetector(
            onTap: onAvatarTap,
            child: AppAvatar(imageUrl: avatarUrl, name: senderName, radius: 16),
          ),
          const SizedBox(width: 8),
          Container(
            constraints: BoxConstraints(maxWidth: screenWidth * 0.76),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: AppColors.surfaceCards,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(16),
              ),
              border: Border.all(color: const Color(0xFF2A2640), width: 0.9),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isDeleted)
                  const Text(
                    'Mensaje eliminado',
                    style: TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: AppColors.textSecondary,
                    ),
                  )
                else ...[
                  ?image,
                  if (body.trim().isNotEmpty)
                    _buildFormattedText(body, isMine: false),
                ],
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Text(
                    timestamp,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormattedText(String text, {required bool isMine}) {
    if (text.startsWith('**') && text.endsWith('**') && text.length > 4) {
      return Text(
        text.substring(2, text.length - 2),
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          height: 1.35,
          color: Colors.white,
        ),
      );
    } else if (text.startsWith('*') && text.endsWith('*') && text.length > 2) {
      return Text(
        text.substring(1, text.length - 1),
        style: const TextStyle(
          fontSize: 13.5,
          fontStyle: FontStyle.italic,
          height: 1.35,
          color: AppColors.accentCyan,
        ),
      );
    }
    return KyubiRichText(
      text: text,
      style: const TextStyle(fontSize: 14, height: 1.35, color: Colors.white),
    );
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

// ── Date separator helpers ──────────────────────────────────────────────

class _ChatItem {
  const _ChatItem.message(this.message) : isDate = false, date = null;
  const _ChatItem.date(this.date) : isDate = true, message = null;

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
