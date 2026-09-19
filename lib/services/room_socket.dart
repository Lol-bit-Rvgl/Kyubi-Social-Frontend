import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:socket_io_client/socket_io_client.dart' as io;

import 'base_socket.dart';

/// Evento recibido por socket de salas.
sealed class RoomSocketEvent {}

/// Llega un mensaje nuevo a una sala en la que estamos unidos.
class RoomMessageReceived extends RoomSocketEvent {
  RoomMessageReceived(this.roomId, this.payload);
  final String roomId;
  final Map<String, dynamic> payload;
}

/// Sincronización de la Sala de Cine: acción confirmada del host,
/// con `videoId`, `currentTime` y marca de tiempo (`updatedAt`).
class RoomCinemaSync extends RoomSocketEvent {
  RoomCinemaSync(this.roomId, this.payload);
  final String roomId;
  final Map<String, dynamic> payload;

  String get action => payload['action'] as String? ?? '';
  String? get videoId => payload['videoId'] as String?;
  double get currentTime =>
      (payload['currentTime'] as num?)?.toDouble() ?? 0;
  DateTime? get updatedAt => DateTime.tryParse(
      payload['updatedAt'] as String? ?? '',
  );
}

/// Cambio de modo de sala broadcast por el server (`room:mode_changed`).
class RoomModeChanged extends RoomSocketEvent {
  RoomModeChanged(this.roomId, this.payload);
  final String roomId;
  final Map<String, dynamic> payload;

  String get mode => payload['mode'] as String? ?? '';
  String? get actorId => payload['actorId'] as String?;
  String? get actorName => payload['actorName'] as String?;
  String? get cinemaVideoId => payload['cinemaVideoId'] as String?;
  String? get cinemaState => payload['cinemaState'] as String?;
  double? get cinemaCurrentTime =>
      (payload['cinemaCurrentTime'] as num?)?.toDouble();
}

/// Moderación del canal de voz broadcast por el server (`room:voice_moderated`).
class RoomVoiceModerated extends RoomSocketEvent {
  RoomVoiceModerated(this.roomId, this.payload);
  final String roomId;
  final Map<String, dynamic> payload;

  String get action => payload['action'] as String? ?? '';
  String? get targetUserId => payload['targetUserId'] as String?;
  String? get targetName => payload['targetName'] as String?;
  String? get actorId => payload['actorId'] as String?;
  String? get actorName => payload['actorName'] as String?;
  bool? get staffOnly => payload['staffOnly'] as bool?;
}

/// Actualización de rol de personaje en el Roleplay Stage broadcast por el server (`room:stage_role`).
class RoomStageRoleChanged extends RoomSocketEvent {
  RoomStageRoleChanged(this.roomId, this.payload);
  final String roomId;
  final Map<String, dynamic> payload;

  String get action => payload['action'] as String? ?? '';
  String? get roleId => payload['roleId'] as String?;
  String? get userId => payload['userId'] as String?;
  String? get username => payload['username'] as String?;
  Map<String, dynamic>? get role => payload['role'] is Map
      ? Map<String, dynamic>.from(payload['role'] as Map)
      : null;
  List<dynamic>? get stageRoles => payload['stageRoles'] as List<dynamic>?;
}

/// Actualización de encuesta votada (`room:poll_voted`).
class RoomPollVoted extends RoomSocketEvent {
  RoomPollVoted(this.roomId, this.payload);
  final String roomId;
  final Map<String, dynamic> payload;

  String get messageId => payload['messageId'] as String? ?? '';
  String? get userId => payload['userId'] as String?;
  String? get optionId => payload['optionId'] as String?;
  int? get optionIndex => (payload['optionIndex'] as num?)?.toInt();
  int? get totalVotes => (payload['totalVotes'] as num?)?.toInt();
  List<dynamic>? get voteCounts => payload['voteCounts'] as List<dynamic>?;
  List<dynamic>? get options => payload['options'] as List<dynamic>?;
}

/// El server rechazó un cambio de modo porque ya hay una actividad activa.
class RoomModeRejected extends RoomSocketEvent {
  RoomModeRejected(this.roomId, this.payload);
  final String roomId;
  final Map<String, dynamic> payload;

  String get currentMode => payload['currentMode'] as String? ?? '';
  String get requestedMode => payload['requestedMode'] as String? ?? '';
  String get reason => payload['reason'] as String? ?? '';
}

/// La cuenta del usuario conectado ha recibido una sanción (`account:sanctioned`).
class RoomAccountSanctioned extends RoomSocketEvent {
  RoomAccountSanctioned(this.payload);
  final Map<String, dynamic> payload;

  String get action => (payload['action'] as String?)?.toUpperCase() ?? 'WARN';
  String get reason => (payload['reason'] as String?)?.trim().isNotEmpty == true
      ? payload['reason'] as String
      : 'Tu cuenta ha sido sancionada por moderación.';
  DateTime? get suspendedUntil {
    final raw = (payload['suspendedUntil'] ?? payload['expiresAt']) as String?;
    return raw != null ? DateTime.tryParse(raw) : null;
  }

  bool get isSessionKilling => action == 'SUSPEND' || action == 'BAN';
}

/// Error por moderación devuelto al intentar una acción o enviar mensaje (`error:sanctioned`).
class RoomErrorSanctioned extends RoomSocketEvent {
  RoomErrorSanctioned(this.payload);
  final Map<String, dynamic> payload;

  String get message => (payload['message'] as String?)?.trim().isNotEmpty == true
      ? payload['message'] as String
      : 'Tu cuenta ha sido sancionada/silenciada por moderación.';
  DateTime? get suspendedUntil {
    final raw = (payload['suspendedUntil'] ?? payload['expiresAt']) as String?;
    return raw != null ? DateTime.tryParse(raw) : null;
  }
}

/// Desconexión forzada enviada por el servidor (`force:disconnect`).
class RoomForceDisconnect extends RoomSocketEvent {
  RoomForceDisconnect(this.payload);
  final Map<String, dynamic> payload;

  String get reason => (payload['reason'] as String?)?.trim().isNotEmpty == true
      ? payload['reason'] as String
      : 'Desconexión forzada por moderación.';
}

/// Mensaje de sala actualizado/editado broadcast por el server (`room:message_updated`).
class RoomMessageUpdated extends RoomSocketEvent {
  RoomMessageUpdated(this.roomId, this.payload);
  final String roomId;
  final Map<String, dynamic> payload;

  String get messageId =>
      payload['messageId'] as String? ?? payload['id'] as String? ?? '';
  String get content =>
      payload['content'] as String? ?? payload['body'] as String? ?? '';
  bool get isEdited => payload['isEdited'] == true;
  String? get editedAt => payload['editedAt'] as String?;
}

/// Mensaje de sala eliminado broadcast por el server (`room:message_deleted`).
class RoomMessageDeleted extends RoomSocketEvent {
  RoomMessageDeleted(this.roomId, this.payload);
  final String roomId;
  final Map<String, dynamic> payload;

  String get messageId =>
      payload['messageId'] as String? ?? payload['deletedMessageId'] as String? ?? '';
}

/// Notificación de rate limit / anti-spam enviada por el servidor (`room:rate_limited`).
class RoomRateLimited extends RoomSocketEvent {
  RoomRateLimited(this.payload);
  final Map<String, dynamic> payload;

  String get message =>
      payload['message'] as String? ??
      'Por favor no spamees. Espera un momento antes de enviar otro mensaje.';
  int get retryAfterMs => (payload['retryAfterMs'] as num?)?.toInt() ?? 1500;
}

/// Notificación en tiempo real de invitación a una sala (`room:invited`).
class RoomInvited extends RoomSocketEvent {
  RoomInvited(this.payload);
  final Map<String, dynamic> payload;

  String get roomId => payload['roomId'] as String? ?? '';
  String get roomName => payload['roomName'] as String? ?? 'Sala';
  String? get roomBanner => payload['roomBanner'] as String?;
  String get senderId => payload['senderId'] as String? ?? '';
  String get senderUsername =>
      payload['senderUsername'] as String? ?? 'Usuario';
  String get timestamp => payload['timestamp'] as String? ?? '';
}

/// Cliente Socket.IO para el chat en vivo de las salas.
class RoomSocketService extends BaseSocket<RoomSocketEvent> {
  RoomSocketService._()
      : super(
          serviceName: 'room',
          transports: const ['websocket', 'polling'],
          reconnectionAttempts: 5,
          reconnectionDelay: 2000,
        );

  static final RoomSocketService instance = RoomSocketService._();

  final _joinedRooms = <String>{};

  /// Normaliza el nombre de modo para interoperabilidad total.
  static String normalizeMode(String mode) {
    final m = mode.trim().toLowerCase();
    if (m == 'cinema' || m == 'screening' || m == 'cine' || m == 'movie') {
      return 'screening';
    }
    if (m == 'voice' || m == 'voz' || m == 'audio') {
      return 'voice';
    }
    if (m == 'roleplay' || m == 'rp' || m == 'rol') {
      return 'roleplay';
    }
    return 'standard';
  }

  @override
  void registerCustomEvents(io.Socket socket) {
    socket.on('room:message', (payload) {
      final data = asMap(payload);
      final roomId = data['roomId'] as String? ?? '';
      if (roomId.isNotEmpty) {
        emitEvent(RoomMessageReceived(roomId, data));
      }
    });

    socket.on('cinema:sync', (payload) {
      final data = asMap(payload);
      final roomId = data['roomId'] as String? ?? '';
      if (roomId.isNotEmpty) {
        emitEvent(RoomCinemaSync(roomId, data));
      }
    });

    socket.on('room:mode_changed', (payload) {
      final data = asMap(payload);
      final roomId = data['roomId'] as String? ?? '';
      if (roomId.isNotEmpty) {
        emitEvent(RoomModeChanged(roomId, data));
      }
    });

    socket.on('room:mode_rejected', (payload) {
      final data = asMap(payload);
      final roomId = data['roomId'] as String? ?? '';
      if (roomId.isNotEmpty) {
        emitEvent(RoomModeRejected(roomId, data));
      }
    });

    socket.on('room:voice_moderated', (payload) {
      final data = asMap(payload);
      final roomId = data['roomId'] as String? ?? '';
      if (roomId.isNotEmpty) {
        emitEvent(RoomVoiceModerated(roomId, data));
      }
    });

    socket.on('room:stage_role', (payload) {
      final data = asMap(payload);
      final roomId = data['roomId'] as String? ?? '';
      if (roomId.isNotEmpty) {
        emitEvent(RoomStageRoleChanged(roomId, data));
      }
    });

    socket.on('roleplay:slot_updated', (payload) {
      final data = asMap(payload);
      final roomId = data['roomId'] as String? ?? '';
      if (roomId.isNotEmpty) {
        emitEvent(RoomStageRoleChanged(roomId, data));
      }
    });

    socket.on('room:poll_voted', (payload) {
      final data = asMap(payload);
      final roomId = data['roomId'] as String? ?? '';
      if (roomId.isNotEmpty) {
        emitEvent(RoomPollVoted(roomId, data));
      }
    });

    socket.on('room:message_updated', (payload) {
      final data = asMap(payload);
      final roomId = data['roomId'] as String? ?? '';
      if (roomId.isNotEmpty) {
        emitEvent(RoomMessageUpdated(roomId, data));
      }
    });

    socket.on('room:message_deleted', (payload) {
      final data = asMap(payload);
      final roomId = data['roomId'] as String? ?? '';
      if (roomId.isNotEmpty) {
        emitEvent(RoomMessageDeleted(roomId, data));
      }
    });

    socket.on('account:sanctioned', (payload) {
      final data = asMap(payload);
      emitEvent(RoomAccountSanctioned(data));
    });

    socket.on('error:sanctioned', (payload) {
      final data = asMap(payload);
      emitEvent(RoomErrorSanctioned(data));
    });

    socket.on('force:disconnect', (payload) {
      final data = asMap(payload);
      emitEvent(RoomForceDisconnect(data));
    });

    socket.on('room:rate_limited', (payload) {
      final data = asMap(payload);
      emitEvent(RoomRateLimited(data));
    });

    socket.on('room:invited', (payload) {
      final data = asMap(payload);
      emitEvent(RoomInvited(data));
    });

    socket.on('room:invite_received', (payload) {
      final data = asMap(payload);
      emitEvent(RoomInvited(data));
    });
  }

  @override
  void onDisconnected(dynamic reason) {
    if (reason == 'manual_disconnect') {
      _joinedRooms.clear();
    }
  }

  @override
  void onConnected() {
    _rejoin();
  }

  void joinRoom(String roomId) {
    _joinedRooms.add(roomId);
    if (kDebugMode) {
      debugPrint('[SOCKET_DEBUG][room] joinRoom($roomId) connected=${socket?.connected}');
    }
    socket?.emit('room:join', roomId);
  }

  void leaveRoom(String roomId) {
    _joinedRooms.remove(roomId);
    socket?.emit('room:leave', roomId);
  }

  /// El host envía una acción de cine al servidor (play/pause/seek/load).
  /// El backend valida que es HOST y retransmite `cinema:sync`.
  void emitCinemaAction({
    required String roomId,
    required String action,
    String? videoId,
    double? currentTime,
  }) {
    socket?.emit('cinema:action', {
      'roomId': roomId,
      'action': action,
      if (videoId != null && videoId.isNotEmpty) 'videoId': videoId,
      'currentTime': ?currentTime,
    });
  }

  /// El host/co-host cambia el modo de sala (voice/roleplay/screening/standard).
  /// El backend valida el rol y retransmite `room:mode_changed`.
  void emitModeChange(
    String roomId,
    String mode, {
    String? videoId,
    String? cinemaState,
    double? currentTime,
  }) {
    final normalized = normalizeMode(mode);
    if (kDebugMode) {
      debugPrint('[SOCKET_DEBUG][room] emitModeChange($roomId, $normalized) '
          'connected=${socket?.connected}');
    }
    socket?.emit('room:mode-change', {
      'roomId': roomId,
      'mode': normalized,
      if (videoId != null && videoId.isNotEmpty) 'videoId': videoId,
      if (cinemaState != null && cinemaState.isNotEmpty)
        'cinemaState': cinemaState,
      'currentTime': ?currentTime,
    });
  }

  /// Moderación del canal de voz (mute/unmute/kick/staff_only/allow_speaker/revoke_speaker).
  /// Solo lo procesa el backend si el emisor es Host/Co-Host de la sala.
  void emitVoiceModeration({
    required String roomId,
    required String action,
    String? targetUserId,
    String? targetUsername,
    bool? staffOnly,
  }) {
    socket?.emit('room:voice-moderation', {
      'roomId': roomId,
      'action': action,
      if (targetUserId != null && targetUserId.isNotEmpty)
        'targetUserId': targetUserId,
      if (targetUsername != null && targetUsername.isNotEmpty)
        'targetUsername': targetUsername,
      'staffOnly': ?staffOnly,
    });
  }

  /// Emite una invitación a un usuario para unirse a una sala (`room:invite`).
  void emitInvite({
    required String roomId,
    required String targetUserId,
    String? roomName,
    String? roomBanner,
  }) {
    socket?.emit('room:invite', {
      'roomId': roomId,
      'targetUserId': targetUserId,
      if (roomName != null && roomName.isNotEmpty) 'roomName': roomName,
      if (roomBanner != null && roomBanner.isNotEmpty) 'roomBanner': roomBanner,
    });
  }

  void _rejoin() {
    for (final roomId in _joinedRooms) {
      socket?.emit('room:join', roomId);
    }
  }

  @override
  void disconnect() {
    super.disconnect();
    _joinedRooms.clear();
  }
}
