import '../core/config/app_config.dart';
import '../core/network/api_client.dart';
import '../models/role_character.dart';
import '../models/room.dart';

/// Operaciones sobre salas (`GET|POST /salas`).
class RoomRepository {
  RoomRepository(this._api);

  final ApiClient _api;

  /// Salas activas, opcionalmente filtradas por círculo o búsqueda.
  Future<List<Room>> getSalas({
    int limit = 30,
    String? circleId,
    String? query,
  }) async {
    final json = await _api.getJson(
      AppConfig.salasBase,
      query: {
        'limit': limit,
        if (circleId != null && circleId.isNotEmpty) 'circleId': circleId,
        if (query != null && query.isNotEmpty) 'q': query,
      },
    );
    return _roomList(json);
  }

  /// Detalle de la sala (incluye participantes).
  Future<Room> getSala(String id) async {
    final json = await _api.getJson(AppConfig.salaDetail(id));
    return Room.fromJson(json);
  }

  /// Crea una sala (el usuario pasa a ser HOST).
  Future<Room> createSala({
    required String name,
    String? description,
    String? imageUrl,
    int? capacity,
    String access = 'PUBLIC',
    String? circleId,
    List<String>? tags,
  }) async {
    final json = await _api.postJson(
      AppConfig.salasBase,
      data: {
        'name': name,
        if (description != null && description.isNotEmpty)
          'description': description,
        if (imageUrl != null && imageUrl.isNotEmpty) 'imageUrl': imageUrl,
        'capacity': ?capacity,
        'access': access,
        if (circleId != null && circleId.isNotEmpty) 'circleId': circleId,
        'tags': ?tags,
      },
    );
    return Room.fromJson(json);
  }

  /// Actualiza la sala (solo el host).
  Future<Room> updateSala(
    String id, {
    String? name,
    String? description,
    String? imageUrl,
    String? chatBackgroundUrl,
    List<String>? rules,
    List<String>? tags,
    int? capacity,
    String? access,
    String? status,
  }) async {
    final json = await _api.patchJson(
      AppConfig.salaDetail(id),
      data: {
        if (name != null && name.isNotEmpty) 'name': name,
        'description': ?description,
        'imageUrl': ?imageUrl,
        'chatBackgroundUrl': ?chatBackgroundUrl,
        'rules': ?rules,
        'tags': ?tags,
        'capacity': ?capacity,
        'access': ?access,
        'status': ?status,
      },
    );
    return Room.fromJson(json);
  }

  /// Cierra/elimina la sala (solo el host).
  Future<void> deleteSala(String id) async {
    await _api.deleteJson(AppConfig.salaDetail(id));
  }

  /// Entra a la sala. El host puede entrar sin estar ya en ella.
  Future<Room> joinSala(String id) async {
    final json = await _api.postJson(AppConfig.salaJoin(id));
    return Room.fromJson(json);
  }

  /// Sale de la sala. Si el host sale, la sala termina.
  Future<RoomLeaveResult> leaveSala(String id) async {
    final json = await _api.postJson(AppConfig.salaLeave(id));
    return RoomLeaveResult.fromJson(json);
  }

  /// Adopta o libera un rol en el stage de roleplay de la sala.
  Future<void> updateStageRole(
    String roomId, {
    required RoleCharacter? role,
    required bool isTake,
  }) async {
    await _api.postJson(
      AppConfig.salaStageRole(roomId),
      data: {
        'action': isTake ? 'take' : 'leave',
        if (role != null) 'role': role.toJson(),
        if (role != null) 'roleId': role.id,
      },
    );
  }

  /// Guarda (crea o actualiza) un rol en la sala de forma persistente en PostgreSQL.
  Future<void> saveStageRole(String roomId, RoleCharacter role) async {
    await _api.postJson(
      AppConfig.salaStageRole(roomId),
      data: {
        'action': 'create',
        'role': role.toJson(),
        'roleId': role.id,
      },
    );
  }

  /// Elimina un rol de la sala de forma persistente en PostgreSQL.
  Future<void> deleteStageRole(String roomId, String roleId) async {
    await _api.postJson(
      AppConfig.salaStageRole(roomId),
      data: {
        'action': 'delete',
        'roleId': roleId,
      },
    );
  }

  /// Actualiza de forma atómica el modo de la sala (standard/voice/roleplay/screening).
  Future<Room> updateRoomMode(
    String roomId,
    String mode, {
    String? videoId,
    String? cinemaState,
    double? currentTime,
  }) async {
    final json = await _api.patchJson(
      AppConfig.salaMode(roomId),
      data: {
        'mode': mode,
        if (videoId != null && videoId.isNotEmpty) 'videoId': videoId,
        if (cinemaState != null && cinemaState.isNotEmpty)
          'cinemaState': cinemaState,
        'currentTime': ?currentTime,
      },
    );
    return Room.fromJson(json);
  }

  /// Registra el voto en una encuesta de sala en el backend.
  Future<Map<String, dynamic>> voteRoomPoll(
    String roomId,
    String messageId, {
    required String optionId,
    int? optionIndex,
  }) async {
    final json = await _api.postJson(
      AppConfig.salaMessageVote(roomId, messageId),
      data: {
        'optionId': optionId,
        'optionIndex': ?optionIndex,
      },
    );
    return json;
  }

  /// Mensajes recientes de la sala (orden descendente del backend).
  /// Usar [before] para paginar hacia atrás o `sort: 'asc'` para recibir los
  /// últimos mensajes en orden cronológico ascendente (historial como lista).
  Future<RoomMessagePage> getRoomMessages(
    String id, {
    String? before,
    int limit = 30,
    String sort = 'desc',
  }) async {
    final json = await _api.getJson(
      AppConfig.salaMessages(id),
      query: {
        'limit': limit,
        'before': ?before,
        if (sort == 'asc') 'sort': 'asc',
      },
    );
    final raw = json['data'];
    final messages = raw is List
        ? raw
              .whereType<Map<String, dynamic>>()
              .map(RoomChatMessage.fromJson)
              .toList()
        : const <RoomChatMessage>[];
    return RoomMessagePage(
      messages: messages,
      hasMore: json['hasMore'] as bool? ?? false,
      total: (json['total'] as num?)?.toInt() ?? messages.length,
    );
  }

  /// Envía un mensaje a la sala (requiere ser participante y sala activa).
  /// Soporta contenido tipado: `TEXT` (default), `VOICE`, `IMAGE`, `POLL`, `DICE`, `RPS`
  /// (dato adicional en [metadata], persistido como `extensions`).
  Future<RoomChatMessage> sendRoomMessage(
    String id, {
    required String body,
    String type = 'TEXT',
    String? mediaUrl,
    List<String>? attachments,
    Map<String, dynamic>? metadata,
    String? characterId,
    String? characterName,
    String? characterAvatarUrl,
    String? replyToId,
    Map<String, dynamic>? replyTo,
  }) async {
    final mergedMetadata = <String, dynamic>{
      ...?metadata,
      if (mediaUrl != null && mediaUrl.isNotEmpty) 'mediaUrl': mediaUrl,
      if (attachments != null && attachments.isNotEmpty)
        'attachments': attachments,
      if (replyToId != null && replyToId.isNotEmpty) 'replyToId': replyToId,
      if (replyTo != null && replyTo.isNotEmpty) 'replyTo': replyTo,
    };
    final json = await _api.postJson(
      AppConfig.salaMessages(id),
      data: {
        'body': body,
        'content': body,
        if (type != 'TEXT') 'type': type,
        if (mediaUrl != null && mediaUrl.isNotEmpty) 'mediaUrl': mediaUrl,
        if (attachments != null && attachments.isNotEmpty)
          'attachments': attachments,
        if (mergedMetadata.isNotEmpty) 'extensions': mergedMetadata,
        if (characterId != null && characterId.isNotEmpty)
          'characterId': characterId,
        if (characterName != null && characterName.isNotEmpty)
          'characterName': characterName,
        if (characterAvatarUrl != null && characterAvatarUrl.isNotEmpty)
          'characterAvatarUrl': characterAvatarUrl,
        if (replyToId != null && replyToId.isNotEmpty) 'replyToId': replyToId,
        if (replyTo != null && replyTo.isNotEmpty) 'replyTo': replyTo,
      },
    );
    return RoomChatMessage.fromJson(json);
  }

  /// Edita un mensaje de sala (permitido solo una vez por el autor).
  Future<RoomChatMessage> editRoomMessage(
    String roomId,
    String messageId, {
    required String content,
  }) async {
    final json = await _api.patchJson(
      AppConfig.salaMessage(roomId, messageId),
      data: {
        'content': content,
        'body': content,
      },
    );
    return RoomChatMessage.fromJson(json);
  }

  /// Elimina un mensaje de la sala (autor o host/staff).
  Future<bool> deleteRoomMessage(String roomId, String messageId) async {
    final json = await _api.deleteJson(
      AppConfig.salaMessage(roomId, messageId),
    );
    return json['success'] == true;
  }

  static List<Room> _roomList(Map<String, dynamic> json) {
    final raw = json['data'];
    if (raw is! List) return const [];
    return raw.whereType<Map<String, dynamic>>().map(Room.fromJson).toList();
  }
}
