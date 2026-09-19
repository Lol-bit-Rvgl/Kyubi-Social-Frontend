import 'post_author.dart';
import 'role_character.dart';

/// Estado de una sala (`RoomStatus` del backend).
enum RoomStatus {
  active,
  ended;

  static RoomStatus fromJson(String? value) {
    return value == 'ENDED' ? RoomStatus.ended : RoomStatus.active;
  }
}

/// Acceso de una sala (`RoomAccess` del backend).
enum RoomAccess {
  public,
  private;

  static RoomAccess fromJson(String? value) {
    return value == 'PRIVATE' ? RoomAccess.private : RoomAccess.public;
  }

  String get wireValue => this == RoomAccess.private ? 'PRIVATE' : 'PUBLIC';
}

/// Tipo de sala (`RoomKind` del backend).
enum RoomKind {
  social;

  static RoomKind fromJson(String? value) {
    return value == 'SOCIAL' ? RoomKind.social : RoomKind.social;
  }
}

/// Círculo al que pertenece una sala (referencia reducida del backend).
class RoomCircle {
  const RoomCircle({required this.id, required this.name, this.avatarUrl});

  final String id;
  final String name;
  final String? avatarUrl;

  factory RoomCircle.fromJson(Map<String, dynamic> json) {
    return RoomCircle(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String?,
    );
  }
}

/// Participante de una sala (`serializeRoomParticipant` del backend).
class RoomParticipant {
  const RoomParticipant({
    required this.user,
    required this.role,
    required this.joinedAt,
    this.activeCharacter,
  });

  final PostAuthor user;
  final String role;
  final String joinedAt;
  final RoleCharacter? activeCharacter;

  factory RoomParticipant.fromJson(Map<String, dynamic> json) {
    return RoomParticipant(
      user: PostAuthor.fromJson(json),
      role: json['role'] as String? ?? 'PARTICIPANT',
      joinedAt: json['joinedAt'] as String? ?? '',
      activeCharacter: json['activeCharacter'] != null &&
              json['activeCharacter'] is Map<String, dynamic>
          ? RoleCharacter.fromJson(
              json['activeCharacter'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Sala de reuniones en vivo (`serializeRoom` del backend).
class Room {
  const Room({
    required this.id,
    required this.name,
    required this.host,
    this.description,
    this.imageUrl,
    this.chatBackgroundUrl,
    this.cinemaVideoId,
    this.cinemaState = 'STOPPED',
    this.cinemaCurrentTime = 0.0,
    this.cinemaUpdatedAt,
    this.currentMode = 'standard',
    this.status = RoomStatus.active,
    this.access = RoomAccess.public,
    this.kind = RoomKind.social,
    this.capacity,
    this.isHost = false,
    this.isParticipant = false,
    this.participantCount = 0,
    this.participants = const [],
    this.tags = const [],
    this.rules = const [],
    this.activeCharacter,
    this.stageRoles = const [],
    this.circle,
    this.createdAt,
    this.endedAt,
  });

  final String id;
  final String name;
  final String? description;
  final String? imageUrl;
  final String? chatBackgroundUrl;
  final String? cinemaVideoId;
  final String cinemaState;
  final double cinemaCurrentTime;
  final DateTime? cinemaUpdatedAt;
  final String currentMode;
  final RoleCharacter? activeCharacter;
  final List<RoleCharacter> stageRoles;
  final PostAuthor host;
  final RoomStatus status;
  final RoomAccess access;
  final RoomKind kind;
  final int? capacity;
  final bool isHost;
  final bool isParticipant;
  final int participantCount;
  final List<RoomParticipant> participants;
  final List<String> tags;
  final List<String> rules;
  final RoomCircle? circle;
  final String? createdAt;
  final String? endedAt;

  String get hostId => host.id;
  bool get hasCircle => circle != null;
  String? get lore => description;
  bool get isFull =>
      capacity != null && capacity! > 0 && participantCount >= capacity!;

  /// Si el cine está en reproducción, estima el segundo actual sumando el
  /// tiempo transcurrido desde `cinemaUpdatedAt` a `cinemaCurrentTime`.
  double get cinemaEstimatedPosition {
    if (cinemaState != 'PLAYING' || cinemaUpdatedAt == null) {
      return cinemaCurrentTime;
    }
    final elapsed =
        DateTime.now().difference(cinemaUpdatedAt!).inMilliseconds / 1000.0;
    return cinemaCurrentTime + elapsed;
  }

  /// Determina si la sala tiene actividad de voz / charla.
  bool get isVoice {
    final mode = currentMode.toLowerCase().trim();
    if (mode == 'voice') return true;
    return tags.any((t) {
      final s = t.toLowerCase().trim();
      return s.contains('voz') ||
          s.contains('voice') ||
          s.contains('chill') ||
          s.contains('charla');
    });
  }

  /// Determina si la sala tiene actividad de cine o reproducción compartida.
  bool get isScreening {
    final mode = currentMode.toLowerCase().trim();
    if (mode == 'screening' || mode == 'cinema') return true;
    if (cinemaVideoId != null && cinemaVideoId!.isNotEmpty) return true;
    return tags.any((t) {
      final s = t.toLowerCase().trim();
      return s.contains('screening') ||
          s.contains('cine') ||
          s.contains('video') ||
          s.contains('pelicula') ||
          s.contains('película');
    });
  }

  /// Determina si la sala tiene escenario o temática de juego de rol (Roleplay/RP/OCs).
  bool get isRoleplay {
    final mode = currentMode.toLowerCase().trim();
    if (mode == 'roleplay' || mode == 'rpg' || mode == 'stage') return true;
    if (stageRoles.isNotEmpty) return true;
    return tags.any((t) {
      final s = t.toLowerCase().trim();
      return s.contains('rol') || s.contains('rp') || s.contains('roleplay');
    });
  }

  /// Verifica si la sala coincide con una categoría o actividad seleccionada.
  bool matchesCategory(String category) {
    final cat = category.toLowerCase().trim();
    if (cat.isEmpty) return true;
    if (cat.contains('voice') || cat.contains('voz')) return isVoice;
    if (cat.contains('screening') || cat.contains('cinema') || cat.contains('cine')) {
      return isScreening;
    }
    if (cat.contains('roleplay') || cat.contains('rol') || cat.contains('rp')) {
      return isRoleplay;
    }
    return tags.any((t) => t.toLowerCase().trim().contains(cat));
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      imageUrl: json['imageUrl'] as String?,
      chatBackgroundUrl: json['chatBackgroundUrl'] as String?,
      cinemaVideoId: json['cinemaVideoId'] as String?,
      cinemaState: json['cinemaState'] as String? ?? 'STOPPED',
      cinemaCurrentTime: (json['cinemaCurrentTime'] as num?)?.toDouble() ?? 0.0,
      cinemaUpdatedAt: _parseDateTime(json['cinemaUpdatedAt']),
      currentMode: (json['currentMode'] as String?) ??
          (json['mode'] as String?) ??
          'standard',
      host: PostAuthor.fromJson(
        json['host'] as Map<String, dynamic>? ?? const {},
      ),
      status: RoomStatus.fromJson(json['status'] as String?),
      access: RoomAccess.fromJson(json['access'] as String?),
      kind: RoomKind.fromJson(json['kind'] as String?),
      capacity: (json['capacity'] as num?)?.toInt(),
      isHost: json['isHost'] as bool? ?? false,
      isParticipant: json['isParticipant'] as bool? ?? false,
      participantCount: (json['participantCount'] as num?)?.toInt() ?? 0,
      participants: _participants(json['participants']),
      tags: _strings(json['tags']),
      rules: _strings(json['rules']),
      activeCharacter: json['activeCharacter'] is Map
          ? RoleCharacter.fromJson(
              Map<String, dynamic>.from(json['activeCharacter'] as Map))
          : null,
      stageRoles: (json['stageRoles'] as List<dynamic>?)
              ?.map((e) => e is Map
                  ? RoleCharacter.fromJson(Map<String, dynamic>.from(e))
                  : null)
              .whereType<RoleCharacter>()
              .where((r) => r.id.trim().isNotEmpty && r.name.trim().isNotEmpty)
              .toList() ??
          const [],
      circle: json['circle'] == null
          ? null
          : RoomCircle.fromJson(json['circle'] as Map<String, dynamic>),
      createdAt: json['createdAt'] as String?,
      endedAt: json['endedAt'] as String?,
    );
  }

  static List<RoomParticipant> _participants(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map<String, dynamic>>()
        .map(RoomParticipant.fromJson)
        .toList();
  }

  static List<String> _strings(dynamic value) {
    if (value is! List) return const [];
    return value
        .where((e) => e != null)
        .map((e) => e.toString().trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  Room copyWith({
    String? name,
    String? description,
    String? imageUrl,
    String? chatBackgroundUrl,
    String? cinemaVideoId,
    bool clearCinemaVideo = false,
    String? cinemaState,
    double? cinemaCurrentTime,
    DateTime? cinemaUpdatedAt,
    String? currentMode,
    RoleCharacter? activeCharacter,
    bool clearActiveCharacter = false,
    List<RoleCharacter>? stageRoles,
    PostAuthor? host,
    RoomStatus? status,
    RoomAccess? access,
    RoomKind? kind,
    int? capacity,
    bool? isHost,
    bool? isParticipant,
    int? participantCount,
    List<RoomParticipant>? participants,
    List<String>? tags,
    List<String>? rules,
    RoomCircle? circle,
    String? createdAt,
    String? endedAt,
  }) {
    return Room(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      chatBackgroundUrl: chatBackgroundUrl ?? this.chatBackgroundUrl,
      cinemaVideoId:
          clearCinemaVideo ? null : (cinemaVideoId ?? this.cinemaVideoId),
      cinemaState: cinemaState ?? this.cinemaState,
      cinemaCurrentTime: cinemaCurrentTime ?? this.cinemaCurrentTime,
      cinemaUpdatedAt: cinemaUpdatedAt ?? this.cinemaUpdatedAt,
      currentMode: currentMode ?? this.currentMode,
      activeCharacter: clearActiveCharacter
          ? null
          : (activeCharacter ?? this.activeCharacter),
      stageRoles: stageRoles ?? this.stageRoles,
      host: host ?? this.host,
      status: status ?? this.status,
      access: access ?? this.access,
      kind: kind ?? this.kind,
      capacity: capacity ?? this.capacity,
      isHost: isHost ?? this.isHost,
      isParticipant: isParticipant ?? this.isParticipant,
      participantCount: participantCount ?? this.participantCount,
      participants: participants ?? this.participants,
      tags: tags ?? this.tags,
      rules: rules ?? this.rules,
      circle: circle ?? this.circle,
      createdAt: createdAt ?? this.createdAt,
      endedAt: endedAt ?? this.endedAt,
    );
  }
}

/// Resultado de `POST /salas/:id/leave`.
class RoomLeaveResult {
  const RoomLeaveResult({
    required this.success,
    this.ended = false,
    this.status,
  });

  final bool success;
  final bool ended;
  final String? status;

  factory RoomLeaveResult.fromJson(Map<String, dynamic> json) {
    return RoomLeaveResult(
      success: json['success'] as bool? ?? false,
      ended: json['ended'] as bool? ?? false,
      status: json['status'] as String?,
    );
  }
}

/// Mensaje de chat de una sala (`serializeRoomMessage` del backend).
class RoomChatMessage {
  const RoomChatMessage({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.sender,
    required this.body,
    required this.createdAt,
    this.type = 'TEXT',
    this.content,
    this.mediaUrl,
    this.attachments = const [],
    this.diceResult,
    this.diceEmoji,
    this.diceName,
    this.metadata,
    this.senderName,
    this.username,
    this.roleId,
    this.roleName,
    this.roleColor,
    this.clientTempId,
    this.senderAvatarUrl,
    this.replyToId,
    this.replyToName,
    this.replyToBody,
    this.isEdited = false,
    this.editedAt,
    this.editCount = 0,
  });

  final String id;
  final String roomId;
  final String senderId;
  final PostAuthor sender;
  final String body;
  final DateTime createdAt;

  /// Tipo del contenido: `TEXT`, `VOICE`, `IMAGE`, `POLL`, `DICE`, `RPS` o `SYSTEM`.
  final String type;

  /// Contenido estructurado: texto (TEXT), URL de audio (VOICE) o imagen (IMAGE).
  final String? content;

  /// URL de archivo multimedia (imagen o nota de voz).
  final String? mediaUrl;

  /// Lista de URLs adjuntas en el mensaje.
  final List<String> attachments;

  /// Resultado de tirada de dados o morra (D4, D6, Morra, etc.).
  final String? diceResult;
  final String? diceEmoji;
  final String? diceName;

  /// Metadatos del contenido (p. ej. `{question, options}` para POLL).
  final Map<String, dynamic>? metadata;

  /// Alias de conveniencia para metadatos o extensiones del backend.
  Map<String, dynamic>? get extensions => metadata;

  /// Nombre visible del autor (displayName o username), ya resuelto.
  final String? senderName;
  final String? username;
  final String? roleId;
  final String? roleName;
  final String? roleColor;
  final String? clientTempId;
  final String? senderAvatarUrl;

  /// Cita o respuesta a otro mensaje (Reply).
  final String? replyToId;
  final String? replyToName;
  final String? replyToBody;

  /// Estado de edición (máximo 1 vez).
  final bool isEdited;
  final String? editedAt;
  final int editCount;

  RoomChatMessage copyWith({
    String? id,
    String? roomId,
    String? senderId,
    PostAuthor? sender,
    String? body,
    DateTime? createdAt,
    String? type,
    String? content,
    String? mediaUrl,
    List<String>? attachments,
    String? diceResult,
    String? diceEmoji,
    String? diceName,
    Map<String, dynamic>? metadata,
    String? senderName,
    String? username,
    String? roleId,
    String? roleName,
    String? roleColor,
    String? clientTempId,
    String? senderAvatarUrl,
    String? replyToId,
    String? replyToName,
    String? replyToBody,
    bool? isEdited,
    String? editedAt,
    int? editCount,
  }) {
    return RoomChatMessage(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      senderId: senderId ?? this.senderId,
      sender: sender ?? this.sender,
      body: body ?? this.body,
      createdAt: createdAt ?? this.createdAt,
      type: type ?? this.type,
      content: content ?? this.content,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      attachments: attachments ?? this.attachments,
      diceResult: diceResult ?? this.diceResult,
      diceEmoji: diceEmoji ?? this.diceEmoji,
      diceName: diceName ?? this.diceName,
      metadata: metadata ?? this.metadata,
      senderName: senderName ?? this.senderName,
      username: username ?? this.username,
      roleId: roleId ?? this.roleId,
      roleName: roleName ?? this.roleName,
      roleColor: roleColor ?? this.roleColor,
      clientTempId: clientTempId ?? this.clientTempId,
      senderAvatarUrl: senderAvatarUrl ?? this.senderAvatarUrl,
      replyToId: replyToId ?? this.replyToId,
      replyToName: replyToName ?? this.replyToName,
      replyToBody: replyToBody ?? this.replyToBody,
      isEdited: isEdited ?? this.isEdited,
      editedAt: editedAt ?? this.editedAt,
      editCount: editCount ?? this.editCount,
    );
  }

  factory RoomChatMessage.fromJson(Map<String, dynamic> json) {
    final metadata = json['metadata'] ?? json['extensions'];
    final metaMap =
        metadata is Map ? Map<String, dynamic>.from(metadata) : <String, dynamic>{};
    if (json['userVotedOptionId'] != null) {
      metaMap['userVotedOptionId'] = json['userVotedOptionId'];
    }
    if (json['userVotedOptionIndex'] != null) {
      metaMap['userVotedOptionIndex'] = json['userVotedOptionIndex'];
    }
    if (json['totalVotes'] != null) {
      metaMap['totalVotes'] = json['totalVotes'];
    }
    if (json['voteCounts'] != null) {
      metaMap['voteCounts'] = json['voteCounts'];
    }
    final roleColor = json['roleColor'] as String? ??
        json['characterColor'] as String? ??
        (json['role'] is Map
            ? (json['role']['colorHex'] ?? json['role']['color'])
            : null) as String? ??
        metaMap['roleColor'] as String? ??
        metaMap['roleColorHex'] as String? ??
        metaMap['colorHex'] as String?;
    final clientTempId = json['clientTempId'] as String? ??
        metaMap['clientTempId'] as String? ??
        metaMap['nonce'] as String?;
    final rawType = (json['type'] as String? ?? 'TEXT').toUpperCase();
    final body = json['body'] as String? ?? json['content'] as String? ?? '';
    final rawMedia = json['mediaUrl'] as String? ??
        metaMap['mediaUrl'] as String? ??
        metaMap['imageUrl'] as String? ??
        (rawType == 'IMAGE' || rawType == 'VOICE' ? (body.startsWith('http') ? body : null) : null);
    final rawAttach = json['attachments'] ?? metaMap['attachments'];
    final attachList = rawAttach is List
        ? rawAttach.map((e) => e.toString()).toList()
        : (rawMedia != null && rawMedia.isNotEmpty ? [rawMedia] : const <String>[]);
    final diceResult = json['diceResult'] as String? ??
        metaMap['diceResult'] as String?;
    final diceEmoji = json['diceEmoji'] as String? ??
        metaMap['diceEmoji'] as String?;
    final diceName = json['diceName'] as String? ??
        metaMap['diceName'] as String?;

    final rawReply = json['replyTo'] is Map ? json['replyTo'] as Map<String, dynamic> : null;
    final replyToId = json['replyToId'] as String? ??
        rawReply?['id'] as String? ??
        metaMap['replyToId'] as String? ??
        (metaMap['replyTo'] is Map ? metaMap['replyTo']['id'] as String? : null);
    final replyToName = json['replyToName'] as String? ??
        rawReply?['authorName'] as String? ??
        rawReply?['senderName'] as String? ??
        metaMap['replyToName'] as String? ??
        (metaMap['replyTo'] is Map ? (metaMap['replyTo']['authorName'] ?? metaMap['replyTo']['senderName']) as String? : null);
    final replyToBody = json['replyToBody'] as String? ??
        rawReply?['content'] as String? ??
        rawReply?['body'] as String? ??
        metaMap['replyToBody'] as String? ??
        (metaMap['replyTo'] is Map ? (metaMap['replyTo']['content'] ?? metaMap['replyTo']['body']) as String? : null);

    final isEdited = json['isEdited'] == true ||
        metaMap['isEdited'] == true ||
        (json['editCount'] != null && (json['editCount'] as num) > 0) ||
        (metaMap['editCount'] != null && (metaMap['editCount'] as num) > 0);
    final editedAt = json['editedAt']?.toString() ?? metaMap['editedAt']?.toString();
    final editCount = (json['editCount'] as num?)?.toInt() ??
        (metaMap['editCount'] as num?)?.toInt() ??
        (isEdited ? 1 : 0);

    return RoomChatMessage(
      id: json['id'] as String? ?? '',
      roomId: json['roomId'] as String? ?? '',
      senderId: json['senderId'] as String? ?? '',
      sender: PostAuthor.fromJson(
        json['sender'] as Map<String, dynamic>? ?? const {},
      ),
      body: body,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
      type: rawType,
      content: json['content'] as String? ?? rawMedia,
      mediaUrl: rawMedia,
      attachments: attachList,
      diceResult: diceResult,
      diceEmoji: diceEmoji,
      diceName: diceName,
      metadata: metaMap.isNotEmpty ? metaMap : null,
      senderName: json['senderName'] as String?,
      username: json['username'] as String?,
      roleId: json['roleId'] as String?,
      roleName: json['roleName'] as String?,
      roleColor: roleColor,
      clientTempId: clientTempId,
      senderAvatarUrl:
          json['characterAvatarUrl'] as String? ??
          json['roleAvatar'] as String?,
      replyToId: replyToId,
      replyToName: replyToName,
      replyToBody: replyToBody,
      isEdited: isEdited,
      editedAt: editedAt,
      editCount: editCount,
    );
  }
}

/// Página de mensajes de sala (orden descendente del backend).
class RoomMessagePage {
  const RoomMessagePage({
    required this.messages,
    required this.hasMore,
    this.total = 0,
  });

  final List<RoomChatMessage> messages;
  final bool hasMore;
  final int total;
}
