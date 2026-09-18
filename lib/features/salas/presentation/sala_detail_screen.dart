import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:gal/gal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/rules/room_permissions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/chat_animated_media.dart';
import '../../../../core/widgets/sticker_catalog.dart';
import '../../../../core/widgets/system_toast.dart';
import '../../../../models/role_character.dart';
import '../../../../models/room.dart';
import '../../../../services/auth_controller.dart';
import '../../../../services/providers.dart';
import '../../../../services/room_socket.dart';
import '../../../../services/voice/voice_room_controller.dart';
import '../../messages/presentation/conversations_controller.dart';
import '../../profile/presentation/user_follow_controller.dart';
import '../../roles/presentation/role_editor_screen.dart';
import '../../roles/presentation/widgets/role_info_modal.dart';
import '../../roles/presentation/role_library_screen.dart';
import 'edit_room_screen.dart';
import 'sala_detail_controller.dart';
import 'salas_controller.dart';
import 'widgets/chat_message_input_bar.dart';
import 'widgets/cinema_player_view.dart';
import 'widgets/live_voice_bar.dart';
import 'widgets/role_chat_bubble.dart';
import 'widgets/roleplay_stage_view.dart';
import 'widgets/room_invite_friends_sheet.dart';
import 'widgets/room_user_profile_sheet.dart';
import 'room_detail_info_screen.dart';

/// Pantalla Oficial de Sala en Vivo, Stage de Roleplay y Chat Inmersivo (Ref: image_992c3c.jpg).
class SalaDetailScreen extends ConsumerStatefulWidget {
  const SalaDetailScreen({
    super.key,
    required this.roomId,
    this.forceConnected = false,
  });

  final String roomId;

  /// Cuando es true (p. ej. el usuario creó la sala / es Host), entra
  /// directamente en modo conectado sin pasar por el estado previo "Join".
  final bool forceConnected;

  @override
  ConsumerState<SalaDetailScreen> createState() => _SalaDetailScreenState();
}

class _SalaDetailScreenState extends ConsumerState<SalaDetailScreen> {
  late bool _isConnected = widget.forceConnected;

  // Silenciar / Desilenciar participantes de la sala (toggle local).
  final Set<String> _mutedUserIds = {};
  // Guard anti doble-tap: evita alternar y emitir el system message dos veces.
  bool _mutePending = false;

  // Personalización visual de la sala
  String? _roomCoverUrl;
  String? _roomBgUrl;
  Color _themeColor = const Color(0xFF00E5FF);

  // Fondo por defecto del chat, usado solo si no hay ninguno persistido.
  static const String _defaultBgUrl =
      'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=800&auto=format&fit=crop&q=60';

  /// Fondo efectivo del chat: el editado localmente o, si no, el persistido
  /// en el backend (`room.chatBackgroundUrl`) y, en última instancia, el default.
  String? get _effectiveBgUrl =>
      _roomBgUrl ?? _currentRoom?.chatBackgroundUrl ?? _defaultBgUrl;

  /// Portada efectiva: la editada localmente o la persistida (`room.imageUrl`).
  String? get _effectiveCoverUrl =>
      _roomCoverUrl ?? _currentRoom?.imageUrl;

  // Rol activo del usuario local
  RoleCharacter? _currentActiveRole;
  String _currentRoomMode =
      'standard'; // 'roleplay', 'voice', 'screening', 'standard'

  // Control local de minimizar/expandir las actividades activas superiores
  bool _isStageMinimized = false;
  bool _isVoiceMinimized = false;
  bool _isRoleplayMinimized = false;

  // Debounce para cambios y toggles de actividad (evita rebotes y condiciones de carrera)
  bool _isSwitchingActivity = false;
  Timer? _activityDebounceTimer;

  void _triggerActivityDebounce() {
    _isSwitchingActivity = true;
    _activityDebounceTimer?.cancel();
    _activityDebounceTimer = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _isSwitchingActivity = false);
    });
  }

  // Restricción de voz a Solo Staff y lista de oradores autorizados
  bool _voiceStaffOnly = false;
  final Set<String> _allowedVoiceSpeakerIds = {};

  // Roles en escena en el stage superior.
  // Se derivan de `room.participants` (usuarios reales subidos al stage).
  List<RoleCharacter> _stageRoles = [];
  String? _syncedRoomId;

  // Historial de mensajes: persistencia en sesión vía SalasNotifier.
  SalasNotifier get _salas => ref.read(salasControllerProvider.notifier);

  List<Map<String, dynamic>> get _messages => _salas.messagesFor(widget.roomId);

  // Cita / Reply activo y Edición activa
  Map<String, dynamic>? _replyingToMessage;
  Map<String, dynamic>? _editingMessage;

  final ScrollController _scrollController = ScrollController();

  // Guard anti doble-solicitud y para no navegar dos veces al salir.
  bool _leaving = false;

  // Guard anti doble-solicitud para verificación de acceso.
  bool _accessChecked = false;

  // ── Chat en vivo: historial del backend + eventos Socket.IO ─────────
  // Controla la carga del historial previo al entrar y la escucha en vivo
  // de mensajes nuevos SIN duplicados (guarda por estado + dedup por id).
  StreamSubscription<RoomSocketEvent>? _chatSub;
  bool _chatStarted = false;
  bool _historyLoaded = false;

  // Guard anti doble-envío: evita duplicados optimistas al tocar enviar varias
  // veces seguidas o mientras se sube un archivo multimedia.
  bool _sendingMedia = false;

  // Pausa de emojis animados del chat: activa mientras el usuario está
  // escribiendo (foco en la barra de input) o el chat pierde el foco.
  final ValueNotifier<bool> _chatAnimationsEnabled = ValueNotifier<bool>(true);

  // Control reactivo de moderación: bloquea envío de mensajes si la cuenta
  // ha sido silenciada o sancionada en tiempo real.
  bool _canSendMessage = true;
  String? _sanctionBannerText;

  @override
  void initState() {
    super.initState();
    _chatSub = ref.read(roomSocketProvider).events.listen(_onRoomSocketEvent);
    // El socket de sala SIEMPRE debe conectarse y unirse a la sala al entrar,
    // independientemente de quién sea (host o espectador). Sin esto, los
    // cambios de modo/mensajes no se propagan entre clientes.
    debugPrint('[SOCKET_DEBUG] Intentando conectar e ingresar a sala: ${widget.roomId}');
    Future.microtask(_startRoomChat);

    // Sincronización inicial declarativa desde el estado ya disponible en memoria/cache
    Future.microtask(() {
      if (!mounted) return;
      final currentRoom =
          ref.read(salaDetailControllerProvider(widget.roomId)).room;
      if (currentRoom != null) {
        _syncStageFromRoom(currentRoom);
        if (currentRoom.currentMode != _currentRoomMode) {
          _applyRoomMode(currentRoom.currentMode, notifyToast: false);
        }
      }
    });
  }

  @override
  void dispose() {
    _chatSub?.cancel();
    _activityDebounceTimer?.cancel();
    RoomSocketService.instance.leaveRoom(widget.roomId);
    final voiceState = ref.read(voiceRoomProvider);
    if (voiceState.activeRoomId == widget.roomId) {
      ref.read(voiceRoomProvider.notifier).leaveRoom();
    }
    _scrollController.dispose();
    _chatAnimationsEnabled.dispose();
    super.dispose();
  }

  /// Conecta el socket, se une a la sala y carga el historial previo.
  Future<void> _startRoomChat() async {
    if (_chatStarted || !mounted) return;
    _chatStarted = true;
    final socket = ref.read(roomSocketProvider);
    debugPrint('[SOCKET_DEBUG] Estado actual de conexión: ${socket.isConnected}');
    try {
      await socket.connect();
    } catch (_) {
      // Sin conexión: el chat sigue funcionando en modo local.
    }
    if (!mounted) return;
    socket.joinRoom(widget.roomId);
    await _loadHistory();
  }

  /// Carga los últimos mensajes del backend (`sort=asc`) y los fusiona en la
  /// lista de la sala. Solo se ejecuta una vez por sesión de pantalla.
  Future<void> _loadHistory() async {
    if (_historyLoaded || !mounted) return;
    _historyLoaded = true;
    try {
      final page = await ref
          .read(roomRepositoryProvider)
          .getRoomMessages(widget.roomId, sort: 'asc');
      if (!mounted) return;
      _salas.seedRoomMessages(widget.roomId, page.messages);
      setState(() {});
      _scrollToBottom();
    } catch (_) {
      // Backend caído/sin conexión: se conservan solo los mensajes de sesión.
    }
  }

  /// Escucha en vivo de mensajes de la sala (sin duplicados gracias a la
  /// deduplicación por id de [SalasNotifier.ingestRoomMessage]).
  void _onRoomSocketEvent(RoomSocketEvent event) {
    if (!mounted) return;
    if (event is RoomMessageReceived && event.roomId == widget.roomId) {
      _salas.ingestRoomMessage(
        widget.roomId,
        RoomChatMessage.fromJson(event.payload),
      );
      setState(() {});
      _scrollToBottom();
      return;
    }
    if (event is RoomMessageUpdated && event.roomId == widget.roomId) {
      _salas.updateRoomMessage(
        widget.roomId,
        event.messageId,
        content: event.content,
        isEdited: event.isEdited,
        editedAt: event.editedAt,
      );
      setState(() {});
      return;
    }
    if (event is RoomMessageDeleted && event.roomId == widget.roomId) {
      _salas.deleteRoomMessage(
        widget.roomId,
        event.messageId,
      );
      setState(() {});
      return;
    }
    if (event is RoomCinemaSync && event.roomId == widget.roomId) {
      final currentRoom = _currentRoom;
      if (currentRoom != null) {
        final action = event.action.toUpperCase();
        final isClear = action == 'CLEAR' ||
            action == 'REMOVE' ||
            (event.videoId == null && action == 'STOP');
        final updatedRoom = currentRoom.copyWith(
          clearCinemaVideo: isClear,
          cinemaVideoId: isClear ? null : (event.videoId ?? currentRoom.cinemaVideoId),
          cinemaState: isClear
              ? 'STOPPED'
              : (action == 'LOAD' || action == 'PLAY'
                  ? 'PLAYING'
                  : (action == 'PAUSE'
                      ? 'PAUSED'
                      : (action == 'STOP' ? 'STOPPED' : currentRoom.cinemaState))),
          cinemaCurrentTime: isClear ? 0 : event.currentTime,
        );
        ref
            .read(salaDetailControllerProvider(widget.roomId).notifier)
            .applyRoom(updatedRoom);
      }
      return;
    }
    if (event is RoomModeChanged && event.roomId == widget.roomId) {
      debugPrint('[MODE_DEBUG_FRONT] Recibido room:mode_changed: ${event.payload}');
      _handleRemoteModeChanged(event);
      return;
    }
    if (event is RoomModeRejected && event.roomId == widget.roomId) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(event.reason.isNotEmpty
                ? event.reason
                : 'Debes finalizar la actividad actual antes de iniciar otra'),
            backgroundColor: const Color(0xFF2A121E),
          ),
        );
      }
      return;
    }
    if (event is RoomRateLimited) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.timer_outlined, color: Colors.amberAccent, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    event.message,
                    style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF2A121E),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: Duration(
              milliseconds: event.retryAfterMs > 0 ? event.retryAfterMs + 1000 : 2500,
            ),
          ),
        );
      }
      return;
    }
    if (event is RoomVoiceModerated && event.roomId == widget.roomId) {
      _handleVoiceModeration(event);
      return;
    }
    if (event is RoomStageRoleChanged && event.roomId == widget.roomId) {
      final myId = ref.read(authControllerProvider).user?.id;
      if (event.stageRoles != null) {
        final roles = event.stageRoles!
            .map((e) => e is Map
                ? RoleCharacter.fromJson(Map<String, dynamic>.from(e))
                : null)
            .whereType<RoleCharacter>()
            .where((r) => r.isValid)
            .toList();
        setState(() {
          _stageRoles = roles;
          _salas.setRoomRoles(widget.roomId, roles);
          if (event.action == 'delete') {
            final deletedId = event.roleId?.toString().trim() ?? '';
            if (deletedId.isNotEmpty) {
              _salas.removeRoomRole(widget.roomId, deletedId);
            }
            if (_currentActiveRole != null &&
                (_currentActiveRole!.id.toString().trim() == deletedId ||
                    !_stageRoles.any((r) =>
                        r.id.toString().trim() ==
                        _currentActiveRole!.id.toString().trim()))) {
              _currentActiveRole = null;
            }
          } else if (event.action == 'leave') {
            if (event.userId == myId ||
                event.roleId == _currentActiveRole?.id ||
                !_stageRoles.any((r) => r.isTaken && r.takenByUserId == myId)) {
              _currentActiveRole = null;
            }
          } else if (event.action == 'take') {
            if (event.userId == myId && event.role != null) {
              _currentActiveRole = RoleCharacter.fromJson(event.role!);
            }
          }
        });
      } else {
        setState(() {
          if (event.action == 'delete') {
            final deletedId = event.roleId?.toString().trim() ?? '';
            if (deletedId.isNotEmpty) {
              _salas.removeRoomRole(widget.roomId, deletedId);
              _stageRoles = _stageRoles
                  .where((r) => r.id.toString().trim() != deletedId)
                  .toList();
            }
            if (_currentActiveRole != null &&
                _currentActiveRole!.id.toString().trim() == deletedId) {
              _currentActiveRole = null;
            }
          } else if (event.action == 'leave') {
            if (event.userId == myId || event.roleId == _currentActiveRole?.id) {
              _currentActiveRole = null;
            }
          } else if (event.action == 'take') {
            if (event.userId == myId && event.role != null) {
              _currentActiveRole = RoleCharacter.fromJson(event.role!);
            }
          }
        });
      }
      return;
    }
    if (event is RoomPollVoted && event.roomId == widget.roomId) {
      final myId = ref.read(authControllerProvider).user?.id;
      final isMyVote = event.userId == myId;
      _salas.updatePollResults(
        widget.roomId,
        messageId: event.messageId,
        options: event.options ?? const [],
        totalVotes: event.totalVotes ?? 0,
        voteCounts: event.voteCounts,
        userVotedOptionId: isMyVote ? event.optionId : null,
      );
      setState(() {});
      return;
    }
    if (event is RoomAccountSanctioned) {
      if (event.isSessionKilling) {
        _handleForcedSanctionExit(
          reason: event.reason,
          suspendedUntil: event.suspendedUntil,
          isBan: event.action == 'BAN',
        );
      } else {
        setState(() {
          if (event.action == 'MUTE') {
            _canSendMessage = false;
            _sanctionBannerText = 'Tu cuenta ha sido silenciada por moderación.';
          }
        });
        _salas.clearLocalRoomMessages(widget.roomId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                event.action == 'MUTE'
                    ? 'Tu cuenta ha sido silenciada por moderación.'
                    : 'Aviso de moderación: ${event.reason}',
              ),
              backgroundColor: const Color(0xFF2A121E),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
      return;
    }
    if (event is RoomErrorSanctioned) {
      setState(() {
        _canSendMessage = false;
        _sanctionBannerText = event.message;
      });
      _salas.clearLocalRoomMessages(widget.roomId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(event.message),
            backgroundColor: const Color(0xFF2A121E),
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return;
    }
    if (event is RoomForceDisconnect) {
      final isBan = event.reason.toLowerCase().contains('ban');
      _handleForcedSanctionExit(
        reason: event.reason,
        isBan: isBan,
      );
      return;
    }
  }

  /// Maneja la expulsión forzada por suspensión o baneo de la cuenta.
  /// Abandona la sala de inmediato y muestra un diálogo explicativo no cancelable.
  Future<void> _handleForcedSanctionExit({
    required String reason,
    DateTime? suspendedUntil,
    bool isBan = false,
  }) async {
    if (!mounted) return;
    setState(() {
      _canSendMessage = false;
      _sanctionBannerText = reason;
    });
    _salas.clearLocalRoomMessages(widget.roomId);

    final navContext = Navigator.of(context, rootNavigator: true).context;

    // Salir de la sala automáticamente
    await _leaveRoom();

    if (!navContext.mounted) return;

    await showDialog<void>(
      context: navContext,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0x33FF4D6D)),
        ),
        title: Row(
          children: [
            Icon(
              isBan ? Icons.gavel_rounded : Icons.pause_circle_filled_rounded,
              color: const Color(0xFFFF4D6D),
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isBan
                    ? 'Cuenta suspendida'
                    : 'Cuenta temporalmente suspendida',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              reason.isNotEmpty
                  ? reason
                  : 'Tu cuenta ha sido suspendida por el equipo de moderación.',
              style: const TextStyle(fontSize: 14, color: Color(0xFFCCCCD4)),
            ),
            if (suspendedUntil != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0x14FF4D6D),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Tiempo restante hasta: ${suspendedUntil.toLocal().toString().substring(0, 16)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFFF8A9D),
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogCtx).pop();
            },
            child: const Text(
              'Entendido',
              style: TextStyle(
                color: Color(0xFFA594F9),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Un host/co-host remoto cambió el modo de la sala (`room:mode_changed`):
  /// se aplica el nuevo modo y se muestra un toast de sistema coherente con
  /// la transición (activación o fin de voice / roleplay / cine).
  void _handleRemoteModeChanged(RoomModeChanged event) {
    final myId = ref.read(authControllerProvider).user?.id ?? '';
    final isMyChange = event.actorId != null &&
        event.actorId!.isNotEmpty &&
        event.actorId == myId;
    final normalized = RoomSocketService.normalizeMode(event.mode);
    final previous = _currentRoomMode;
    if (normalized == previous && !isMyChange) return;
    _applyRoomMode(
      normalized,
      cinemaVideoId: event.cinemaVideoId,
      cinemaState: event.cinemaState,
      cinemaCurrentTime: event.cinemaCurrentTime,
      notifyToast: !isMyChange,
    );
    if (normalized == 'voice') {
      // Al re-entrar en voz se limpia el mute local residual.
      ref.read(voiceRoomProvider.notifier).setRemoteMuted('', muted: false);
    } else if (previous == 'voice' || normalized == 'standard') {
      final voice = ref.read(voiceRoomProvider);
      if (voice.isConnected || voice.isConnecting) {
        ref.read(voiceRoomProvider.notifier).leaveVoice();
      }
    }
  }

  /// Aplica localmente un modo de sala (sin re-emitir). Centraliza estado,
  /// identidad activa y muestra un toast informativo.
  void _applyRoomMode(
    String mode, {
    String? cinemaVideoId,
    String? cinemaState,
    double? cinemaCurrentTime,
    bool notifyToast = true,
  }) {
    final normalized = RoomSocketService.normalizeMode(mode);
    final previous = _currentRoomMode;
    if (_currentRoomMode != normalized) {
      setState(() {
        _currentRoomMode = normalized;
        if (normalized != 'roleplay') {
          _currentActiveRole = null;
        }
        if (normalized == 'roleplay') {
          _isRoleplayMinimized = false;
          _isVoiceMinimized = true;
          _isStageMinimized = false;
        } else if (normalized == 'voice') {
          _isVoiceMinimized = false;
          _isRoleplayMinimized = true;
          _isStageMinimized = false;
        } else if (normalized == 'screening') {
          _isVoiceMinimized = true;
          _isRoleplayMinimized = true;
          _isStageMinimized = false;
        } else {
          _isStageMinimized = false;
        }
      });
      _syncActiveIdentityForMode(normalized);
    }
    final currentRoom = _currentRoom;
    if (currentRoom != null) {
      final isClearCinema = normalized != 'screening';
      final updatedRoom = currentRoom.copyWith(
        currentMode: normalized,
        clearCinemaVideo: isClearCinema,
        cinemaVideoId:
            isClearCinema ? null : (cinemaVideoId ?? currentRoom.cinemaVideoId),
        cinemaState: isClearCinema
            ? 'STOPPED'
            : (cinemaState ?? currentRoom.cinemaState),
        cinemaCurrentTime: isClearCinema
            ? 0.0
            : (cinemaCurrentTime ?? currentRoom.cinemaCurrentTime),
      );
      ref
          .read(salaDetailControllerProvider(widget.roomId).notifier)
          .applyRoom(updatedRoom);
      ref.read(salasControllerProvider.notifier).applyRoom(updatedRoom);
    }
    // Toast en vivo cada vez que el modo cambia (local o remoto).
    if (notifyToast && mounted && previous != normalized) {
      showSystemToast(
        context,
        emoji: _modeEmoji(normalized),
        message: _modeToastMessage(previous, normalized),
        accentColor: _modeAccent(normalized),
      );
    }
  }

  /// Cierra la actividad activa (voz / cine / roleplay) y vuelve a chat
  /// estándar. Si hay una sesión de voz activa, desconecta LiveKit de inmediato.
  Future<void> _turnOffActivity() async {
    if (!_canManageRoles()) return;
    final voice = ref.read(voiceRoomProvider);
    if (_currentRoomMode == 'voice' || voice.isConnected || voice.isConnecting) {
      await ref.read(voiceRoomProvider.notifier).leaveVoice();
    }
    if (!mounted) return;
    _applyRoomMode('standard');
    ref.read(roomRepositoryProvider).updateRoomMode(
      widget.roomId,
      'standard',
    ).then((updated) {
      if (!mounted) return;
      ref
          .read(salaDetailControllerProvider(widget.roomId).notifier)
          .applyRoom(updated);
      ref.read(salasControllerProvider.notifier).applyRoom(updated);
    }).catchError((err) {
      debugPrint('[MODE_DEBUG] Error en _turnOffActivity updateRoomMode HTTP: $err');
    });
  }

  /// Emoji de cabecera para el toast según el modo.
  String _modeEmoji(String mode) {
    switch (mode) {
      case 'voice':
        return '🎙️';
      case 'roleplay':
        return '🎭';
      case 'screening':
        return '🎬';
      default:
        return '💬';
    }
  }

  /// Color de acento del toast según el modo.
  Color _modeAccent(String mode) {
    switch (mode) {
      case 'voice':
        return AppColors.accentTeal;
      case 'roleplay':
        return const Color(0xFFFFD600);
      case 'screening':
        return AppColors.accentPurple;
      default:
        return AppColors.accentTeal;
    }
  }

  /// Texto descriptivo de la transición (modo nuevo o apagado del anterior).
  String _modeToastMessage(String previous, String mode) {
    if (mode == 'standard') {
      switch (previous) {
        case 'voice':
          return 'Chat de voz apagado';
        case 'roleplay':
          return 'Modo Roleplay desactivado';
        case 'screening':
          return 'Sala de cine finalizada';
        default:
          return 'Actividad finalizada';
      }
    }
    switch (mode) {
      case 'voice':
        return 'Chat de voz activado';
      case 'roleplay':
        return 'Modo Roleplay activado';
      case 'screening':
        return 'Sala de cine iniciada';
      default:
        return 'Modo actualizado';
    }
  }

  /// Resultado de un `room:voice_moderated` del servidor de salas
  /// (mute/unmute/kick/staff_only/allow_speaker/revoke_speaker).
  void _handleVoiceModeration(RoomVoiceModerated event) {
    final myId = ref.read(authControllerProvider).user?.id ?? '';
    final voice = ref.read(voiceRoomProvider.notifier);
    final isSelf = event.targetUserId == myId;
    switch (event.action) {
      case 'staff_only':
        final isStaffOnly = event.staffOnly ?? false;
        setState(() {
          _voiceStaffOnly = isStaffOnly;
        });
        if (isStaffOnly &&
            !_canManageRoles() &&
            !_allowedVoiceSpeakerIds.contains(myId)) {
          voice.setMic(false);
        }
        showSystemToast(
          context,
          emoji: isStaffOnly ? '🔒' : '🔓',
          message: isStaffOnly
              ? 'Chat de voz restringido: Solo Staff y oradores autorizados'
              : 'Chat de voz abierto a todos los participantes',
          accentColor:
              isStaffOnly ? const Color(0xFFFFB300) : AppColors.accentTeal,
        );
        break;
      case 'allow_speaker':
        if (event.targetUserId != null && event.targetUserId!.isNotEmpty) {
          setState(() {
            _allowedVoiceSpeakerIds.add(event.targetUserId!);
          });
        }
        if (isSelf) {
          showSystemToast(
            context,
            emoji: '🎙️',
            message: 'Se te ha otorgado permiso para hablar en el canal de voz',
            accentColor: AppColors.success,
          );
        } else {
          final name = (event.targetName?.isNotEmpty ?? false)
              ? event.targetName!
              : 'Un usuario';
          showSystemToast(
            context,
            emoji: '🎙️',
            message: '$name fue autorizado/a como orador/a',
            accentColor: AppColors.accentTeal,
          );
        }
        break;
      case 'revoke_speaker':
        if (event.targetUserId != null && event.targetUserId!.isNotEmpty) {
          setState(() {
            _allowedVoiceSpeakerIds.remove(event.targetUserId!);
          });
        }
        if (isSelf) {
          if (_voiceStaffOnly && !_canManageRoles()) {
            voice.setMic(false);
          }
          showSystemToast(
            context,
            emoji: '🔇',
            message: 'Se ha revocado tu permiso de orador/a',
            accentColor: AppColors.danger,
          );
        }
        break;
      case 'mute':
        if (isSelf) {
          voice.setMic(false);
          showSystemToast(
            context,
            emoji: '🔇',
            message: 'Tu micrófono fue silenciado por el moderador',
            accentColor: AppColors.danger,
          );
        } else {
          voice.setRemoteMuted(event.targetUserId ?? '', muted: true);
        }
        break;
      case 'unmute':
        if (isSelf) {
          showSystemToast(
            context,
            emoji: '🎙️',
            message: 'Tu micrófono fue reactivado',
            accentColor: AppColors.success,
          );
        } else {
          voice.setRemoteMuted(event.targetUserId ?? '', muted: false);
        }
        break;
      case 'kick':
        if (isSelf) {
          voice.leaveRoom();
          showSystemToast(
            context,
            emoji: '🚫',
            message: 'Has sido expulsado/a del canal de voz',
            accentColor: AppColors.danger,
          );
        } else {
          final name =
              (event.targetName?.isNotEmpty ?? false) ? event.targetName! : 'Un usuario';
          showSystemToast(
            context,
            emoji: '🚪',
            message: '$name fue expulsado/a del canal de voz',
            accentColor: AppColors.danger,
          );
        }
        break;
    }
  }

  /// Aplica una acción de moderación local (el Host/Co-Host toca el sheet):
  /// emite al servidor de salas para el mute remoto y refleja el estado.
  void _moderateVoice(String targetUserId, String targetUsername, String action) {
    ref.read(roomSocketProvider).emitVoiceModeration(
          roomId: widget.roomId,
          action: action,
          targetUserId: targetUserId,
          targetUsername: targetUsername,
        );
    ref
        .read(voiceRoomProvider.notifier)
        .setRemoteMuted(targetUserId, muted: action == 'mute');
    final message = switch (action) {
      'mute' => '$targetUsername silenciado/a en el canal de voz',
      'unmute' => '$targetUsername puede volver a hablar',
      'kick' => '$targetUsername fue expulsado/a del canal de voz',
      _ => 'Acción enviada',
    };
    showSystemToast(
      context,
      emoji: switch (action) {
        'mute' => '🔇',
        'unmute' => '🎙️',
        _ => '🚪',
      },
      message: message,
      accentColor: action == 'kick' ? AppColors.danger : AppColors.accentTeal,
    );
  }

  // ── Modales de Configuración de Actividades para Staff ──────────────────────

  /// Modal de configuración del Chat de Voz (Solo Staff y Oradores Autorizados)
  void _openVoiceSettingsSheet() {
    if (!_canManageRoles()) return;
    final room = _currentRoom;
    final myId = ref.read(authControllerProvider).user?.id ?? '';
    final participants = room?.participants ?? const <RoomParticipant>[];
    final nonStaffParticipants = participants.where((p) {
      if (p.user.id == myId) return false;
      return !RoomPermissions.canManageRole(p.role);
    }).toList();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF14121F),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.75,
            ),
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3A3A4A),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.accentTeal.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.settings_voice_rounded,
                        color: AppColors.accentTeal,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ajustes de Chat de Voz',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Control de accesos y oradores (Solo Staff)',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Switch Solo Staff
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B1728),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF2C2542), width: 0.8),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Restringir a Solo Staff',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Solo Host, Admins y oradores autorizados podrán hablar',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _voiceStaffOnly,
                        activeThumbColor: AppColors.accentTeal,
                        activeTrackColor:
                            AppColors.accentTeal.withValues(alpha: 0.4),
                        inactiveThumbColor: const Color(0xFF8A8A9A),
                        inactiveTrackColor: const Color(0xFF28223C),
                        onChanged: (val) {
                          setSheetState(() => _voiceStaffOnly = val);
                          setState(() => _voiceStaffOnly = val);
                          ref.read(roomSocketProvider).emitVoiceModeration(
                                roomId: widget.roomId,
                                action: 'staff_only',
                                staffOnly: val,
                              );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Sección Oradores Autorizados
                const Text(
                  'Oradores Autorizados',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                if (nonStaffParticipants.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF181424),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text(
                        'No hay otros participantes en la sala actualmente',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF7A7A8A),
                        ),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: nonStaffParticipants.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (ctx, i) {
                        final p = nonStaffParticipants[i];
                        final isAllowed =
                            _allowedVoiceSpeakerIds.contains(p.user.id);
                        final displayName = p.user.displayName.isNotEmpty
                            ? p.user.displayName
                            : p.user.username;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF181424),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isAllowed
                                  ? AppColors.accentTeal
                                      .withValues(alpha: 0.5)
                                  : const Color(0xFF262038),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            children: [
                              AppAvatar(
                                imageUrl: p.user.avatarUrl,
                                name: displayName,
                                radius: 16,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      displayName,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      '@${p.user.username}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF7A7A8A),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  final newAllowed = !isAllowed;
                                  setSheetState(() {
                                    if (newAllowed) {
                                      _allowedVoiceSpeakerIds.add(p.user.id);
                                    } else {
                                      _allowedVoiceSpeakerIds
                                          .remove(p.user.id);
                                    }
                                  });
                                  setState(() {});
                                  ref
                                      .read(roomSocketProvider)
                                      .emitVoiceModeration(
                                        roomId: widget.roomId,
                                        action: newAllowed
                                            ? 'allow_speaker'
                                            : 'revoke_speaker',
                                        targetUserId: p.user.id,
                                        targetUsername: p.user.username,
                                      );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isAllowed
                                        ? AppColors.accentTeal
                                            .withValues(alpha: 0.15)
                                        : const Color(0xFF221C34),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isAllowed
                                          ? AppColors.accentTeal
                                          : const Color(0xFF382F52),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isAllowed
                                            ? Icons.mic_rounded
                                            : Icons.mic_off_rounded,
                                        size: 14,
                                        color: isAllowed
                                            ? AppColors.accentTeal
                                            : const Color(0xFF9A9AA8),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        isAllowed ? 'Autorizado' : 'Autorizar',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: isAllowed
                                              ? AppColors.accentTeal
                                              : const Color(0xFF9A9AA8),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Extrae el ID de 11 caracteres de un enlace o input de YouTube.
  String? _extractYoutubeVideoId(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;
    if (RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(trimmed)) {
      return trimmed;
    }
    final uri = Uri.tryParse(trimmed);
    if (uri != null) {
      if (uri.queryParameters.containsKey('v')) {
        final v = uri.queryParameters['v'];
        if (v != null && RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(v)) {
          return v;
        }
      }
      if (uri.host.contains('youtu.be') && uri.pathSegments.isNotEmpty) {
        final seg = uri.pathSegments.first;
        if (RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(seg)) {
          return seg;
        }
      }
      if (uri.pathSegments.contains('embed') ||
          uri.pathSegments.contains('shorts')) {
        final last = uri.pathSegments.last;
        if (RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(last)) {
          return last;
        }
      }
    }
    return null;
  }

  /// Diálogo para ingresar enlace o ID de YouTube y cargarlo a la sala.
  void _openCinemaLoadDialog() {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF161224),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFF2E2744), width: 0.8),
        ),
        title: const Row(
          children: [
            Icon(Icons.video_library_rounded,
                color: AppColors.accentPurple, size: 22),
            SizedBox(width: 8),
            Text(
              'Cargar Video',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ingresa el enlace de YouTube o el ID del video:',
              style: TextStyle(fontSize: 12.5, color: Color(0xFFC0C0D4)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white, fontSize: 13.5),
              decoration: InputDecoration(
                hintText: 'https://www.youtube.com/watch?v=...',
                hintStyle:
                    const TextStyle(color: Color(0xFF5A5570), fontSize: 12.5),
                filled: true,
                fillColor: const Color(0xFF1F1A30),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF332A50)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF332A50)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                      color: AppColors.accentPurple, width: 1.2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancelar',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final videoId = _extractYoutubeVideoId(controller.text);
              if (videoId == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Enlace de YouTube no válido'),
                    backgroundColor: Color(0xFF2A121E),
                  ),
                );
                return;
              }
              Navigator.pop(dialogCtx);
              ref.read(roomSocketProvider).emitCinemaAction(
                    roomId: widget.roomId,
                    action: 'LOAD',
                    videoId: videoId,
                  );
              final currentRoom = _currentRoom;
              if (currentRoom != null) {
                final updatedRoom = currentRoom.copyWith(
                  cinemaVideoId: videoId,
                  cinemaState: 'PLAYING',
                  cinemaCurrentTime: 0,
                );
                ref
                    .read(salaDetailControllerProvider(widget.roomId).notifier)
                    .applyRoom(updatedRoom);
              }
              showSystemToast(
                context,
                emoji: '🎬',
                message: 'Video cargado en la sala de cine',
                accentColor: AppColors.accentPurple,
              );
            },
            child: const Text('Cargar',
                style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  /// Modal de configuración de Sala de Cine para Staff
  void _openCinemaSettingsSheet() {
    if (!_canManageRoles()) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF14121F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3A3A4A),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.accentPurple.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.movie_filter_rounded,
                      color: AppColors.accentPurple,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ajustes de Sala de Cine',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Gestión y reproducción de video para Staff',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Opción 1: Cargar / Cambiar Video
              ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                tileColor: const Color(0xFF1B1728),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.accentPurple.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.video_library_rounded,
                      color: AppColors.accentPurple, size: 20),
                ),
                title: const Text(
                  'Cambiar / Añadir Video',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
                subtitle: const Text(
                  'Carga un video de YouTube para reproducir a la sala',
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 11),
                ),
                trailing: const Icon(Icons.chevron_right_rounded,
                    color: Color(0xFF5A5A6A)),
                onTap: () {
                  Navigator.pop(ctx);
                  _openCinemaLoadDialog();
                },
              ),
              const SizedBox(height: 10),

              // Opción 2: Quitar Video Actual
              ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                tileColor: const Color(0xFF1B1728),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.accentCrimson.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.highlight_off_rounded,
                      color: AppColors.accentCrimson, size: 20),
                ),
                title: const Text(
                  'Quitar Video Actual',
                  style: TextStyle(
                    color: AppColors.accentCrimson,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
                subtitle: const Text(
                  'Detiene la reproducción y limpia el reproductor',
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 11),
                ),
                trailing: const Icon(Icons.chevron_right_rounded,
                    color: Color(0xFF5A5A6A)),
                onTap: () {
                  Navigator.pop(ctx);
                  ref.read(roomSocketProvider).emitCinemaAction(
                        roomId: widget.roomId,
                        action: 'CLEAR',
                      );
                  final currentRoom = _currentRoom;
                  if (currentRoom != null) {
                    final updatedRoom = currentRoom.copyWith(
                      clearCinemaVideo: true,
                      cinemaVideoId: null,
                      cinemaState: 'STOPPED',
                      cinemaCurrentTime: 0,
                    );
                    ref
                        .read(
                            salaDetailControllerProvider(widget.roomId).notifier)
                        .applyRoom(updatedRoom);
                  }
                  showSystemToast(
                    context,
                    emoji: '⏹️',
                    message: 'Video retirado de la sala de cine',
                    accentColor: AppColors.accentPurple,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Modal de configuración del Roleplay Stage para Staff
  void _openRoleplaySettingsSheet() {
    if (!_canManageRoles()) return;
    final occupiedRoles = _stageRoles
        .where((r) => r.isTaken && r.takenByUserId != null)
        .toList();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF14121F),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.75,
            ),
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3A3A4A),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color:
                            const Color(0xFFFFD600).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.theater_comedy_rounded,
                        color: Color(0xFFFFD600),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ajustes de Roleplay Stage',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Gestión de fichas y personajes para Staff',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Opción Crear / Añadir Personaje
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  tileColor: const Color(0xFF1B1728),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color:
                          const Color(0xFFFFD600).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.person_add_alt_1_rounded,
                      color: Color(0xFFFFD600),
                      size: 20,
                    ),
                  ),
                  title: const Text(
                    'Crear / Añadir Personaje',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                  subtitle: const Text(
                    'Crea una nueva ficha de rol disponible para la sala',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 11),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded,
                      color: Color(0xFF5A5A6A)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openRoleCreatorOrSelector();
                  },
                ),
                const SizedBox(height: 16),

                // Sección Desasignar Personajes
                const Text(
                  'Personajes Ocupados en Escena',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),

                if (occupiedRoles.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF181424),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text(
                        'No hay personajes ocupados actualmente en el stage',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF7A7A8A),
                        ),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: occupiedRoles.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: 8),
                      itemBuilder: (ctx, i) {
                        final role = occupiedRoles[i];
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF181424),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF2C2542),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            children: [
                              AppAvatar(
                                imageUrl: role.avatarUrl,
                                name: role.name,
                                radius: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      role.name,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      'Por @${role.takenByUsername ?? "usuario"}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFFFFD600),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.accentCrimson
                                      .withValues(alpha: 0.15),
                                  foregroundColor:
                                      AppColors.accentCrimson,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: const BorderSide(
                                        color: AppColors.accentCrimson,
                                        width: 0.8),
                                  ),
                                ),
                                onPressed: () {
                                  _leaveRole(role);
                                  _messages.add({
                                    'type': 'system',
                                    'text':
                                        'El moderador liberó el rol "${role.name}"',
                                  });
                                  setSheetState(() {
                                    occupiedRoles.removeAt(i);
                                  });
                                  setState(() {});
                                  showSystemToast(
                                    context,
                                    emoji: '🎭',
                                    message:
                                        'Rol "${role.name}" desasignado',
                                    accentColor: const Color(0xFFFFD600),
                                  );
                                },
                                child: const Text(
                                  'Quitar',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Abre la hoja de perfil/moderación de un participante efectivo del canal
  /// LiveKit (live_voice_bar). Resuelve datos reales por el userId del avatar.
  void _openVoiceParticipantSheet(VoiceParticipant vp) {
    RoomParticipant? real;
    for (final p in _currentRoom?.participants ?? const <RoomParticipant>[]) {
      if (p.user.id == vp.identity) {
        real = p;
        break;
      }
    }
    _openParticipantSheet(
      userId: vp.identity,
      username: real?.user.username,
      displayName: vp.name,
      avatarUrl: vp.avatarUrl ?? real?.user.avatarUrl,
      role: vp.role ?? real?.role,
    );
  }

  /// Hoja unificada: perfil normal de usuario o, si el local puede gestionar,
  /// botones de moderación del canal de voz (silenciar / expulsar remotamente).
  void _openParticipantSheet({
    required String userId,
    String? username,
    required String displayName,
    String? avatarUrl,
    String? role,
  }) {
    if (userId.isEmpty) return;
    final myId = ref.read(authControllerProvider).user?.id ?? '';
    final isSelf = userId == myId;
    final canManage = !isSelf && _canManageRoles();
    final isVoiceMuted =
        ref.read(voiceRoomProvider).mutedIds.contains(userId);
    final cleanUsername = username?.replaceAll('@', '').trim() ?? '';
    RoomUserProfileSheet.show(
      context,
      displayName: displayName,
      username: cleanUsername.isNotEmpty ? cleanUsername : null,
      userId: userId,
      avatarUrl: avatarUrl,
      isOnline: true,
      isHost: role == 'HOST',
      isSelf: isSelf,
      canManage: canManage,
      isMuted: isVoiceMuted,
      onViewProfile: cleanUsername.isNotEmpty
          ? () {
              // Perfil social completo (publicaciones, seguidores,
              // insignias y bio real). `push` conserva la sala montada:
              // la voz sigue conectada en segundo plano al volver atrás.
              Navigator.pop(context);
              context.push('/profile/$cleanUsername');
            }
          : null,
      onStartDirectChat: () =>
          _startDirectChatWith(userId, cleanUsername),
      onMute: canManage
          ? () => _moderateVoice(
                userId,
                cleanUsername.isNotEmpty ? cleanUsername : displayName,
                isVoiceMuted ? 'unmute' : 'mute',
              )
          : null,
      onKick: canManage
          ? () => _moderateVoice(
                userId,
                cleanUsername.isNotEmpty ? cleanUsername : displayName,
                'kick',
              )
          : null,
    );
  }

  /// Formatea `HH:mm` (24 h) a partir del `createdAt` del mensaje.
  String? _formatMessageTime(Map<String, dynamic> msg) {
    final raw = msg['createdAt'];
    final dt = raw is DateTime
        ? raw
        : DateTime.tryParse(raw is String ? raw : '');
    if (dt == null) return null;
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// Verifica si el usuario tiene permiso de acceso a la sala privada.
  /// Si no es participante ni host, muestra modal de "Solicitar invitación".
  void _verifyAccess(Room? room) {
    if (_accessChecked || room == null) return;
    _accessChecked = true;

    // Salas públicas: acceso libre.
    if (room.access == RoomAccess.public) return;

    // Si es host o participante activo (no solo invitado), acceso permitido.
    final myId = ref.read(authControllerProvider).user?.id ?? '';
    final isHostOrParticipant = (myId.isNotEmpty && room.host.id == myId) ||
        room.participants.any((p) => p.user.id == myId && p.role != 'INVITED');
    if (isHostOrParticipant) return;

    // Sala privada sin permiso: mostrar modal de acceso denegado.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showAccessDeniedModal(room);
    });
  }

  void _showAccessDeniedModal(Room room) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF13101E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isDismissible: false,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF3A3A4A),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.accentCrimson.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.lock_outline_rounded,
                  color: AppColors.accentCrimson,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Sala Privada',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'No tienes acceso a "${room.name}". Solicita una invitación al Host para unirte.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Solicitud de invitación enviada ✓'),
                        backgroundColor: Color(0xFF0F3A3A),
                      ),
                    );
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/salas');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentCyan,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Solicitar Invitación',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/salas');
                    }
                  },
                  child: const Text(
                    'Volver',
                    style: TextStyle(color: Color(0xFF6E6888)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Resetea la identidad activa al perfil personal (sin rol) en cualquier
  /// cambio de modo o al entrar a la sala. NO hay autoasignación de rol:
  /// el usuario siempre inicia como espectador/Cuenta Personal y solo adopta
  /// un personaje si pulsa explícitamente '+ Unirse' o elige su identidad en
  /// la barra de chat. Fuera del Roleplay Stage la identidad queda forzada a
  /// la cuenta personal (no hay equipación de personajes).
  /// Fuera del modo Roleplay la identidad queda forzada a la cuenta personal.
  /// Dentro del modo Roleplay, preserva o recupera el rol si ya estaba adoptado.
  void _syncActiveIdentityForMode(String mode) {
    if (mode != 'roleplay') {
      _currentActiveRole = null;
    } else if (_currentActiveRole == null) {
      final myId = ref.read(authControllerProvider).user?.id ?? '';
      if (myId.isNotEmpty) {
        final roleFound = _stageRoles
            .where((r) => r.isTaken && r.takenByUserId == myId)
            .firstOrNull;
        if (roleFound != null) {
          _currentActiveRole = roleFound;
        }
      }
    }
  }

  /// Puebla [RoleCharacter]s del stage con los roles de la sala. Prioriza los
  /// roles persistidos en el backend (`room.stageRoles`) y los sincroniza con
  /// `SalasController`. Inicializa además el rol activo del usuario si ya lo tenía
  /// adoptado previamente.
  void _syncStageFromRoom(Room? room, {bool force = false}) {
    if (room == null || (!force && _syncedRoomId == room.id)) return;
    _syncedRoomId = room.id;

    // Verificar acceso a sala privada.
    _verifyAccess(room);

    // Cargar roles: el backend (room.stageRoles) es la fuente autoritativa de roles del stage.
    _stageRoles = room.stageRoles.where((r) => r.isValid).toList();
    _salas.setRoomRoles(widget.roomId, _stageRoles);

    // Sincronizar estrictamente el rol activo del usuario autenticado:
    final myId = ref.read(authControllerProvider).user?.id ?? '';
    RoleCharacter? confirmedRole;
    if (myId.isNotEmpty) {
      if (room.activeCharacter != null &&
          room.activeCharacter!.isTaken &&
          (room.activeCharacter!.takenByUserId == myId ||
              room.activeCharacter!.occupiedBy == myId)) {
        confirmedRole = room.activeCharacter;
      } else {
        confirmedRole = _stageRoles
            .where((r) =>
                r.isTaken &&
                (r.takenByUserId == myId || r.occupiedBy == myId))
            .firstOrNull;
      }
    }
    _currentActiveRole = confirmedRole;

    // Auto-join: el creador o un miembro activo existente entra conectado directo.
    final isHostOrActiveParticipant = (myId.isNotEmpty && room.host.id == myId) ||
        room.participants.any((p) => p.user.id == myId && p.role != 'INVITED');
    if (isHostOrActiveParticipant) _isConnected = true;
  }

  /// Registra la unión real en el backend (best-effort). En modo offline la
  /// sala sigue siendo accesible en modo local.
  Future<void> _joinRoom() async {
    final room = _currentRoom;
    final myId = ref.read(authControllerProvider).user?.id ?? '';
    if (room != null) {
      final isCreator = myId.isNotEmpty && room.host.id == myId;
      final isParticipant =
          room.participants.any((p) => p.user.id == myId && p.role != 'INVITED');
      if (isCreator || isParticipant) {
        // Ya es miembro o es el anfitrión: no reenviar petición de join para evitar
        // spam de mensajes 'Te has unido' en reconexiones o reingresos.
        return;
      }
    }
    try {
      await ref
          .read(salaDetailControllerProvider(widget.roomId).notifier)
          .join();
    } catch (_) {
      // Sin conexión o backend: continuar en modo local.
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage(String text) {
    if (!_canSendMessage) {
      _showSendError('Tu cuenta está sancionada/silenciada. No puedes enviar mensajes.');
      return;
    }
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _sendMediaMessage(type: 'TEXT', content: trimmed);
  }

  void _sendDiceRoll(String diceName, String result, String emoji) {
    if (!_canSendMessage) {
      _showSendError('Tu cuenta está sancionada/silenciada. No puedes enviar mensajes.');
      return;
    }
    final isRps = diceName.toLowerCase().contains('morra') ||
        result.contains('Piedra') ||
        result.contains('Papel') ||
        result.contains('Tijeras');
    final msgType = isRps ? 'RPS' : 'DICE';
    final metadata = <String, dynamic>{
      'diceName': diceName,
      'diceResult': result,
      'diceEmoji': emoji,
    };
    _sendMediaMessage(
      type: msgType,
      content: 'Tirada de $diceName',
      metadata: metadata,
    );
  }

  void _sendPoll(String question, List<String> options) {
    if (!_canSendMessage) {
      _showSendError('Tu cuenta está sancionada/silenciada. No puedes enviar mensajes.');
      return;
    }
    final trimmedQuestion = question.trim();
    final trimmedOptions = options
        .map((o) => o.trim())
        .where((o) => o.isNotEmpty)
        .toList();
    if (trimmedQuestion.isEmpty || trimmedOptions.isEmpty) return;
    final metadata = <String, dynamic>{
      'question': trimmedQuestion,
      'options': [
        for (var i = 0; i < trimmedOptions.length; i++)
          {'id': 'opt$i', 'text': trimmedOptions[i], 'votes': 0},
      ],
      'totalVotes': 0,
    };
    _sendMediaMessage(
      type: 'POLL',
      content: trimmedQuestion,
      metadata: metadata,
    );
    setState(() {});
    _scrollToBottom();
  }

  void _sendSticker(StickerItem sticker) {
    if (!_canSendMessage) {
      _showSendError('Tu cuenta está sancionada/silenciada. No puedes enviar mensajes.');
      return;
    }
    final user = ref.read(authControllerProvider).user;
    final isRp = _currentRoomMode == 'roleplay';
    final role = isRp ? _currentActiveRole : null;
    final myName = user?.displayName.isNotEmpty == true
        ? user!.displayName
        : (user?.username ?? 'Tú');

    _salas.addRoomMessage(widget.roomId, {
      'type': 'sticker',
      'stickerAsset': sticker.assetPath,
      'stickerEmoji': sticker.emoji,
      'senderName': myName,
      'senderId': user?.id,
      'username': user?.username,
      'userAvatar': user?.avatarUrl,
      'role': role,
      'roleColor': role?.colorHex,
      'id': 'local-${DateTime.now().microsecondsSinceEpoch}',
      'createdAt': DateTime.now(),
    });
    setState(() {});
    _scrollToBottom();
  }

  Future<void> _sendImageFromPath(String path) async {
    if (!_canSendMessage) {
      _showSendError('Tu cuenta está sancionada/silenciada. No puedes enviar mensajes.');
      return;
    }
    try {
      final file = File(path);
      if (!await file.exists()) {
        _showSendError('No se pudo leer la imagen seleccionada');
        return;
      }
      final bytes = await file.readAsBytes();
      final dims = await _decodeImageDims(bytes);
      final filename = path.split(RegExp(r'[\\/]')).last;
      final url = await _uploadMedia(
        bytes,
        filename,
        _contentTypeForFilename(path),
      );
      if (url == null) return;
      _sendMediaMessage(
        type: 'IMAGE',
        content: url,
        contentUrl: url,
        metadata: {
          'mediaUrl': url,
          'attachments': [url],
          if (dims != null) 'width': dims.$1,
          if (dims != null) 'height': dims.$2,
        },
      );
    } catch (_) {
      _showSendError('No se pudo subir la imagen');
    }
  }

  Future<void> _sendVoiceNote(
    int durationMs,
    Uint8List audioBytes,
    String filename,
  ) async {
    if (!_canSendMessage) {
      _showSendError('Tu cuenta está sancionada/silenciada. No puedes enviar mensajes.');
      return;
    }
    if (audioBytes.isEmpty) {
      _showSendError('No se pudo grabar la nota de voz');
      return;
    }
    try {
      final url = await _uploadMedia(
        audioBytes,
        filename,
        _contentTypeForFilename(filename),
      );
      if (url == null) return;
      _sendMediaMessage(
        type: 'VOICE',
        content: url,
        contentUrl: url,
        metadata: {
          'mediaUrl': url,
          'durationMs': durationMs,
        },
      );
    } catch (_) {
      _showSendError('No se pudo subir la nota de voz');
    }
  }

  Future<String?> _uploadMedia(
    Uint8List bytes,
    String filename,
    String? contentType,
  ) async {
    try {
      return await ref
          .read(uploadRepositoryProvider)
          .uploadFile(
            'media',
            bytes: bytes,
            filename: filename,
            contentType: contentType,
          );
    } catch (_) {
      _showSendError('No se pudo subir el archivo');
      return null;
    }
  }

  Future<(int, int)?> _decodeImageDims(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final dims = (frame.image.width, frame.image.height);
      frame.image.dispose();
      return dims;
    } catch (_) {
      return null;
    }
  }

  String? _contentTypeForFilename(String filename) {
    final ext = filename.toLowerCase();
    if (ext.endsWith('.jpg') || ext.endsWith('.jpeg')) return 'image/jpeg';
    if (ext.endsWith('.png')) return 'image/png';
    if (ext.endsWith('.webp')) return 'image/webp';
    if (ext.endsWith('.gif')) return 'image/gif';
    if (ext.endsWith('.m4a')) return 'audio/mp4';
    if (ext.endsWith('.mp3')) return 'audio/mpeg';
    if (ext.endsWith('.ogg')) return 'audio/ogg';
    if (ext.endsWith('.wav')) return 'audio/wav';
    return null;
  }

  void _showSendError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF2A121E),
      ),
    );
  }

  /// Alterna silenciar/desilenciar un participante de la sala.
  ///
  /// El guard `_mutePending` absorbe dobles taps (evita alternar dos veces y
  /// emitir el system message repetido); cero llamadas de red: solo estado
  /// local + nota de sistema en el chat.
  void _toggleMuteUser(String targetId, String targetName) {
    if (_mutePending) return;
    if (targetId.isEmpty) return;
    _mutePending = true;
    final wasMuted = _mutedUserIds.contains(targetId);
    if (wasMuted) {
      _mutedUserIds.remove(targetId);
    } else {
      _mutedUserIds.add(targetId);
    }
    _salas.addRoomMessage(widget.roomId, {
      'type': 'system',
      'text': wasMuted
          ? '🔊 $targetName ha sido desilenciado/a en esta sala'
          : '🔇 $targetName ha sido silenciado/a en esta sala',
    });
    setState(() {});
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) _mutePending = false;
    });
  }

  void _sendMediaMessage({
    required String type,
    required String content,
    String contentUrl = '',
    Map<String, dynamic>? metadata,
  }) {
    if (!_canSendMessage) {
      _showSendError('Tu cuenta está sancionada/silenciada. No puedes enviar mensajes.');
      return;
    }
    if (_sendingMedia) return;
    _sendingMedia = true;
    try {
      final user = ref.read(authControllerProvider).user;
      final isRp = _currentRoomMode == 'roleplay';
      final role = isRp ? _currentActiveRole : null;
      final myName = user?.displayName.isNotEmpty == true
          ? user!.displayName
          : (user?.username ?? 'Tú');
      final wiredType = switch (type) {
        'VOICE' => 'voice',
        'IMAGE' => 'image',
        'POLL' => 'poll',
        'DICE' || 'RPS' => 'dice',
        _ => 'message',
      };
      final localId = 'local-${DateTime.now().microsecondsSinceEpoch}';

      final replyingMsg = _replyingToMessage;
      final replyToId = replyingMsg?['id']?.toString();
      final replyToName = (replyingMsg?['senderName'] ?? replyingMsg?['username'])?.toString();
      final replyToBody = (replyingMsg?['body'] ?? replyingMsg?['content'] ?? replyingMsg?['text'])?.toString();
      final replyTo = (replyToId != null && replyToId.isNotEmpty)
          ? <String, dynamic>{
              'id': replyToId,
              'authorName': replyToName,
              'content': replyToBody,
            }
          : null;
      _replyingToMessage = null;

      final finalMetadata = <String, dynamic>{
        ...?metadata,
        'clientTempId': localId,
        if (replyToId != null && replyToId.isNotEmpty) ...{
          'replyToId': replyToId,
          'replyToName': replyToName,
          'replyToBody': replyToBody,
          'replyTo': replyTo,
        },
      };
      if (role?.colorHex != null && role!.colorHex.isNotEmpty) {
        finalMetadata['roleColor'] = role.colorHex;
        finalMetadata['roleColorHex'] = role.colorHex;
      }

      final effectiveMediaUrl = contentUrl.isNotEmpty
          ? contentUrl
          : (finalMetadata['mediaUrl'] as String? ?? '');

      _salas.addRoomMessage(widget.roomId, {
        'type': wiredType,
        'body': content,
        'contentUrl': effectiveMediaUrl,
        'mediaUrl': effectiveMediaUrl,
        'metadata': finalMetadata,
        'clientTempId': localId,
        'senderId': user?.id,
        'senderName': myName,
        'username': user?.username,
        'userAvatar': user?.avatarUrl,
        'role': role,
        'roleColor': role?.colorHex,
        'diceResult': finalMetadata['diceResult'],
        'diceEmoji': finalMetadata['diceEmoji'],
        'diceName': finalMetadata['diceName'],
        'id': localId,
        'createdAt': DateTime.now(),
        'replyToId': replyToId,
        'replyToName': replyToName,
        'replyToBody': replyToBody,
        'replyTo': replyTo,
      });
      setState(() {});
      _scrollToBottom();

      unawaited(
        _sendPersisted(
          type: type,
          content: content,
          metadata: finalMetadata,
          localId: localId,
          role: role,
        ),
      );
    } finally {
      _sendingMedia = false;
    }
  }

  Future<void> _sendPersisted({
    required String type,
    required String content,
    required Map<String, dynamic>? metadata,
    required String localId,
    required RoleCharacter? role,
  }) async {
    try {
      final sent = await ref
          .read(roomRepositoryProvider)
          .sendRoomMessage(
            widget.roomId,
            body: content,
            type: type,
            mediaUrl: metadata?['mediaUrl'] as String?,
            attachments: (metadata?['attachments'] as List?)?.cast<String>(),
            metadata: metadata,
            characterId: role?.id,
            characterName: role?.name,
            characterAvatarUrl: role?.avatarUrl,
            replyToId: metadata?['replyToId'] as String?,
            replyTo: metadata?['replyTo'] as Map<String, dynamic>?,
          );
      if (!mounted) return;
      _salas.replaceLocalRoomMessage(
        widget.roomId,
        localId: localId,
        server: sent,
      );
      setState(() {});
    } catch (_) {
      // Sin conexión: se conserva el mensaje optimista con estado local.
    }
  }

  /// Acción "Dejar Rol" (`leaveRole(roleId)`): libera el slot del rol en el
  /// stage —vuelve a quedar vacante para cualquiera—, resetea la identidad
  /// activa a la Cuenta Personal y actualiza el stage de forma reactiva.
  void _leaveRole(RoleCharacter role) {
    final freed = role.toVacant();
    _salas.updateRoomRole(widget.roomId, freed);
    final myId = ref.read(authControllerProvider).user?.id ?? '';
    setState(() {
      final idx = _stageRoles.indexWhere((r) => r.id == role.id);
      if (idx >= 0 && idx < _stageRoles.length) _stageRoles[idx] = freed;
      if (myId.isNotEmpty) {
        for (int i = 0; i < _stageRoles.length; i++) {
          if (_stageRoles[i].takenByUserId == myId ||
              _stageRoles[i].occupiedBy == myId) {
            _stageRoles[i] = _stageRoles[i].toVacant();
            _salas.updateRoomRole(widget.roomId, _stageRoles[i]);
          }
        }
      }
      _currentActiveRole = null;
    });

    // Actualizar optimistamente la sala en el controlador
    final currentRoom =
        ref.read(salaDetailControllerProvider(widget.roomId)).room;
    if (currentRoom != null) {
      final updatedRoles = currentRoom.stageRoles.map((r) {
        if (r.id == role.id ||
            (myId.isNotEmpty &&
                (r.takenByUserId == myId || r.occupiedBy == myId))) {
          return r.toVacant();
        }
        return r;
      }).toList();
      final updatedActiveChar = (currentRoom.activeCharacter?.id == role.id ||
              (myId.isNotEmpty &&
                  (currentRoom.activeCharacter?.takenByUserId == myId ||
                      currentRoom.activeCharacter?.occupiedBy == myId)))
          ? null
          : currentRoom.activeCharacter;
      ref
          .read(salaDetailControllerProvider(widget.roomId).notifier)
          .applyRoom(currentRoom.copyWith(
            stageRoles: updatedRoles,
            activeCharacter: updatedActiveChar,
          ));
    }

    // Persistir liberación en el backend (best-effort)
    ref
        .read(roomRepositoryProvider)
        .updateStageRole(widget.roomId, role: freed, isTake: false)
        .catchError((err) {
      debugPrint('[STAGE_ROLE] Error al liberar rol en backend: $err');
    });
  }

  /// Adopta una ficha de personaje elegida desde la Biblioteca de Roles (OCs).
  void _onRoleSelectedFromLibrary(RoleCharacter chosen) {
    final user = ref.read(authControllerProvider).user;
    final myId = user?.id ?? '';
    final myUsername = user?.displayName.isNotEmpty == true
        ? user!.displayName
        : (user?.username ?? 'Tú');

    final adopted = chosen.copyWith(
      isTaken: true,
      takenByUserId: myId,
      takenByUsername: myUsername,
    );

    setState(() {
      _currentActiveRole = adopted;
      final idx = _stageRoles.indexWhere((r) => r.id == adopted.id);
      if (idx >= 0) {
        _stageRoles[idx] = adopted;
      } else {
        _stageRoles.add(adopted);
      }
    });

    _salas.updateRoomRole(widget.roomId, adopted);
    ref
        .read(roomRepositoryProvider)
        .updateStageRole(widget.roomId, role: adopted, isTake: true)
        .catchError((err) {
      debugPrint('[STAGE_ROLE] Error al adoptar rol de biblioteca: $err');
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Identidad cambiada a: ${adopted.name}'),
        backgroundColor: const Color(0xFF2A121E),
      ),
    );
  }

  void _openRoleInfo(RoleCharacter role) {
    final canManage = _canManageRoles();
    final myId = ref.read(authControllerProvider).user?.id ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (modalCtx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final liveRole = _stageRoles.firstWhere(
            (r) => r.id == role.id,
            orElse: () => role,
          );
          final isMyRole = liveRole.isTaken &&
              (_currentActiveRole?.id == liveRole.id ||
                  (myId.isNotEmpty &&
                      (liveRole.takenByUserId == myId ||
                          liveRole.occupiedBy == myId)));
          final isOccupied = liveRole.isTaken &&
              (liveRole.takenByUserId != null || liveRole.occupiedBy != null);

          return RoleInfoModal(
            role: liveRole,
            isCurrentRole: isMyRole,
            isOccupied: isOccupied,
            occupiedByUsername: liveRole.takenByUsername,
            onTakeRole: isOccupied && !isMyRole
                ? null // No se puede tomar un rol ya ocupado por otro
                : () {
                    if (isMyRole) {
                      // Cerrar el modal de inmediato para dar retroalimentación instantánea
                      Navigator.pop(modalCtx);
                      // Dejar rol: liberar el slot y resetear la identidad.
                      _leaveRole(liveRole);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Has liberado el rol: ${liveRole.name}'),
                          backgroundColor: const Color(0xFF2A121E),
                        ),
                      );
                    } else {
                      // Tomar rol vacante
                      final user = ref.read(authControllerProvider).user;
                      final taken = liveRole.copyWith(
                        isTaken: true,
                        takenByUserId: myId,
                        takenByUsername: user?.displayName.isNotEmpty == true
                            ? user!.displayName
                            : user?.username,
                      );
                      _salas.updateRoomRole(widget.roomId, taken);
                      setState(() {
                        final idx =
                            _stageRoles.indexWhere((r) => r.id == liveRole.id);
                        if (idx >= 0 && idx < _stageRoles.length) {
                          _stageRoles[idx] = taken;
                        }
                        _currentActiveRole = taken;
                      });

                      final currentRoom = ref
                          .read(salaDetailControllerProvider(widget.roomId))
                          .room;
                      if (currentRoom != null) {
                        final updatedRoles = currentRoom.stageRoles.map((r) {
                          if (r.id == liveRole.id) return taken;
                          return r;
                        }).toList();
                        ref
                            .read(salaDetailControllerProvider(widget.roomId)
                                .notifier)
                            .applyRoom(currentRoom.copyWith(
                              stageRoles: updatedRoles,
                              activeCharacter: taken,
                            ));
                      }

                      // Persistir adopción de rol en el backend (best-effort)
                      ref
                          .read(roomRepositoryProvider)
                          .updateStageRole(widget.roomId,
                              role: taken, isTake: true)
                          .catchError((err) {
                        debugPrint(
                            '[STAGE_ROLE] Error al adoptar rol en backend: $err');
                      });
                      Navigator.pop(modalCtx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Has adoptado el rol: ${liveRole.name}'),
                          backgroundColor: const Color(0xFF1E1A2E),
                        ),
                      );
                    }
                  },
            onEditRole: canManage
                ? () async {
                    Navigator.pop(modalCtx);
                    final updated = await Navigator.push<RoleCharacter>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RoleEditorScreen(initialRole: liveRole),
                      ),
                    );
                    if (!mounted) return;
                    if (updated != null) {
                      // Mantener estado de ocupación del rol original.
                      final merged = updated.copyWith(
                        isTaken: liveRole.isTaken,
                        takenByUserId: liveRole.takenByUserId,
                        takenByUsername: liveRole.takenByUsername,
                      );
                      _salas.updateRoomRole(widget.roomId, merged);
                      setState(() {
                        final index = _stageRoles.indexWhere(
                          (r) => r.id == liveRole.id,
                        );
                        if (index >= 0 && index < _stageRoles.length) {
                          _stageRoles[index] = merged;
                        }
                        if (_currentActiveRole?.id == liveRole.id) {
                          _currentActiveRole = merged;
                        }
                      });
                      ref
                          .read(roomRepositoryProvider)
                          .saveStageRole(widget.roomId, merged)
                          .catchError((err) {
                        debugPrint(
                            '[STAGE_ROLE] Error al persistir edición de rol: $err');
                      });
                    }
                  }
                : null,
            onDeleteRole: canManage
                ? () {
                    Navigator.pop(modalCtx);
                    final roleIdStr = liveRole.id.toString().trim();
                    _salas.removeRoomRole(widget.roomId, roleIdStr);
                    setState(() {
                      _stageRoles = _stageRoles
                          .where((r) => r.id.toString().trim() != roleIdStr)
                          .toList();
                      if (_currentActiveRole?.id.toString().trim() ==
                          roleIdStr) {
                        _currentActiveRole = null;
                      }
                    });
                    ref
                        .read(roomRepositoryProvider)
                        .deleteStageRole(widget.roomId, roleIdStr)
                        .catchError((err) {
                      debugPrint(
                          '[STAGE_ROLE] Error al eliminar rol en backend: $err');
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Ficha de rol eliminada')),
                    );
                  }
                : null,
          );
        },
      ),
    );
  }

  void _openRoleCreatorOrSelector() async {
    if (!_canManageRoles()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Solo el Admin o Co-Admin puede crear fichas de rol'),
        ),
      );
      return;
    }
    final newRole = await context.push<RoleCharacter>('/roles/create');
    if (!mounted) return;
    if (newRole != null) {
      // El rol se crea VACANTE (sin asignar). Se persiste en SalasController y en el backend.
      final vacantRole = newRole.copyWith(
        isTaken: false,
        takenByUserId: null,
        takenByUsername: null,
      );
      _salas.addRoomRole(widget.roomId, vacantRole);
      setState(() {
        _stageRoles.add(vacantRole);
      });
      ref
          .read(roomRepositoryProvider)
          .saveStageRole(widget.roomId, vacantRole)
          .catchError((err) {
        debugPrint(
            '[STAGE_ROLE] Error al persistir nuevo rol en backend: $err');
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Rol "${vacantRole.name}" creado — disponible para todos',
          ),
          backgroundColor: const Color(0xFF0F3A3A),
        ),
      );
    }
  }

  void _openRoomModesSelector() {
    if (!_canManageRoles()) return;
    final isHostOrAdmin = _canManageRoles();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF14121F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3A3A4A),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text(
                    'Modos de Sala',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  if (!isHostOrAdmin)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Solo Admin',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF9E9EA8),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              _buildModeOption(
                mode: 'voice',
                icon: Icons.graphic_eq_rounded,
                iconColor: AppColors.accentTeal,
                title: 'Voice Chat',
                subtitle: 'Chat de voz en tiempo real con micrófono en vivo',
                isCurrent: _currentRoomMode == 'voice',
                isAllowed: isHostOrAdmin,
              ),
              const SizedBox(height: 8),
              _buildModeOption(
                mode: 'roleplay',
                icon: Icons.theater_comedy_rounded,
                iconColor: const Color(0xFFFFD600),
                title: 'Roleplay Stage',
                subtitle: 'Escena con avatares de OCs, fichas de rol y dados',
                isCurrent: _currentRoomMode == 'roleplay',
                isAllowed: isHostOrAdmin,
              ),
              const SizedBox(height: 8),
              _buildModeOption(
                mode: 'screening',
                icon: Icons.live_tv_rounded,
                iconColor: const Color(0xFFD500F9),
                title: 'Screening Room',
                subtitle: 'Proyección multimedia y sincronización de video',
                isCurrent: _currentRoomMode == 'screening',
                isAllowed: isHostOrAdmin,
              ),
              const SizedBox(height: 8),
              _buildModeOption(
                mode: 'standard',
                icon: Icons.chat_bubble_outline_rounded,
                iconColor: const Color(0xFF00E5FF),
                title: 'Chat Estándar',
                subtitle: 'Mensajería clásica sin stage superior',
                isCurrent: _currentRoomMode == 'standard',
                isAllowed: isHostOrAdmin,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeOption({
    required String mode,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isCurrent,
    required bool isAllowed,
  }) {
    return GestureDetector(
      onTap: () {
        if (_isSwitchingActivity) return;
        _triggerActivityDebounce();
        if (!isAllowed) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Solo el Host o Administradores pueden cambiar el modo',
              ),
            ),
          );
          return;
        }
        HapticFeedback.mediumImpact();
        Navigator.pop(context);
        final normalized = RoomSocketService.normalizeMode(mode);
        final currentRoom = _currentRoom;
        if (normalized != 'voice') {
          final voice = ref.read(voiceRoomProvider);
          if (voice.isConnected || voice.isConnecting) {
            ref.read(voiceRoomProvider.notifier).leaveVoice();
          }
        }
        final isScreening = normalized == 'screening';
        final nextVideoId = isScreening ? currentRoom?.cinemaVideoId : null;
        final nextCinemaState =
            isScreening ? (currentRoom?.cinemaState ?? 'STOPPED') : 'STOPPED';
        final nextCurrentTime =
            isScreening ? (currentRoom?.cinemaCurrentTime ?? 0.0) : 0.0;

        _applyRoomMode(
          normalized,
          cinemaVideoId: nextVideoId,
          cinemaState: nextCinemaState,
          cinemaCurrentTime: nextCurrentTime,
        );
        debugPrint('[MODE_DEBUG] Emitiendo cambio de modo a HTTP: '
            'sala=${widget.roomId}, modo=$normalized');
        ref.read(roomRepositoryProvider).updateRoomMode(
          widget.roomId,
          normalized,
          videoId: nextVideoId,
          cinemaState: nextCinemaState,
          currentTime: nextCurrentTime,
        ).then((updated) {
          if (!mounted) return;
          ref
              .read(salaDetailControllerProvider(widget.roomId).notifier)
              .applyRoom(updated);
          ref.read(salasControllerProvider.notifier).applyRoom(updated);
        }).catchError((err) {
          debugPrint('[MODE_DEBUG] Error en updateRoomMode HTTP: $err');
        });
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isCurrent
              ? iconColor.withValues(alpha: 0.12)
              : const Color(0xFF1B1728),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isCurrent ? iconColor : const Color(0xFF2C2542),
            width: isCurrent ? 1.2 : 0.8,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isCurrent)
              Icon(Icons.check_circle_rounded, color: iconColor, size: 18),
          ],
        ),
      ),
    );
  }

  void _openRoomInfo(Room? room) {
    HapticFeedback.selectionClick();
    // Refresca el detalle al abrir para que "Descripción y Lore" nunca
    // muestre valores obsoletos en memoria.
    ref.read(salaDetailControllerProvider(widget.roomId).notifier).refresh();
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => RoomDetailInfoScreen(
          roomId: widget.roomId,
          room: room,
          onEditRoom: () => _openEditRoom(room),
        ),
      ),
    );
  }

  void _openEditRoom(Room? room) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => EditRoomScreen(
          room: room,
          initialCoverUrl: _effectiveCoverUrl,
          initialBgUrl: _effectiveBgUrl,
          initialThemeColor: _themeColor,
        ),
      ),
    );
    if (!mounted) return;
    if (result != null) {
      setState(() {
        _roomCoverUrl = result['coverUrl'] as String? ?? _roomCoverUrl;
        _roomBgUrl = result['bgUrl'] as String? ?? _roomBgUrl;
        _themeColor = result['themeColor'] as Color? ?? _themeColor;
      });

      // Persistir la configuración, portada, fondo y reglas en el backend para que no se
      // pierdan al reiniciar la aplicación (PATCH /salas/:id).
      final cover = result['coverUrl'] as String?;
      final bg = result['bgUrl'] as String?;
      final name = result['name'] as String?;
      final desc = result['description'] as String?;
      final rules = (result['rules'] as List?)?.cast<String>();
      final tags = (result['tags'] as List?)?.cast<String>();
      try {
        final updatedRoom = await ref.read(roomRepositoryProvider).updateSala(
              widget.roomId,
              name: name,
              description: desc,
              imageUrl: cover != null && cover.isNotEmpty ? cover : null,
              chatBackgroundUrl: bg != null && bg.isNotEmpty ? bg : null,
              rules: rules,
              tags: tags,
            );
        if (!mounted) return;
        ref.read(salaDetailControllerProvider(widget.roomId).notifier).applyRoom(updatedRoom);
        ref.read(salasControllerProvider.notifier).applyRoom(updatedRoom);
        await ref.read(salaDetailControllerProvider(widget.roomId).notifier).refresh();
        setState(() {});
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se pudo guardar la configuración de la sala'),
              backgroundColor: Color(0xFF2A121E),
            ),
          );
        }
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configuración de la sala guardada ✨')),
        );
      }
    }
  }

  // ── Permisos de gestión: Solo Admin (Host) / Co-Admin ──────────────────
  bool _canManageRoles() {
    final room = _currentRoom;
    if (room == null) return false;
    final myId = ref.read(authControllerProvider).user?.id ?? '';
    if (myId.isEmpty) return false;
    if (room.host.id == myId) return true;
    for (final p in room.participants) {
      if (p.user.id == myId && RoomPermissions.canManageRole(p.role)) {
        return true;
      }
    }
    return false;
  }

  /// Inicia o reabre una conversación directa con el usuario indicado usando
  /// siempre su `userId` real y su `username` (handle) para la petición.
  /// Navega al DM dedicado (`/dm/:id`) y verifica que la conversación
  /// devuelta pertenezca al usuario objetivo antes de navegar.
  Future<void> _startDirectChatWith(String userId, String username) async {
    if (userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo iniciar la conversación'),
          backgroundColor: Color(0xFF1E1A2E),
        ),
      );
      return;
    }
    Future<void> failChat(String message) async {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFF1E1A2E),
        ),
      );
    }

    try {
      final chat = ref.read(chatRepositoryProvider);
      final cleanUsername = username.replaceAll('@', '').trim();
      final conversation = await chat.openOrCreateDirect(
        userId,
        username: cleanUsername.isNotEmpty ? cleanUsername : null,
      );
      if (!mounted) return;
      if (conversation.id.isEmpty) {
        await failChat('No se pudo iniciar la conversación');
        return;
      }
      // Verificación anti-chat-equivocado: la conversación devuelta debe
      // incluir al usuario objetivo como contraparte.
      final myId = ref.read(authControllerProvider).user?.id ?? '';
      final otherId = conversation.resolveOtherMember(myId)?.id ?? '';
      if (otherId.isNotEmpty && otherId != userId) {
        await failChat('No se pudo abrir el chat con este usuario');
        return;
      }
      ref
          .read(conversationsControllerProvider.notifier)
          .upsertConversation(conversation);
      context.push('/dm/${conversation.id}');
    } catch (_) {
      await failChat('No se pudo iniciar la conversación');
    }
  }

  Room? get _currentRoom =>
      ref.read(salaDetailControllerProvider(widget.roomId)).room;

  // ── Follow del host (header) ───────────────────────────────────────────
  Widget _buildFollowButton(Room? room) {
    final host = room?.host;
    if (host == null || host.id.isEmpty) return const SizedBox.shrink();
    if (host.id == ref.read(authControllerProvider).user?.id) {
      return const SizedBox.shrink();
    }

    ref.read(userFollowNotifierProvider(host.id).notifier).initialize(
          isFollowing: host.isFollowing,
        );
    final followState = ref.watch(userFollowNotifierProvider(host.id));
    final following = followState.isFollowing;
    final isBusy = followState.isBusy;

    return GestureDetector(
      onTap: isBusy
          ? null
          : () async {
              HapticFeedback.selectionClick();
              try {
                await ref
                    .read(userFollowNotifierProvider(host.id).notifier)
                    .toggleFollow();
              } catch (_) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('No se pudo actualizar el follow'),
                    ),
                  );
                }
              }
            },
      child: Container(
        height: 20,
        padding: const EdgeInsets.symmetric(horizontal: 7),
        decoration: BoxDecoration(
          color: following
              ? AppColors.accentCyan.withValues(alpha: 0.12)
              : const Color(0xFF183338),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: following
                ? AppColors.accentCyan.withValues(alpha: 0.7)
                : AppColors.accentCyan.withValues(alpha: 0.45),
            width: 1,
          ),
        ),
        child: Center(
          child: isBusy
              ? const SizedBox(
                  width: 11,
                  height: 11,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.6,
                    color: AppColors.accentCyan,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      following ? Icons.check_rounded : Icons.add_rounded,
                      size: 12,
                      color: AppColors.accentCyan,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      following ? 'Siguiendo' : 'Seguir',
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.accentCyan,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  // ── Salir de la sala: SOLO desde el menú (•••) ────────────────────────
  Future<void> _leaveRoom() async {
    if (_leaving) return;
    _leaving = true;
    setState(() {
      _currentActiveRole = null;
      _stageRoles = [];
      _syncedRoomId = null;
    });
    final voiceState = ref.read(voiceRoomProvider);
    if (voiceState.activeRoomId == widget.roomId) {
      await ref.read(voiceRoomProvider.notifier).leaveRoom();
    }
    try {
      await ref
          .read(salaDetailControllerProvider(widget.roomId).notifier)
          .leave();
    } catch (_) {
      // Sin conexión: salimos localmente igualmente.
    }
    if (!mounted) {
      _leaving = false;
      return;
    }
    final updated = _currentRoom;
    if (updated != null) {
      final salas = ref.read(salasControllerProvider.notifier);
      // Si el host abandona, la sala termina: se retira de la lista para que
      // no queden entradas fantasma que muestren el árbol sin pintar.
      if (updated.status == RoomStatus.ended) {
        salas.removeRoom(updated.id);
      } else {
        salas.applyRoom(updated);
      }
    }
    // Cancela de forma segura el stream/listener del detalle de la sala
    // ANTES de navegar, para que ninguna actualización posterior repinte
    // un estado huérfano (pantalla negra).
    ref.invalidate(salaDetailControllerProvider(widget.roomId));
    // Navegación inmediata y segura: si la sala se abrió como ruta raíz o el
    // stack no permite pop, vamos directo a /salas en lugar de desapilar.
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/main');
    }
  }

  void _showRoomMenu() {
    final room = _currentRoom;
    final myId = ref.read(authControllerProvider).user?.id ?? '';
    // Host/Creador: solo puede eliminar la sala (nunca abandonarla).
    final isHost = room != null && myId.isNotEmpty && room.host.id == myId;

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
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Opciones de la sala',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.link_rounded,
                color: AppColors.accentCyan,
              ),
              title: const Text(
                'Copiar enlace de la sala',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: const Text(
                'Copia el enlace canónico directo al portapapeles',
                style: TextStyle(color: Color(0xFF8A8A9A), fontSize: 12),
              ),
              trailing: const Icon(
                Icons.copy_rounded,
                color: Color(0xFF5A5A6A),
                size: 18,
              ),
              onTap: () {
                Navigator.pop(ctx);
                _copyRoomLink();
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.person_add_alt_1_rounded,
                color: AppColors.accentTeal,
              ),
              title: const Text(
                'Invitar amigos',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: const Text(
                'Envía una invitación directa a tus contactos',
                style: TextStyle(color: Color(0xFF8A8A9A), fontSize: 12),
              ),
              trailing: const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF5A5A6A),
              ),
              onTap: () {
                Navigator.pop(ctx);
                final currentRoom = room ?? _currentRoom;
                if (currentRoom != null) {
                  RoomInviteFriendsSheet.show(context, room: currentRoom);
                }
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.share_rounded,
                color: Color(0xFFA594F9),
              ),
              title: const Text(
                'Compartir sala',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: const Text(
                'Invita amigos a través de otras aplicaciones',
                style: TextStyle(color: Color(0xFF8A8A9A), fontSize: 12),
              ),
              trailing: const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF5A5A6A),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _shareRoom();
              },
            ),
            if (isHost)
              ListTile(
                leading: const Icon(
                  Icons.delete_forever_rounded,
                  color: AppColors.accentCrimson,
                ),
                title: const Text(
                  'Eliminar sala',
                  style: TextStyle(
                    color: AppColors.accentCrimson,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: const Text(
                  'Termina y elimina la sala para todos los participantes',
                  style: TextStyle(color: Color(0xFF8A8A9A), fontSize: 12),
                ),
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF5A5A6A),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDeleteRoom(room);
                },
              )
            else
              ListTile(
                leading: const Icon(
                  Icons.logout_rounded,
                  color: AppColors.accentCrimson,
                ),
                title: const Text(
                  'Abandonar sala',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: const Text(
                  'Sales de la sala y desconectas la sesión',
                  style: TextStyle(color: Color(0xFF8A8A9A), fontSize: 12),
                ),
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF5A5A6A),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _leaveRoom();
                },
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _copyRoomLink() {
    final roomUrl = 'https://kyubi.app/salas/${widget.roomId}';
    Clipboard.setData(ClipboardData(text: roomUrl));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('¡Enlace de la sala copiado al portapapeles!'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _shareRoom() {
    final roomUrl = 'https://kyubi.app/salas/${widget.roomId}';
    final roomName = _currentRoom?.name ?? 'esta sala';
    Share.share(
      '¡Únete a $roomName en Kyubi!\n$roomUrl',
      subject: 'Únete a mi sala en Kyubi',
    );
  }

  void _startReply(Map<String, dynamic> msg) {
    HapticFeedback.lightImpact();
    setState(() {
      _replyingToMessage = msg;
      _editingMessage = null;
    });
  }

  void _cancelReply() {
    setState(() => _replyingToMessage = null);
  }

  void _startEdit(Map<String, dynamic> msg) {
    HapticFeedback.lightImpact();
    setState(() {
      _editingMessage = msg;
      _replyingToMessage = null;
    });
  }

  void _cancelEdit() {
    setState(() => _editingMessage = null);
  }

  Future<void> _submitEdit(String messageId, String newContent) async {
    final trimmed = newContent.trim();
    if (trimmed.isEmpty || messageId.isEmpty) return;
    _cancelEdit();

    _salas.updateRoomMessage(
      widget.roomId,
      messageId,
      content: trimmed,
      isEdited: true,
    );
    setState(() {});

    if (!messageId.startsWith('local-')) {
      try {
        await ref.read(roomRepositoryProvider).editRoomMessage(
          widget.roomId,
          messageId,
          content: trimmed,
        );
      } catch (err) {
        debugPrint('[EDIT_MSG] Error editando mensaje: $err');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'No se pudo editar el mensaje: ${err.toString().replaceAll('Exception:', '').trim()}',
              ),
              backgroundColor: const Color(0xFF2A121E),
            ),
          );
        }
      }
    }
  }

  void _confirmDeleteMessage(Map<String, dynamic> msg) {
    final msgId = msg['id']?.toString() ?? '';
    if (msgId.isEmpty) return;

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF1B172B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF332B4F), width: 0.8),
        ),
        title: const Text(
          '¿Eliminar mensaje?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Esta acción eliminará el mensaje permanentemente de la sala.',
          style: TextStyle(color: Color(0xFFC0BCDA), fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancelar', style: TextStyle(color: Color(0xFF8E889D))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentCrimson,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              _salas.deleteRoomMessage(widget.roomId, msgId);
              setState(() {});
              if (!msgId.startsWith('local-')) {
                try {
                  await ref.read(roomRepositoryProvider).deleteRoomMessage(widget.roomId, msgId);
                } catch (err) {
                  debugPrint('[DELETE_MSG] Error eliminando mensaje HTTP: $err');
                }
              }
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _scrollToMessage(String targetMessageId) {
    if (targetMessageId.isEmpty) return;
    final index = _messages.indexWhere((m) => '${m['id'] ?? ''}' == targetMessageId);
    if (index < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El mensaje citado no se encuentra en el historial actual.'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (_scrollController.hasClients) {
      final max = _scrollController.position.maxScrollExtent;
      final targetOffset = (_messages.length > 1)
          ? (index / (_messages.length - 1)) * max
          : 0.0;
      _scrollController.animateTo(
        targetOffset.clamp(0.0, max),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _showMessageContextMenu(Map<String, dynamic> msg) {
    HapticFeedback.mediumImpact();
    final myId = ref.read(authControllerProvider).user?.id ?? '';
    final senderId = msg['senderId']?.toString() ?? '';
    final isMine = senderId.isNotEmpty && senderId == myId;
    final isHost = _currentRoom != null && myId.isNotEmpty && _currentRoom!.host.id == myId;
    final canManage = isHost || _canManageRoles();
    final isEdited = msg['isEdited'] == true || (msg['editCount'] != null && (msg['editCount'] as num) > 0);
    final text = (msg['body'] ?? msg['content'] ?? msg['text'] ?? '').toString();
    final rawType = (msg['type'] as String? ?? '').toLowerCase();
    final isTextMessage = rawType == 'message' || rawType == 'text' || rawType.isEmpty;

    final meta = msg['metadata'] is Map
        ? Map<String, dynamic>.from(msg['metadata'] as Map)
        : <String, dynamic>{};
    final mediaUrl = (msg['mediaUrl'] ??
            msg['contentUrl'] ??
            meta['mediaUrl'] ??
            meta['url'])
        ?.toString();

    bool isImageUrl(String? s) {
      if (s == null || s.trim().isEmpty) return false;
      final clean = s.toLowerCase().split('?').first.trim();
      return clean.endsWith('.png') ||
          clean.endsWith('.jpg') ||
          clean.endsWith('.jpeg') ||
          clean.endsWith('.webp') ||
          clean.endsWith('.gif') ||
          clean.contains('/images/') ||
          clean.contains('/media/') ||
          clean.contains('supabase.co/storage/v1/object/public/');
    }

    final isImage = rawType == 'image' ||
        meta['attachmentType'] == 'image' ||
        isImageUrl(mediaUrl) ||
        isImageUrl(text);

    final effectiveImageUrl = (mediaUrl != null && mediaUrl.isNotEmpty)
        ? mediaUrl
        : (isImageUrl(text) ? text : '');

    final createdAtRaw = msg['createdAt'] ?? msg['timestamp'];
    DateTime? createdAtDt;
    if (createdAtRaw is DateTime) {
      createdAtDt = createdAtRaw;
    } else if (createdAtRaw is String && createdAtRaw.isNotEmpty) {
      createdAtDt = DateTime.tryParse(createdAtRaw);
    }
    final isWithin15Minutes = createdAtDt == null ||
        DateTime.now().difference(createdAtDt).inMinutes < 15;

    Future<void> saveImageToGallery(String imageUrl) async {
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
        if (bytes == null || bytes.isEmpty) {
          throw Exception('No se pudieron obtener los datos de la imagen');
        }
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
              title: const Text('Responder', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(ctx);
                _startReply(msg);
              },
            ),
            if (isImage && effectiveImageUrl.isNotEmpty) ...[
              ListTile(
                leading: const Icon(Icons.download_rounded, color: AppColors.accentTeal),
                title: const Text('Guardar imagen', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: const Text('Descargar a la galería del dispositivo', style: TextStyle(color: Color(0xFF8A8A9A), fontSize: 11)),
                onTap: () {
                  Navigator.pop(ctx);
                  saveImageToGallery(effectiveImageUrl);
                },
              ),
              ListTile(
                leading: const Icon(Icons.link_rounded, color: Color(0xFF9E9EA8)),
                title: const Text('Copiar enlace de imagen', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
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
                title: const Text('Copiar texto', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
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
            if (isMine && !isEdited && isTextMessage && isWithin15Minutes)
              ListTile(
                leading: const Icon(Icons.edit_rounded, color: Color(0xFFFFB300)),
                title: const Text('Editar mensaje', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: const Text('Solo puedes editar tu mensaje dentro de los primeros 15 minutos', style: TextStyle(color: Color(0xFF8A8A9A), fontSize: 11)),
                onTap: () {
                  Navigator.pop(ctx);
                  _startEdit(msg);
                },
              ),
            if (isMine || canManage)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: AppColors.accentCrimson),
                title: const Text('Eliminar mensaje', style: TextStyle(color: AppColors.accentCrimson, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDeleteMessage(msg);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Diálogo de confirmación antes de eliminar la sala (solo Host/Creador).
  Future<void> _confirmDeleteRoom(Room? room) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161224),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFF2E2744), width: 0.8),
        ),
        title: const Text(
          '¿Eliminar sala?',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        content: Text(
          'Se terminará y eliminará "${room?.name ?? 'la sala'}" para todos los '
          'participantes. Esta acción no se puede deshacer.',
          style: const TextStyle(fontSize: 13, color: Color(0xFFC0C0D4)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentCrimson,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Eliminar',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _deleteRoom();
  }

  /// Elimina la sala en el backend (best-effort) y la retira localmente.
  Future<void> _deleteRoom() async {
    if (_leaving) return;
    _leaving = true;
    setState(() {
      _currentActiveRole = null;
      _stageRoles = [];
      _syncedRoomId = null;
    });
    final voiceState = ref.read(voiceRoomProvider);
    if (voiceState.activeRoomId == widget.roomId) {
      await ref.read(voiceRoomProvider.notifier).leaveRoom();
    }
    final salas = ref.read(salasControllerProvider.notifier);
    try {
      await ref.read(roomRepositoryProvider).deleteSala(widget.roomId);
    } catch (_) {
      // Sin conexión o backend caído: la sala igualmente se retira localmente.
    }
    if (!mounted) return;
    salas.removeRoom(widget.roomId);
    salas.clearRoomMessages(widget.roomId);
    ref.invalidate(salaDetailControllerProvider(widget.roomId));
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/salas');
    }
  }

  /// Navegación natural estilo WhatsApp: el botón atrás solo regresa a la
  /// lista de chats sin salir de la sala. La salida real ocurre únicamente
  /// desde el menú (•••) → "Abandonar sala".
  void _handleExit() {
    // Si la sala llegó como ruta raíz (sin stack previo), volvemos a /salas
    // para no desapilar la base y terminar con el árbol sin pintar.
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/salas');
    }
  }

  @override
  Widget build(BuildContext context) {
    // ── Escucha declarativa de cambios de estado en la sala ───────────────────
    // Se aíslan todas las mutaciones fuera del frame de renderizado.
    ref.listen<SalaDetailState>(
      salaDetailControllerProvider(widget.roomId),
      (previous, next) {
        final prevRoom = previous?.room;
        final nextRoom = next.room;
        if (nextRoom == null) return;

        final rolesChanged = prevRoom?.stageRoles != nextRoom.stageRoles;
        final participantsChanged =
            prevRoom?.participants.length != nextRoom.participants.length;
        final roomChanged = prevRoom?.id != nextRoom.id;

        if (roomChanged || rolesChanged || participantsChanged) {
          _syncStageFromRoom(nextRoom, force: rolesChanged || participantsChanged);
        }

        if (prevRoom?.currentMode != nextRoom.currentMode &&
            nextRoom.currentMode != _currentRoomMode) {
          _applyRoomMode(nextRoom.currentMode, notifyToast: false);
        }

        if (_isConnected && !_chatStarted) {
          _startRoomChat();
        }
      },
    );

    final state = ref.watch(salaDetailControllerProvider(widget.roomId));
    final room = state.room;
    final roomName = room?.name ?? 'Sala';

    return PopScope(
      // El botón atrás (flecha superior) y el gesto del sistema nunca deben
      // cerrar la app: si no hay stack previo se redirige a /salas.
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && mounted) _handleExit();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: const Color(0xFF0A0912),
        body: Stack(
        fit: StackFit.expand,
        children: [
          // ── 1. Fondo de Pantalla Completo (Background Wallpaper con opacidad) ──
          if (_effectiveBgUrl != null && _effectiveBgUrl!.isNotEmpty)
            Positioned.fill(
              child: _effectiveBgUrl!.startsWith('assets/')
                  ? Image.asset(
                      _effectiveBgUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    )
                  : CachedNetworkImage(
                      imageUrl: _effectiveBgUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => const SizedBox.shrink(),
                    ),
            ),

          // Capa oscura translúcida
          Positioned.fill(child: Container(color: const Color(0xE60A0912))),

          // ── 2. Estructura Principal ──
          SafeArea(
            child: Column(
              children: [
                // ── Header Superior Inmersivo (Ref: image_992c3c.jpg) ──
                _buildTopHeader(roomName, room),

                // ── Barra de Anuncios: 📢 Announcement ──
                _buildAnnouncementBar(),

                // ── Contador de participantes (debajo del anuncio, anclado
                //    a la esquina superior derecha del área de chat) ──
                if (room != null) _buildMemberPill(room),

                // ── Stage de Voz en Vivo (LiveKit) ──
                // Único panel de voz del top: debajo de anuncios y miembros.
                // Aislado dentro de un Consumer local para evitar que los decibelios
                // y eventos de audio de participantes redibujen todo el Scaffold.
                Consumer(
                  builder: (context, ref, _) {
                    final isVoiceConnected = ref.watch(
                      voiceRoomProvider.select((s) => s.isConnected),
                    );
                    final activeRoomId = ref.watch(
                      voiceRoomProvider.select((s) => s.activeRoomId),
                    );
                    final isVoiceActiveInThisRoom =
                        activeRoomId == widget.roomId && isVoiceConnected;
                    final isVoiceActiveElsewhere = isVoiceConnected &&
                        activeRoomId != null &&
                        activeRoomId != widget.roomId;

                    if (isVoiceActiveInThisRoom ||
                        (_currentRoomMode == 'voice' &&
                            !isVoiceActiveElsewhere)) {
                      return LiveVoiceBar(
                        roomId: widget.roomId,
                        isMinimized: _isVoiceMinimized,
                        onToggleMinimize: () {
                          if (_isSwitchingActivity) return;
                          _triggerActivityDebounce();
                          setState(() {
                            _isVoiceMinimized = !_isVoiceMinimized;
                            if (!_isVoiceMinimized) {
                              _isRoleplayMinimized = true;
                            }
                          });
                        },
                        onParticipantTap: _openVoiceParticipantSheet,
                        canPowerOff: _canManageRoles(),
                        onPowerOff: _turnOffActivity,
                        canManage: _canManageRoles(),
                        onOpenSettings: _openVoiceSettingsSheet,
                        isStaffOnly: _voiceStaffOnly,
                        canJoinVoice: !_voiceStaffOnly ||
                            _canManageRoles() ||
                            _allowedVoiceSpeakerIds.contains(
                                ref.read(authControllerProvider).user?.id),
                      );
                    }

                    if (isVoiceActiveElsewhere) {
                      return _buildVoiceActiveElsewhereBanner(activeRoomId);
                    }

                    return const SizedBox.shrink();
                  },
                ),

                // ── Panel de Actividad Superior Dinámico (Condicional Top-Down Flow) ──
                if (_currentRoomMode == 'roleplay')
                  RoleplayStageView(
                    roles: _stageRoles,
                    isExpanded: !_isRoleplayMinimized,
                    onToggleExpanded: (expanded) {
                      if (_isSwitchingActivity) return;
                      _triggerActivityDebounce();
                      setState(() {
                        _isRoleplayMinimized = !expanded;
                        if (expanded) {
                          _isVoiceMinimized = true;
                        }
                      });
                    },
                    onRoleTap: _openRoleInfo,
                    onAddRoleTap: _openRoleCreatorOrSelector,
                    currentUserId: ref.read(authControllerProvider).user?.id,
                    canPowerOff: _canManageRoles(),
                    onPowerOff: _turnOffActivity,
                    canManage: _canManageRoles(),
                    onOpenSettings: _openRoleplaySettingsSheet,
                    onPlayTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('¡Turno de Rol solicitado! 🎲'),
                        ),
                      );
                    },
                    onLeaveStageTap: () {
                      final myId = ref.read(authControllerProvider).user?.id;
                      if (myId != null && myId.isNotEmpty) {
                        final myRoles = _stageRoles
                            .where((r) =>
                                (r.isTaken &&
                                    (r.takenByUserId == myId ||
                                        r.occupiedBy == myId)) ||
                                r.id == _currentActiveRole?.id)
                            .toList();
                        if (myRoles.isNotEmpty) {
                          for (final role in myRoles) {
                            _leaveRole(role);
                          }
                        } else if (_currentActiveRole != null) {
                          _leaveRole(_currentActiveRole!);
                        } else {
                          setState(() {
                            _currentActiveRole = null;
                            for (int i = 0; i < _stageRoles.length; i++) {
                              if (_stageRoles[i].takenByUserId == myId ||
                                  _stageRoles[i].occupiedBy == myId) {
                                _stageRoles[i] = _stageRoles[i].toVacant();
                                _salas.updateRoomRole(
                                    widget.roomId, _stageRoles[i]);
                              }
                            }
                          });
                          ref
                              .read(roomRepositoryProvider)
                              .updateStageRole(widget.roomId,
                                  role: null, isTake: false)
                              .catchError((_) {});
                        }
                      } else if (_currentActiveRole != null) {
                        _leaveRole(_currentActiveRole!);
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Has bajado del stage'),
                          backgroundColor: Color(0xFF2A121E),
                        ),
                      );
                    },
                  )
                else if (_currentRoomMode == 'screening')
                  CinemaPlayerView(
                    roomId: widget.roomId,
                    initialVideoId: room?.cinemaVideoId,
                    initialState: room?.cinemaState ?? 'STOPPED',
                    initialPosition: room?.cinemaEstimatedPosition ?? 0,
                    isHost: _canManageRoles(),
                    isMinimized: _isStageMinimized,
                    onToggleMinimize: () {
                      if (_isSwitchingActivity) return;
                      _triggerActivityDebounce();
                      setState(() {
                        _isStageMinimized = !_isStageMinimized;
                        if (!_isStageMinimized) {
                          _isVoiceMinimized = true;
                          _isRoleplayMinimized = true;
                        }
                      });
                    },
                    canManage: _canManageRoles(),
                    onOpenSettings: _openCinemaSettingsSheet,
                    onToggleOff: _turnOffActivity,
                  ),

                // ── Botón de redimensión / colapso de la actividad activa ──
                if (_currentRoomMode == 'voice' ||
                    ref.watch(voiceRoomProvider.select((s) => s.isConnected)) ||
                    _currentRoomMode == 'roleplay' ||
                    _currentRoomMode == 'screening')
                  _buildStageResizeButton(),

                // ── Feed de Mensajes / Chat Flow (Ref: Imagen 1, 2, 3, 5) ──
                // Las animaciones de emojis/stickers se pausan cuando el
                // usuario está escribiendo o el chat pierde el foco.
                ChatAnimationScope(
                  animationsEnabled: _chatAnimationsEnabled,
                  child: Expanded(
                    child: _messages.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  size: 32,
                                  color: Colors.white.withValues(alpha: 0.2),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Sé el primero en enviar un mensaje...',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF7A7A8A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          reverse: true,
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 10,
                          ),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final msg = _messages[_messages.length - 1 - index];
                            final rawType =
                                (msg['type'] as String? ?? 'message')
                                    .toLowerCase();
                            final isSystem = rawType == 'system' ||
                                msg['isSystem'] == true ||
                                (msg['type'] as String?)?.toUpperCase() ==
                                    'SYSTEM';

                            if (rawType == 'time') {
                              return Center(
                                child: Container(
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.4),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    (msg['text'] ?? msg['body'] ?? '')
                                        as String,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF7A7A8A),
                                    ),
                                  ),
                                ),
                              );
                            }

                            if (isSystem) {
                              final metadata =
                                  msg['metadata'] as Map<String, dynamic>? ??
                                      {};
                              final subType =
                                  metadata['subType'] as String? ??
                                      msg['subType'] as String?;
                              final msgUserId =
                                  metadata['userId'] as String? ??
                                      msg['senderId'] as String? ??
                                      msg['userId'] as String? ??
                                      '';
                              final userName =
                                  metadata['userName'] as String? ??
                                      msg['senderName'] as String? ??
                                      msg['userName'] as String? ??
                                      '';
                              final myId = ref
                                      .read(authControllerProvider)
                                      .user
                                      ?.id ??
                                  '';
                              final rawBody = (msg['text'] ??
                                      msg['body'] ??
                                      msg['content'] ??
                                      '')
                                  .toString();

                              final isJoin = subType == 'USER_JOIN' ||
                                  rawBody.contains('se ha unido');

                              final String displayText;
                              if (isJoin) {
                                if (msgUserId.isNotEmpty && msgUserId == myId) {
                                  displayText = '— Te has unido —';
                                } else if (userName.isNotEmpty) {
                                  displayText = '— $userName se ha unido —';
                                } else {
                                  displayText = rawBody.isNotEmpty
                                      ? '— $rawBody —'
                                      : '— Un usuario se ha unido —';
                                }
                              } else {
                                displayText = rawBody;
                              }

                              return Center(
                                child: Container(
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 6,
                                    horizontal: 16,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0x80141022),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFF2C2542),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.info_outline_rounded,
                                        size: 13,
                                        color: AppColors.accentCyan,
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          displayText,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFFC8C8DC),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            final metaMap = msg['metadata'] is Map<String, dynamic>
                                ? msg['metadata'] as Map<String, dynamic>
                                : (msg['metadata'] is Map
                                    ? Map<String, dynamic>.from(msg['metadata'] as Map)
                                    : null);
                            final msgTypeUpper =
                                (msg['type'] as String? ?? '').toUpperCase();
                            final isDice = rawType == 'dice' ||
                                msgTypeUpper == 'DICE' ||
                                msgTypeUpper == 'RPS' ||
                                msg['diceResult'] != null ||
                                metaMap?['diceResult'] != null;
                            final isSticker = rawType == 'sticker';
                            // Render inmutable: el rol del mensaje sale de sus
                            // propios datos (roleName != null en el wire),
                            // NUNCA del modo actual de la sala. Así el historial
                            // de Roleplay conserva su hexágono y tag de rol
                            // aunque el host cambie a voz / chat estándar.
                            final role = msg['role'] as RoleCharacter?;
                            final senderName =
                                msg['senderName'] as String? ?? 'Usuario';
                            final myId =
                                ref.read(authControllerProvider).user?.id ?? '';
                            final senderId = msg['senderId'] as String? ?? '';
                            final effectiveContentUrl =
                                (msg['contentUrl'] as String?)?.isNotEmpty ==
                                        true
                                    ? msg['contentUrl'] as String
                                    : ((msg['mediaUrl'] as String?)
                                                ?.isNotEmpty ==
                                            true
                                        ? msg['mediaUrl'] as String
                                        : (metaMap?['mediaUrl'] as String?));

                            final isMsgMine = senderId.isNotEmpty && senderId == myId;
                            final bubble = RoleChatBubble(
                              isMine: isMsgMine,
                              body: msg['body'] as String? ?? '',
                              senderName: senderName,
                              userName: msg['username'] as String?,
                              role: role,
                              userAvatarUrl: msg['userAvatar'] as String?,
                              adminBadge: msg['adminBadge'] as String?,
                              timestamp: _formatMessageTime(msg),
                              messageType: msg['type'] as String? ?? 'message',
                              contentUrl: effectiveContentUrl,
                              metadata: metaMap,
                              isDiceRoll: isDice,
                              diceResult: msg['diceResult'] as String? ??
                                  metaMap?['diceResult'] as String?,
                              diceEmoji: msg['diceEmoji'] as String? ??
                                  metaMap?['diceEmoji'] as String?,
                              isSticker: isSticker,
                              stickerAsset: msg['stickerAsset'] as String?,
                              stickerEmoji: msg['stickerEmoji'] as String?,
                              replyToId: msg['replyToId']?.toString(),
                              replyToName: msg['replyToName'] as String?,
                              replyToBody: msg['replyToBody'] as String?,
                              onReplyTap: msg['replyToId'] != null
                                  ? () => _scrollToMessage(msg['replyToId']!.toString())
                                  : null,
                              isEdited: msg['isEdited'] == true,
                              editedAt: msg['editedAt']?.toString(),
                              onPollVote: (optionId) {
                                final msgId = '${msg['id'] ?? ''}';
                                _salas.markPollVoted(
                                  widget.roomId,
                                  msgId,
                                  optionId,
                                );
                                setState(() {});
                                if (!msgId.startsWith('local-')) {
                                  ref
                                      .read(roomRepositoryProvider)
                                      .voteRoomPoll(
                                        widget.roomId,
                                        msgId,
                                        optionId: optionId,
                                      )
                                      .catchError((err) {
                                    debugPrint('[POLL_VOTE] Error: $err');
                                    return <String, dynamic>{};
                                  });
                                }
                              },
                              onUserTap: () {
                                final realUsername =
                                    (msg['username'] as String?) ?? '';
                                RoomUserProfileSheet.show(
                                  context,
                                  displayName: senderName,
                                  username: realUsername,
                                  userId: senderId.isEmpty ? null : senderId,
                                  avatarUrl: msg['userAvatar'] as String?,
                                  role: role,
                                  adminBadge: msg['adminBadge'] as String?,
                                  isHost:
                                      room != null &&
                                      (senderId == room.host.id ||
                                          (senderId.isEmpty &&
                                              room.host.displayName ==
                                                  senderName)),
                                  isSelf:
                                      senderId == myId ||
                                      senderName ==
                                          (ref
                                                  .read(authControllerProvider)
                                                  .user
                                                  ?.displayName ??
                                              ''),
                                  canManage: _canManageRoles(),
                                  onViewProfile: () {
                                    if (realUsername
                                        .replaceAll('@', '')
                                        .trim()
                                        .isNotEmpty) {
                                      final cleanU = realUsername
                                          .replaceAll('@', '')
                                          .trim();
                                      Navigator.pop(context);
                                      context.push('/profile/$cleanU');
                                    }
                                  },
                                  onStartDirectChat: () {
                                    _startDirectChatWith(
                                      senderId,
                                      realUsername,
                                    );
                                  },
                                  isMuted: _mutedUserIds.contains(senderId),
                                  onMute: () =>
                                      _toggleMuteUser(senderId, senderName),
                                  onKick: () {
                                    _salas.addRoomMessage(widget.roomId, {
                                      'type': 'system',
                                      'text':
                                          '🚫 $senderName ha sido expulsado/a de la sala',
                                    });
                                    setState(() {});
                                  },
                                );
                              },
                            );

                            final msgKey = 'msg_${msg['id'] ?? index}';
                            return Dismissible(
                              key: ValueKey(msgKey),
                              direction: DismissDirection.startToEnd,
                              confirmDismiss: (dir) async {
                                _startReply(msg);
                                return false;
                              },
                              background: Container(
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.only(left: 16),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.accentCyan.withValues(alpha: 0.18),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.reply_rounded,
                                    color: AppColors.accentCyan,
                                    size: 20,
                                  ),
                                ),
                              ),
                              child: GestureDetector(
                                onLongPress: () => _showMessageContextMenu(msg),
                                child: bubble,
                              ),
                            );
                          },
                        ),
                  ),
                ),

                // ── Barra de Saludos Rápidos (Modo Previa) ──
                if (!_isConnected && _canSendMessage) _buildQuickGreetings(),

                // ── Banner de moderación / sanción activa ──
                if (_isConnected && !_canSendMessage)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(14, 0, 14, 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0x28FF4D6D),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0x55FF4D6D),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Color(0xFFFF4D6D),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _sanctionBannerText ??
                                'Tu cuenta ha sido sancionada/silenciada por moderación.',
                            style: const TextStyle(
                              color: Color(0xFFFF8A9D),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // ── Barra Inferior: Conectado vs Previa ──
                if (_isConnected)
                  ChatMessageInputBar(
                    enabled: _canSendMessage,
                    disabledHint: 'Envío de mensajes bloqueado por moderación',
                    onSendMessage: _sendMessage,
                    onSendImage: _sendImageFromPath,
                    onSendAudio: _sendVoiceNote,
                    onSendDiceRoll: _sendDiceRoll,
                    onSendPoll: _sendPoll,
                    onSendSticker: _sendSticker,
                    onOpenModesTap:
                        _canManageRoles() ? _openRoomModesSelector : null,
                    isRoleplay: _currentRoomMode == 'roleplay',
                    userName:
                        ref
                                .watch(authControllerProvider)
                                .user
                                ?.displayName
                                .isNotEmpty ==
                            true
                        ? ref.watch(authControllerProvider).user!.displayName
                        : (ref.watch(authControllerProvider).user?.username ??
                              'Tú'),
                    userAvatarUrl: ref
                        .watch(authControllerProvider)
                        .user
                        ?.avatarUrl,
                    currentRole: _currentActiveRole,
                    availableRoles: _stageRoles,
                    currentUserId: ref.watch(authControllerProvider).user?.id,
                    isHost: _canManageRoles(),
                    replyingToMessage: _replyingToMessage,
                    onCancelReply: _cancelReply,
                    editingMessage: _editingMessage,
                    onCancelEdit: _cancelEdit,
                    onSendEdit: _submitEdit,
                    onIdentityChanged: (selected) {
                      setState(() => _currentActiveRole = selected);
                    },
                    onRoleChanged: (selected) {
                      setState(() => _currentActiveRole = selected);
                    },
                    onTypingChanged: (typing) {
                      // Mientras se escribe se pausan los emojis animados.
                      _chatAnimationsEnabled.value = !typing;
                    },
                  )
                else
                  _buildPreJoinBottomBar(),
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }

  // ── Botón de redimensión de actividad ──────────────────────────────────────

  Widget _buildStageResizeButton() {
    final bool isVoiceConnected =
        ref.watch(voiceRoomProvider.select((s) => s.isConnected));
    final bool isCurrentMinimized = _currentRoomMode == 'roleplay'
        ? _isRoleplayMinimized
        : (_currentRoomMode == 'voice'
            ? _isVoiceMinimized
            : (_currentRoomMode == 'screening'
                ? _isStageMinimized
                : (isVoiceConnected
                    ? _isVoiceMinimized
                    : _isStageMinimized)));

    return Center(
      child: GestureDetector(
        onTap: () {
          if (_isSwitchingActivity) return;
          _triggerActivityDebounce();
          HapticFeedback.selectionClick();
          setState(() {
            if (_currentRoomMode == 'roleplay') {
              final next = !_isRoleplayMinimized;
              _isRoleplayMinimized = next;
              if (!next) _isVoiceMinimized = true;
            } else if (_currentRoomMode == 'voice') {
              final next = !_isVoiceMinimized;
              _isVoiceMinimized = next;
              if (!next) _isRoleplayMinimized = true;
            } else if (_currentRoomMode == 'screening') {
              final next = !_isStageMinimized;
              _isStageMinimized = next;
              if (!next) {
                _isVoiceMinimized = true;
                _isRoleplayMinimized = true;
              }
            } else if (ref.read(voiceRoomProvider).isConnected &&
                ref.read(voiceRoomProvider).activeRoomId == widget.roomId) {
              final next = !_isVoiceMinimized;
              _isVoiceMinimized = next;
              if (!next) _isRoleplayMinimized = true;
            } else {
              _isStageMinimized = !_isStageMinimized;
            }
          });
        },
        child: Container(
          margin: const EdgeInsets.only(top: 2, bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xCC1F1B2E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF2C2542),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isCurrentMinimized
                    ? Icons.keyboard_arrow_down_rounded
                    : Icons.keyboard_arrow_up_rounded,
                size: 16,
                color: Colors.white70,
              ),
              const SizedBox(width: 4),
              Text(
                isCurrentMinimized ? 'Expandir actividad' : 'Minimizar actividad',
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVoiceActiveElsewhereBanner(String otherRoomId) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 4, 14, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1B162B).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.accentCyan.withValues(alpha: 0.4),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: AppColors.accentCyan.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.phone_in_talk_rounded,
              size: 15,
              color: AppColors.accentCyan,
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'En llamada en otra sala',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFFE2E2F0),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              ref.read(voiceRoomProvider.notifier).leaveRoom();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.accentCrimson.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.accentCrimson.withValues(alpha: 0.5),
                  width: 0.8,
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.call_end_rounded,
                      size: 13, color: AppColors.accentCrimson),
                  SizedBox(width: 4),
                  Text(
                    'Colgar',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.accentCrimson,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Header Superior ──────────────────────────────────────────────────────

  Widget _buildTopHeader(String roomName, Room? room) {
    final hostName = room?.host.displayName ?? room?.host.username ?? 'Host';
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 12, 6),
      child: Row(
        children: [
          // Flecha de regreso limpia
          IconButton(
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: Colors.white,
              size: 22,
            ),
            onPressed: _handleExit,
            tooltip: 'Volver',
            splashRadius: 20,
            constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
            padding: const EdgeInsets.all(6),
          ),
          const SizedBox(width: 4),

          // Portada squircle de la sala (GLL / imagen de portada)
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF2E2744), width: 0.8),
            ),
            clipBehavior: Clip.antiAlias,
            child: (_effectiveCoverUrl != null && _effectiveCoverUrl!.isNotEmpty)
                ? CachedNetworkImage(
                    imageUrl: _effectiveCoverUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => Container(color: const Color(0xFF1E1A2E)),
                    errorWidget: (_, _, _) => _buildRoomCoverFallback(roomName),
                  )
                : _buildRoomCoverFallback(roomName),
          ),
          const SizedBox(width: 10),

          // Título y Host
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  roomName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    // Avatar circular pequeño del host/owner
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.accentCyan.withValues(alpha: 0.6),
                          width: 1,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: room?.host.avatarUrl != null &&
                              room!.host.avatarUrl!.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: room.host.avatarUrl!,
                              fit: BoxFit.cover,
                              errorWidget: (_, _, _) => const Icon(
                                Icons.person_rounded,
                                size: 12,
                                color: Colors.white70,
                              ),
                            )
                          : const Icon(
                              Icons.person_rounded,
                              size: 12,
                              color: Colors.white70,
                            ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      hostName,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accentTeal,
                      ),
                    ),
                    if (room?.host.isVerified == true) ...[
                      const SizedBox(width: 4),
                      Image.asset(
                        AppAssets.iconVerificados,
                        width: 14,
                        height: 14,
                        fit: BoxFit.contain,
                      ),
                    ],
                    const SizedBox(width: 6),
                    _buildFollowButton(room),
                  ],
                ),
              ],
            ),
          ),

          // Botón Invitar amigos
          IconButton(
            tooltip: 'Invitar amigos',
            icon: const Icon(
              Icons.person_add_alt_1_rounded,
              color: Colors.white70,
              size: 20,
            ),
            onPressed: room != null
                ? () => RoomInviteFriendsSheet.show(context, room: room)
                : null,
          ),

          // Botón Info ⓘ
          IconButton(
            icon: const Icon(
              Icons.info_outline_rounded,
              color: Colors.white70,
              size: 20,
            ),
            onPressed: () => _openRoomInfo(room),
          ),

          // Menú de opciones de la sala: contiene "Abandonar sala" (•••).
          IconButton(
            icon: const Icon(
              Icons.more_vert_rounded,
              color: Colors.white70,
              size: 20,
            ),
            onPressed: _showRoomMenu,
          ),
        ],
      ),
    );
  }

  /// Iniciales o fallback squircle para la portada de sala cuando no hay imagen.
  Widget _buildRoomCoverFallback(String name) {
    final trimmed = name.trim();
    final initials = trimmed.isNotEmpty
        ? (trimmed.length <= 3
            ? trimmed.toUpperCase()
            : trimmed.substring(0, 2).toUpperCase())
        : 'S';
    return Container(
      color: AppColors.avatarColor(name),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // ── Barra de Anuncios ────────────────────────────────────────────────────

  Widget _buildAnnouncementBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x99181428),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF28223C), width: 0.6),
      ),
      child: const Row(
        children: [
          Icon(Icons.campaign_rounded, size: 16, color: Color(0xFFFFB300)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Announcement: Bienvenidos a la sesión nocturna de Beacon Hills. ¡Mantengan el lore activo!',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFFD0D0E0),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Píldora de Participantes (👥 N personas, debajo del anuncio) ──────────

  Widget _buildMemberPill(Room? room) {
    final memberCount = room != null && room.participantCount > 0
        ? room.participantCount
        : room?.participants.length ?? 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 2),
      child: Align(
        alignment: Alignment.centerRight,
        child: GestureDetector(
          onTap: () => _showParticipantsSheet(room),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xB3181528),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF2C2544), width: 0.8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.people_alt_rounded,
                  size: 13,
                  color: Color(0xFF9E9EA8),
                ),
                const SizedBox(width: 4),
                Text(
                  '$memberCount personas',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Bottom sheet que lista a los miembros/participantes presentes en la sala.
  void _showParticipantsSheet(Room? room) {
    final participants = room?.participants ?? const [];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF13101E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3A3A4A),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Participantes (${participants.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              if (participants.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: Text(
                      'Aún no hay participantes visibles',
                      style: TextStyle(color: Color(0xFF9E9EA8), fontSize: 12.5),
                    ),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.5,
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: participants.length,
                    itemBuilder: (ctx, i) {
                      final p = participants[i];
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: AppAvatar(
                          imageUrl: p.user.avatarUrl,
                          name: p.user.displayName,
                          radius: 18,
                        ),
                        title: Text(
                          p.user.displayName.isNotEmpty
                              ? p.user.displayName
                              : p.user.username,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          p.role,
                          style: const TextStyle(
                            color: Color(0xFF9E9EA8),
                            fontSize: 11.5,
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Saludos Rápidos ──────────────────────────────────────────────────────

  Widget _buildQuickGreetings() {
    const greetings = ['Hi', 'Hello, 👋', 'Invite me, 🥳', 'How are you doing'];

    return Container(
      height: 36,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: greetings.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final text = greetings[index];
          return GestureDetector(
            onTap: () => _sendMessage(text),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF181428),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF2C2544), width: 0.8),
              ),
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFC0C0D4),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Barra Inferior Modo Pre-Join ─────────────────────────────────────────

  Widget _buildPreJoinBottomBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        14,
        8,
        14,
        12 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF13101E),
        border: Border(top: BorderSide(color: Color(0xFF221D32), width: 0.8)),
      ),
      child: Row(
        children: [
          // Campo simulación
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF1B172B),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF2E2746), width: 0.8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.centerLeft,
              child: const Text(
                'Message...',
                style: TextStyle(color: Color(0xFF6E6888), fontSize: 13.5),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Botón Switch (Cambiar rol / Adoptar desde la Biblioteca de Roles)
          GestureDetector(
            onTap: () async {
              final chosen = await RoleLibraryScreen.showPicker(context);
              if (chosen != null && mounted) {
                _onRoleSelectedFromLibrary(chosen);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1930),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF332B4F), width: 0.8),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: 14,
                    color: AppColors.accentCyan,
                  ),
                  SizedBox(width: 5),
                  Text(
                    'Switch',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Botón Join (Conectarse formalmente)
          GestureDetector(
            onTap: () {
              // Gamefeel: impacto medio al unirse a una sala de roleplay.
              HapticFeedback.mediumImpact();
              setState(() => _isConnected = true);
              _joinRoom();
              _startRoomChat();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('¡Conectado a la Sala de Roleplay! 🎭'),
                  backgroundColor: Color(0xFF0F3A3A),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFF0E3838),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.accentCyan, width: 1),
              ),
              child: const Text(
                'Join',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: AppColors.accentCyan,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
