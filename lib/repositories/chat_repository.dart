import '../core/config/app_config.dart';
import '../core/network/api_client.dart';
import '../models/chat_conversation.dart';
import '../models/chat_message.dart';

/// Mensajería directa: conversaciones y mensajes.
class ChatRepository {
  ChatRepository(this._api);

  final ApiClient _api;

  Future<List<Conversation>> getConversations({int limit = 30}) async {
    final json = await _api.getJson(
      AppConfig.roomsBase,
      query: {'limit': limit},
    );
    final raw = json['data'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(Conversation.fromJson)
        .where((c) => c.lastMessage != null)
        .toList();
  }

  Future<Conversation> getConversation(String conversationId) async {
    final json = await _api.getJson(AppConfig.roomDetail(conversationId));
    return Conversation.fromJson(json);
  }

  Future<Conversation> openOrCreateDirect(
    String userId, {
    String? username,
  }) async {
    final json = await _api.postJson(
      AppConfig.roomsBase,
      data: {
        if (userId.isNotEmpty) 'userId': userId,
        if (username != null && username.isNotEmpty) 'username': username,
      },
    );
    return Conversation.fromJson(json);
  }

  Future<Message> sendMessage(
    String conversationId, {
    required String body,
    String? type,
    String? mediaUrl,
    String? mediaType,
    String? stickerUrl,
    String? stickerId,
    Map<String, dynamic>? poll,
    String? replyToId,
    Map<String, dynamic>? extensions,
  }) async {
    final json = await _api.postJson(
      AppConfig.conversationMessages(conversationId),
      data: {
        'body': body,
        'content': body,
        'type': ?type,
        'mediaUrl': ?mediaUrl,
        'mediaType': ?mediaType,
        'stickerUrl': ?stickerUrl,
        'stickerId': ?stickerId,
        'poll': ?poll,
        'replyToId': ?replyToId,
        'extensions': ?extensions,
      },
    );
    return Message.fromJson(json);
  }

  /// Devuelve mensajes más recientes primero (order desc del backend).
  /// Usar [before] para paginar hacia atrás.
  Future<MessagePage> getMessages(
    String conversationId, {
    String? before,
    int limit = 30,
  }) async {
    final json = await _api.getJson(
      AppConfig.roomMessages(conversationId),
      query: {'limit': limit, 'before': ?before},
    );
    final raw = json['data'];
    final messages = raw is List
        ? raw.whereType<Map<String, dynamic>>().map(Message.fromJson).toList()
        : const <Message>[];
    return MessagePage(
      messages: messages,
      hasMore: json['hasMore'] as bool? ?? false,
      total: (json['total'] as num?)?.toInt() ?? messages.length,
    );
  }

  Future<void> markConversationRead(String conversationId) async {
    await _api.postJson(
      '${AppConfig.roomDetail(conversationId)}/read',
      data: const {},
    );
  }

  Future<Message> votePoll(
    String conversationId,
    String messageId, {
    String? optionId,
    int? optionIndex,
  }) async {
    final json = await _api.postJson(
      AppConfig.conversationMessageVote(conversationId, messageId),
      data: {
        'optionId': ?optionId,
        'optionIndex': ?optionIndex,
      },
    );
    return Message.fromJson(json);
  }

  Future<void> setMuted(String conversationId, bool muted) async {
    await _api.patchJson(
      AppConfig.roomDetail(conversationId),
      data: {'muted': muted},
    );
  }

  Future<void> deleteConversation(String conversationId) async {
    await _api.deleteJson(AppConfig.roomDetail(conversationId));
  }

  Future<Message> editMessage(
    String conversationId,
    String messageId,
    String newBody,
  ) async {
    final json = await _api.patchJson(
      '${AppConfig.conversationMessages(conversationId)}/$messageId',
      data: {'body': newBody, 'content': newBody},
    );
    final data = json['data'] is Map<String, dynamic> ? json['data'] : json;
    return Message.fromJson(data as Map<String, dynamic>);
  }

  Future<void> deleteMessage(
    String conversationId,
    String messageId,
  ) async {
    await _api.deleteJson(
      '${AppConfig.conversationMessages(conversationId)}/$messageId',
    );
  }

  Future<List<Message>> searchMessages(
    String conversationId,
    String query,
  ) async {
    final json = await _api.getJson(
      AppConfig.chatSearch(conversationId),
      query: {'q': query},
    );
    final raw = json['data'];
    if (raw is! List) return const [];
    return raw.whereType<Map<String, dynamic>>().map(Message.fromJson).toList();
  }
}

/// Página de mensajes.
class MessagePage {
  const MessagePage({
    required this.messages,
    required this.hasMore,
    this.total = 0,
  });

  final List<Message> messages;
  final bool hasMore;
  final int total;
}
