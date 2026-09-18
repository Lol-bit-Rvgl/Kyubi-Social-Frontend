import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/role_character.dart';
import '../../../models/room.dart';
import '../../../repositories/room_repository.dart';
import '../../../services/auth_controller.dart';
import '../../../services/providers.dart';

/// Estado del listado de salas (públicas o de un círculo).
class SalasState {
  const SalasState({
    this.rooms = const [],
    this.pinnedRoomIds = const {},
    this.circleId,
    this.category,
    this.query = '',
    this.loading = false,
    this.refreshing = false,
    this.error,
  });

  final List<Room> rooms;

  /// Salas del usuario: donde es Host/Creador o a las que se ha unido
  /// explícitamente. Las salas públicas que solo se exploran quedan fuera.
  /// Si el usuario solo tiene rol INVITED, la sala queda excluida.
  List<Room> get userRooms =>
      rooms.where((r) {
        final isOnlyInvited = r.participants.any((p) => p.role == 'INVITED') && !r.isParticipant && !r.isHost;
        if (isOnlyInvited) return false;
        return r.isHost || r.isParticipant;
      }).toList();

  /// Salas activas del usuario actual identificadas estrictamente por su `userId`.
  /// Si el usuario solo tiene rol INVITED, la sala NUNCA se incluye en "Rooms".
  List<Room> activeRoomsForUser(String? currentUserId) {
    if (currentUserId == null || currentUserId.isEmpty) {
      return userRooms;
    }
    return rooms.where((r) {
      final isHost = r.hostId == currentUserId || r.host.id == currentUserId;
      final isInvited = r.participants.any(
        (p) => p.user.id == currentUserId && p.role == 'INVITED',
      );
      if (isInvited) return false;
      final isMember = r.participants.any(
        (p) => p.user.id == currentUserId && p.role != 'INVITED',
      ) || (r.isParticipant && !isInvited);
      return isHost || isMember;
    }).toList();
  }

  /// Ids de salas fijadas (`Pin to My Chats`): van primero en la lista.
  final Set<String> pinnedRoomIds;
  final String? circleId;
  final String? category;
  final String query;
  final bool loading;
  final bool refreshing;
  final String? error;

  SalasState copyWith({
    List<Room>? rooms,
    Set<String>? pinnedRoomIds,
    String? circleId,
    String? category,
    String? query,
    bool? loading,
    bool? refreshing,
    String? error,
  }) {
    return SalasState(
      rooms: rooms ?? this.rooms,
      pinnedRoomIds: pinnedRoomIds ?? this.pinnedRoomIds,
      circleId: circleId ?? this.circleId,
      category: category ?? this.category,
      query: query ?? this.query,
      loading: loading ?? this.loading,
      refreshing: refreshing ?? this.refreshing,
      error: error ?? this.error,
    );
  }
}

class SalasNotifier extends Notifier<SalasState> {
  RoomRepository get _repo => ref.read(roomRepositoryProvider);

  bool _disposed = false;
  bool _fetching = false;

  @override
  SalasState build() {
    ref.onDispose(() => _disposed = true);
    final currentUserId = ref.watch(authControllerProvider.select((s) => s.user?.id));
    _clearMemoryData();
    if (currentUserId != null && currentUserId.isNotEmpty) {
      Future.microtask(_load);
      return const SalasState(loading: true);
    }
    return const SalasState();
  }

  /// Purga síncrona de todo el estado en memoria al cambiar de cuenta o cerrar sesión.
  void clearAll() {
    _clearMemoryData();
    state = const SalasState();
  }

  void _clearMemoryData() {
    _roomNotifications.clear();
    _roomBubbleColors.clear();
    _roomRoles.clear();
    _roomMessages.clear();
  }

  Future<void> _load() async {
    if (_disposed || _fetching) return;
    _fetching = true;
    state = state.copyWith(loading: true, error: null);
    try {
      final rooms = await _fetch();
      if (_disposed) return;
      state = state.copyWith(rooms: _sortRooms(rooms), loading: false);
    } catch (e) {
      if (_disposed) return;
      state = state.copyWith(loading: false, error: e.toString());
    } finally {
      _fetching = false;
    }
  }

  Future<List<Room>> _fetch() {
    return _repo.getSalas(
      circleId: state.circleId,
      query: state.query.isEmpty ? null : state.query,
      category: state.category,
    );
  }

  /// Active rooms first, then pinned first, then ended rooms last.
  List<Room> _sortRooms(List<Room> rooms) {
    final sorted = List<Room>.from(rooms);
    sorted.sort((a, b) {
      final aPinned = state.pinnedRoomIds.contains(a.id);
      final bPinned = state.pinnedRoomIds.contains(b.id);
      if (aPinned != bPinned) return aPinned ? -1 : 1;
      if (a.status == RoomStatus.active && b.status != RoomStatus.active) {
        return -1;
      }
      if (a.status != RoomStatus.active && b.status == RoomStatus.active) {
        return 1;
      }
      return 0;
    });
    return sorted;
  }

  Future<void> refresh() async {
    if (_disposed || _fetching) return;
    _fetching = true;
    state = state.copyWith(refreshing: true, error: null);
    try {
      final rooms = await _fetch();
      if (_disposed) return;
      state = state.copyWith(rooms: _sortRooms(rooms), refreshing: false);
    } catch (e) {
      if (_disposed) return;
      state = state.copyWith(refreshing: false, error: e.toString());
    } finally {
      _fetching = false;
    }
  }

  void filterByCircle(String? circleId) {
    if (state.circleId == circleId) return;
    state = SalasState(circleId: circleId);
    Future.microtask(_load);
  }

  void search(String query) {
    final trimmed = query.trim();
    if (state.query == trimmed) return;
    state = SalasState(
      circleId: state.circleId,
      category: state.category,
      query: trimmed,
      pinnedRoomIds: state.pinnedRoomIds,
    );
    Future.microtask(_load);
  }

  void setCategory(String? category) {
    if (state.category == category) return;
    state = SalasState(
      circleId: state.circleId,
      category: category,
      query: state.query,
      pinnedRoomIds: state.pinnedRoomIds,
    );
    Future.microtask(_load);
  }

  /// Aplica una sala actualizada (join/leave) en la lista.
  void applyRoom(Room room) {
    final updated = [
      for (final r in state.rooms)
        if (r.id == room.id) room else r,
    ];
    state = state.copyWith(rooms: _sortRooms(updated));
  }

  /// Inserta una sala recién creada (o la actualiza si ya existe) para que
  /// aparezca de inmediato en la pestaña de Rooms/My Chats.
  void upsertRoom(Room room) {
    final list = [...state.rooms];
    final index = list.indexWhere((r) => r.id == room.id);
    if (index >= 0) {
      list[index] = room;
    } else {
      list.insert(0, room);
    }
    state = state.copyWith(rooms: _sortRooms(list));
  }

  /// Elimina una sala de la lista (p. ej. terminada por su host).
  void removeRoom(String roomId) {
    state = state.copyWith(
      rooms: state.rooms.where((r) => r.id != roomId).toList(),
    );
  }

  // ── Pin to My Chats ───────────────────────────────────────────────────
  // Las salas fijadas quedan al tope del listado de la pestaña Rooms.

  void togglePinRoom(String roomId) {
    final pinned = Set<String>.from(state.pinnedRoomIds);
    if (!pinned.remove(roomId)) pinned.add(roomId);
    state = state.copyWith(
      pinnedRoomIds: pinned,
      rooms: _sortRooms(state.rooms),
    );
  }

  bool isRoomPinned(String roomId) => state.pinnedRoomIds.contains(roomId);

  // ── Preferencias locales por sala (sesión) ────────────────────────────
  // Notificaciones y color de burbuja del chat de la sala.

  final Map<String, bool> _roomNotifications = {};
  final Map<String, Color> _roomBubbleColors = {};

  bool notificationsEnabledFor(String roomId) =>
      _roomNotifications[roomId] ?? true;

  void setRoomNotifications(String roomId, bool enabled) {
    _roomNotifications[roomId] = enabled;
  }

  Color? bubbleColorFor(String roomId) => _roomBubbleColors[roomId];

  void setRoomBubbleColor(String roomId, Color color) {
    _roomBubbleColors[roomId] = color;
  }

  // ── Roles del stage (creados solo por Admin/Co-Admin) ─────────────────
  // El stage de Roleplay se inicia vacío; los roles se agregan manualmente.

  final Map<String, List<RoleCharacter>> _roomRoles = {};

  List<RoleCharacter> rolesFor(String roomId) =>
      List.unmodifiable(_roomRoles[roomId] ?? const []);

  void addRoomRole(String roomId, RoleCharacter role) {
    _roomRoles.putIfAbsent(roomId, () => []).add(role);
  }

  void updateRoomRole(String roomId, RoleCharacter role) {
    final list = _roomRoles[roomId];
    if (list == null) return;
    final index = list.indexWhere((r) => r.id == role.id);
    if (index >= 0) {
      list[index] = role;
    } else {
      list.add(role);
    }
  }

  void setRoomRoles(String roomId, List<RoleCharacter> roles) {
    _roomRoles[roomId] = List<RoleCharacter>.from(roles);
  }

  void removeRoomRole(String roomId, String roleId) {
    final list = _roomRoles[roomId];
    if (list == null) return;
    list.removeWhere((r) => r.id.toString().trim() == roleId.toString().trim());
  }

  // ── Persistencia en sesión de los mensajes de cada sala ─────────────
  // Conserva los mensajes enviados/recibidos en la sala a lo largo de la
  // sesión para que no se reinicien al navegar hacia atrás.
  // Las salas nuevas comienzan con lista 100% vacía.

  final Map<String, List<Map<String, dynamic>>> _roomMessages = {};

  List<Map<String, dynamic>> messagesFor(String roomId) {
    return List.unmodifiable(_roomMessages[roomId] ?? const []);
  }

  /// Comprueba si un mensaje corresponde a la creación o inicio de la sala
  /// (tipo `ROOM_CREATED` o texto "Sala iniciada" / "Sala creada").
  static bool _isRoomCreationMessage(dynamic msg) {
    if (msg == null) return false;
    if (msg is RoomChatMessage) {
      final type = msg.type.toUpperCase();
      final subType = msg.extensions?['subType']?.toString().toUpperCase();
      final body = msg.body.toLowerCase();
      return type == 'ROOM_CREATED' ||
          subType == 'ROOM_CREATED' ||
          body.contains('sala iniciada') ||
          body.contains('sala creada');
    }
    if (msg is Map<String, dynamic>) {
      final type = (msg['type'] as String? ?? '').toUpperCase();
      final subType = (msg['subType'] ??
              msg['metadata']?['subType'] ??
              msg['extensions']?['subType'])
          ?.toString()
          .toUpperCase();
      final text = (msg['text'] ?? msg['body'] ?? msg['content'] ?? '')
          .toString()
          .toLowerCase();
      return type == 'ROOM_CREATED' ||
          subType == 'ROOM_CREATED' ||
          text.contains('sala iniciada') ||
          text.contains('sala creada');
    }
    return false;
  }

  void addRoomMessage(String roomId, Map<String, dynamic> message) {
    if (message.isEmpty) return;
    final list = _roomMessages.putIfAbsent(roomId, () => []);
    final id = message['id']?.toString();
    if (id != null && id.isNotEmpty) {
      final index = list.indexWhere((e) => e['id']?.toString() == id);
      if (index >= 0) {
        list[index] = message;
        return;
      }
    }

    // Deduplicación estricta para mensaje de inicio / creación de sala
    if (_isRoomCreationMessage(message)) {
      final alreadyHasCreation = list.any(_isRoomCreationMessage);
      if (alreadyHasCreation) return;
    }

    list.add(message);
  }

  void clearRoomMessages(String roomId) {
    _roomMessages.remove(roomId);
  }

  void clearAllRoomMessages() {
    _roomMessages.clear();
  }

  // ── Historial del backend + mensajes en vivo (Socket.IO) ─────────────
  // Fusiona el historial persistido con los mensajes de la sesión local.
  // Deduplicación por id y orden cronológico ascendente (el flujo muestra
  // el mensaje más reciente al fondo).

  /// Carga el historial del backend dentro de la sesión, fusionándolo con los
  /// mensajes locales existentes (sin duplicar por id).
  void seedRoomMessages(String roomId, List<RoomChatMessage> messages) {
    if (messages.isEmpty) return;
    final list = _roomMessages.putIfAbsent(roomId, () => []);
    var alreadyHasCreation = list.any(_isRoomCreationMessage);

    for (final m in messages) {
      final id = m.id;
      if (id.isNotEmpty && list.any((e) => e['id'] == id)) continue;

      if (_isRoomCreationMessage(m)) {
        if (alreadyHasCreation) continue;
        alreadyHasCreation = true;
      }

      final optIdx = list.indexWhere((e) {
        final eId = '${e['id'] ?? ''}';
        if (!eId.startsWith('local-')) return false;
        if (m.clientTempId != null &&
            (e['clientTempId'] == m.clientTempId || e['id'] == m.clientTempId)) {
          return true;
        }
        final sameSender = e['senderId'] == m.senderId;
        final sameBody =
            (e['body'] ?? e['text'] ?? e['content'] ?? '').toString() == m.body;
        if (sameSender && sameBody) {
          final eCreatedAt = e['createdAt'];
          final eTime = eCreatedAt is DateTime
              ? eCreatedAt
              : DateTime.tryParse(eCreatedAt?.toString() ?? '');
          return eTime == null ||
              m.createdAt.difference(eTime).abs().inSeconds < 5;
        }
        return false;
      });
      if (optIdx >= 0) {
        list[optIdx] = _roomMessageToMap(m);
        continue;
      }

      list.add(_roomMessageToMap(m));
    }
    list.sort(_sortRoomMessages);
  }

  /// Incorpora un mensaje en vivo recibido por socket. Reemplaza por id si ya
  /// existe para evitar duplicados con el echo de un mensaje propio.
  void ingestRoomMessage(String roomId, RoomChatMessage message) {
    final list = _roomMessages.putIfAbsent(roomId, () => []);

    // 1. Reemplazo por id exacto del servidor
    final exactIndex = list.indexWhere((e) => e['id'] == message.id);
    if (exactIndex >= 0) {
      list[exactIndex] = _roomMessageToMap(message);
      return;
    }

    // 2. Reemplazo por clientTempId asociado al mensaje optimista
    if (message.clientTempId != null && message.clientTempId!.isNotEmpty) {
      final tempIndex = list.indexWhere((e) =>
          e['clientTempId'] == message.clientTempId ||
          e['id'] == message.clientTempId ||
          e['metadata']?['clientTempId'] == message.clientTempId);
      if (tempIndex >= 0) {
        list[tempIndex] = _roomMessageToMap(message);
        return;
      }
    }

    // 3. Reemplazo por coincidencia optimista (local-id + mismo sender/texto + tiempo < 5s)
    final localIndex = list.indexWhere((e) {
      final eId = '${e['id'] ?? ''}';
      if (!eId.startsWith('local-')) return false;

      final sameSender = e['senderId'] == message.senderId ||
          e['username'] == message.sender.username ||
          e['senderName'] == message.sender.displayName ||
          e['senderName'] == message.sender.username;

      final eBody =
          (e['body'] ?? e['text'] ?? e['content'] ?? '').toString().trim();
      final mBody = (message.body.isNotEmpty
              ? message.body
              : (message.content ?? ''))
          .trim();
      final sameBody = eBody == mBody;

      if (sameBody && (sameSender || message.senderId.isEmpty)) {
        final eCreatedAt = e['createdAt'];
        final eTime = eCreatedAt is DateTime
            ? eCreatedAt
            : DateTime.tryParse(eCreatedAt?.toString() ?? '');
        final mTime = message.createdAt;
        if (eTime != null) {
          return mTime.difference(eTime).abs().inSeconds < 5;
        }
        return true;
      }
      return false;
    });
    if (localIndex >= 0) {
      list[localIndex] = _roomMessageToMap(message);
      return;
    }

    // Deduplicación estricta para mensaje de inicio / creación de sala
    if (_isRoomCreationMessage(message)) {
      final alreadyHasCreation = list.any(_isRoomCreationMessage);
      if (alreadyHasCreation) return;
    }

    // Deduplicación preventiva de eventos de unión (USER_JOIN / se ha unido)
    final isJoin = message.extensions?['subType'] == 'USER_JOIN' ||
        message.body.contains('se ha unido') ||
        message.body.contains('Te has unido');
    if (isJoin) {
      final joinUserId = message.extensions?['userId'] ?? message.senderId;
      final recentDuplicate = list.any((e) {
        final eSubType = e['subType'] ??
            e['extensions']?['subType'] ??
            e['metadata']?['subType'];
        final eBody =
            (e['body'] ?? e['text'] ?? e['content'] ?? '').toString();
        final eIsJoin = eSubType == 'USER_JOIN' ||
            eBody.contains('se ha unido') ||
            eBody.contains('Te has unido');
        if (!eIsJoin) return false;
        final eUserId = e['userId'] ??
            e['senderId'] ??
            e['extensions']?['userId'] ??
            e['metadata']?['userId'];
        if (eUserId == joinUserId) {
          final eCreatedAt = e['createdAt'];
          final eTime = eCreatedAt is DateTime
              ? eCreatedAt
              : DateTime.tryParse(eCreatedAt?.toString() ?? '');
          final mTime = message.createdAt;
          if (eTime != null) {
            return (mTime.difference(eTime).abs().inSeconds < 10);
          }
          return true;
        }
        return false;
      });
      if (recentDuplicate) return;
    }

    list.add(_roomMessageToMap(message));
    list.sort(_sortRoomMessages);
  }

  /// Registra el voto del usuario en la encuesta de un mensaje de sala.
  ///
  /// Actualiza `metadata.userVotedOptionId` (hasVoted), suma el voto a la
  /// opción elegida y `totalVotes`. Como los mensajes viven en esta sesión,
  /// el estado vendido se conserva al reconectar/recargar el chat. No añade
  /// duplicados si el usuario ya votó (guarda por `userVotedOptionId`).
  void markPollVoted(String roomId, String messageId, String optionId) {
    if (messageId.isEmpty || optionId.isEmpty) return;
    final list = _roomMessages[roomId];
    if (list == null) return;
    final index = list.indexWhere((e) => '${e['id'] ?? ''}' == messageId);
    if (index < 0) return;
    final msg = list[index];
    final metadata = msg['metadata'];
    if (metadata is! Map<String, dynamic>) return;

    final prevVote = metadata['userVotedOptionId'] as String?;
    if (prevVote != null && prevVote.isNotEmpty) return;

    final rawOptions = metadata['options'];
    if (rawOptions is! List) return;
    final updatedOptions = <Map<String, dynamic>>[];
    var matched = false;
    for (final raw in rawOptions) {
      if (raw is! Map<String, dynamic>) continue;
      final id = '${raw['id'] ?? raw['text'] ?? ''}';
      if (id == optionId) {
        updatedOptions.add({
          ...raw,
          'votes': ((raw['votes'] as num?)?.toInt() ?? 0) + 1,
        });
        matched = true;
      } else {
        updatedOptions.add({...raw});
      }
    }
    if (!matched) return;

    list[index] = {
      ...msg,
      'metadata': <String, dynamic>{
        ...metadata,
        'userVotedOptionId': optionId,
        'options': updatedOptions,
        'totalVotes': ((metadata['totalVotes'] as num?)?.toInt() ?? 0) + 1,
      },
    };
  }

  /// Actualiza los resultados de una encuesta a partir de un evento del servidor.
  void updatePollResults(
    String roomId, {
    required String messageId,
    required List<dynamic> options,
    required int totalVotes,
    List<dynamic>? voteCounts,
    String? userVotedOptionId,
  }) {
    if (messageId.isEmpty) return;
    final list = _roomMessages[roomId];
    if (list == null) return;
    final index = list.indexWhere((e) => '${e['id'] ?? ''}' == messageId);
    if (index < 0) return;
    final msg = list[index];
    final metadata = msg['metadata'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(msg['metadata'] as Map)
        : <String, dynamic>{};

    final effectiveUserVoted = userVotedOptionId ?? metadata['userVotedOptionId'];

    list[index] = {
      ...msg,
      'metadata': <String, dynamic>{
        ...metadata,
        'userVotedOptionId': ?effectiveUserVoted,
        'options': options,
        'totalVotes': totalVotes,
        'voteCounts': ?voteCounts,
      },
    };
  }

  /// Sustituye un mensaje optimista (enviado de forma local con id `local-…`)
  /// por la versión confirmada del backend, evitando duplicados cuando llega
  /// el echo vía socket con el id del servidor.
  void replaceLocalRoomMessage(
    String roomId, {
    required String localId,
    required RoomChatMessage server,
  }) {
    final list = _roomMessages[roomId];
    if (list == null) return;
    final index = list.indexWhere((e) => '${e['id'] ?? ''}' == localId);
    if (index < 0 || server.id.isEmpty) return;
    if (list.any((e) => '${e['id'] ?? ''}' == server.id)) {
      list.removeAt(index);
      return;
    }
    list[index] = _roomMessageToMap(server);
    list.sort(_sortRoomMessages);
  }

  /// Elimina los mensajes optimistas locales (id empieza por `local-`) de una sala,
  /// descartando cualquier mensaje pendiente si el usuario es sancionado.
  void clearLocalRoomMessages(String roomId) {
    final list = _roomMessages[roomId];
    if (list == null) return;
    list.removeWhere((e) => '${e['id'] ?? ''}'.startsWith('local-'));
  }

  static int _sortRoomMessages(Map<String, dynamic> a, Map<String, dynamic> b) {
    final ta = a['createdAt'];
    final tb = b['createdAt'];
    final da = ta is DateTime ? ta : DateTime.tryParse('${ta ?? ''}');
    final db = tb is DateTime ? tb : DateTime.tryParse('${tb ?? ''}');
    if (da == null && db == null) return 0;
    if (da == null) return 1;
    if (db == null) return -1;
    final cmp = da.compareTo(db);
    if (cmp != 0) return cmp;
    return '${a['id'] ?? ''}'.compareTo('${b['id'] ?? ''}');
  }

  /// Actualiza el contenido de un mensaje editado en la sala.
  void updateRoomMessage(
    String roomId,
    String messageId, {
    required String content,
    bool isEdited = true,
    String? editedAt,
  }) {
    if (messageId.isEmpty) return;
    final list = _roomMessages[roomId];
    if (list == null) return;
    final index = list.indexWhere((e) => '${e['id'] ?? ''}' == messageId);
    if (index < 0) return;
    final prev = list[index];
    list[index] = {
      ...prev,
      'body': content,
      'content': content,
      'text': content,
      'isEdited': isEdited,
      'editedAt': editedAt ?? DateTime.now().toIso8601String(),
    };
  }

  /// Elimina un mensaje de la sala por su ID.
  void deleteRoomMessage(String roomId, String messageId) {
    if (messageId.isEmpty) return;
    final list = _roomMessages[roomId];
    if (list == null) return;
    list.removeWhere((e) => '${e['id'] ?? ''}' == messageId);
  }

  /// Convierte un [RoomChatMessage] del backend al formato de mapa que ya
  /// entiende el renderer de `SalaDetailScreen` (claves tipo, body, role…).
  Map<String, dynamic> _roomMessageToMap(RoomChatMessage m) {
    final type = m.type.toUpperCase();
    final isDice = type == 'DICE' ||
        type == 'RPS' ||
        m.diceResult != null ||
        m.metadata?['diceResult'] != null;
    final wiredType = switch (type) {
      'VOICE' => 'voice',
      'IMAGE' => 'image',
      'POLL' => 'poll',
      'SYSTEM' => 'system',
      'DICE' || 'RPS' => 'dice',
      _ => isDice ? 'dice' : 'message',
    };
    final senderName = m.senderName != null && m.senderName!.isNotEmpty
        ? m.senderName!
        : (m.sender.displayName.isNotEmpty
              ? m.sender.displayName
              : m.sender.username);
    final roleColorHex = m.roleColor ??
        m.metadata?['roleColor'] as String? ??
        m.metadata?['roleColorHex'] as String? ??
        m.metadata?['colorHex'] as String? ??
        m.metadata?['characterColor'] as String? ??
        '#00E5FF';
    final role = m.roleName != null && m.roleName!.isNotEmpty
        ? RoleCharacter(
            id: m.roleId ?? m.senderId,
            name: m.roleName!,
            avatarUrl: m.senderAvatarUrl ?? m.sender.avatarUrl,
            colorHex: roleColorHex,
          )
        : null;

    final resolvedMediaUrl = m.mediaUrl ??
        m.metadata?['mediaUrl'] as String? ??
        m.metadata?['imageUrl'] as String? ??
        ((type == 'IMAGE' || type == 'VOICE') && m.body.startsWith('http')
            ? m.body
            : null);

    final contentUrl = resolvedMediaUrl ??
        (type == 'VOICE' || type == 'IMAGE' ? (m.content ?? m.body) : '');

    final diceResult = m.diceResult ?? m.metadata?['diceResult'] as String?;
    final diceEmoji = m.diceEmoji ?? m.metadata?['diceEmoji'] as String?;
    final diceName = m.diceName ?? m.metadata?['diceName'] as String?;

    return {
      'type': wiredType,
      'body': m.body.isNotEmpty ? m.body : m.content ?? '',
      'contentUrl': contentUrl,
      'mediaUrl': resolvedMediaUrl,
      'attachments': m.attachments,
      'diceResult': diceResult,
      'diceEmoji': diceEmoji,
      'diceName': diceName,
      'metadata': m.metadata,
      'clientTempId': m.clientTempId,
      'senderId': m.senderId,
      'senderName': senderName,
      'username': m.username ?? m.sender.username,
      'userAvatar': m.senderAvatarUrl ?? m.sender.avatarUrl,
      'role': role,
      'roleColor': roleColorHex,
      'id': m.id,
      'createdAt': m.createdAt,
      'replyToId': m.replyToId,
      'replyToName': m.replyToName,
      'replyToBody': m.replyToBody,
      'isEdited': m.isEdited,
      'editedAt': m.editedAt,
      'editCount': m.editCount,
    };
  }
}

final salasControllerProvider = NotifierProvider<SalasNotifier, SalasState>(
  SalasNotifier.new,
);
