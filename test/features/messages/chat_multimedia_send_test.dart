import 'package:flutter_test/flutter_test.dart';
import 'package:kyubi/core/network/api_client.dart';
import 'package:kyubi/repositories/chat_repository.dart';

class FakeChatApiClient extends Fake implements ApiClient {
  String? lastPath;
  dynamic lastData;

  @override
  Future<Map<String, dynamic>> postJson(String path, {Object? data, Map<String, dynamic>? query}) async {
    lastPath = path;
    lastData = data;
    final map = data as Map?;
    return {
      'id': 'msg-123',
      'conversationId': 'conv-123',
      'senderId': 'user-1',
      'sender': {'id': 'user-1', 'username': 'tester', 'displayName': 'Tester'},
      'body': map?['body'] ?? '',
      'createdAt': DateTime.now().toIso8601String(),
      'mediaUrl': map?['mediaUrl'],
      'mediaType': map?['mediaType'],
      'extensions': map?['extensions'],
    };
  }
}

void main() {
  group('ChatRepository - Envío de Mensajes Multimedia, Stickers y Encuestas en DMs', () {
    late FakeChatApiClient fakeApi;
    late ChatRepository repository;

    setUp(() {
      fakeApi = FakeChatApiClient();
      repository = ChatRepository(fakeApi);
    });

    test('sendMessage con imagen envía type: IMAGE, mediaUrl y content vacío a /conversations/:id/messages', () async {
      final message = await repository.sendMessage(
        'conv-123',
        body: '',
        type: 'IMAGE',
        mediaUrl: 'https://cdn.kyubi.app/img.webp',
        mediaType: 'image',
      );

      expect(fakeApi.lastPath, '/conversations/conv-123/messages');
      expect(fakeApi.lastData, {
        'body': '',
        'content': '',
        'type': 'IMAGE',
        'mediaUrl': 'https://cdn.kyubi.app/img.webp',
        'mediaType': 'image',
      });
      expect(message.id, 'msg-123');
      expect(message.mediaUrl, 'https://cdn.kyubi.app/img.webp');
    });

    test('sendMessage con sticker envía type: STICKER, stickerUrl y stickerId', () async {
      final message = await repository.sendMessage(
        'conv-123',
        body: '',
        type: 'STICKER',
        mediaUrl: 'assets/stickers/cat.png',
        stickerUrl: 'assets/stickers/cat.png',
        stickerId: 'sticker-1',
        mediaType: 'sticker',
      );

      expect(fakeApi.lastPath, '/conversations/conv-123/messages');
      expect(fakeApi.lastData['type'], 'STICKER');
      expect(fakeApi.lastData['stickerUrl'], 'assets/stickers/cat.png');
      expect(fakeApi.lastData['stickerId'], 'sticker-1');
      expect(message.mediaUrl, 'assets/stickers/cat.png');
    });

    test('sendMessage con encuesta envía type: POLL y payload de poll', () async {
      final pollData = {
        'question': '¿Qué película vemos?',
        'options': ['Película 1', 'Película 2'],
      };

      final message = await repository.sendMessage(
        'conv-123',
        body: '',
        type: 'POLL',
        mediaType: 'poll',
        poll: pollData,
      );

      expect(fakeApi.lastPath, '/conversations/conv-123/messages');
      expect(fakeApi.lastData['type'], 'POLL');
      expect(fakeApi.lastData['poll'], pollData);
      expect(message.id, 'msg-123');
    });
  });
}
