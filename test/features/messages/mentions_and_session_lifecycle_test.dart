import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyubi/core/network/api_client.dart';
import 'package:kyubi/core/storage/session_store.dart';
import 'package:kyubi/models/mention_item.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Session Lifecycle & ApiClient Token Sync', () {
    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});
      ApiClient.instance.resetRefresh();
      ApiClient.instance.updateAuthToken(null);
    });

    test('ApiClient.updateAuthToken actualiza y limpia el token en memoria inmediatamente', () {
      expect(ApiClient.instance.currentAuthToken, isNull);

      ApiClient.instance.updateAuthToken('test-token-123');
      expect(ApiClient.instance.currentAuthToken, 'test-token-123');

      ApiClient.instance.updateAuthToken(null);
      expect(ApiClient.instance.currentAuthToken, isNull);
    });

    test('TokenStorage.saveTokens sincroniza ApiClient en memoria de forma inmediata', () async {
      await TokenStorage.saveTokens(
        accessToken: 'access-token-abc',
        refreshToken: 'refresh-token-xyz',
      );

      expect(ApiClient.instance.currentAuthToken, 'access-token-abc');

      await TokenStorage.clear();
      expect(ApiClient.instance.currentAuthToken, isNull);
    });

    test('TokenStorage.updateAccessToken refresca el token en ApiClient', () async {
      await TokenStorage.saveTokens(
        accessToken: 'old-token',
        refreshToken: 'refresh-token',
      );
      expect(ApiClient.instance.currentAuthToken, 'old-token');

      await TokenStorage.updateAccessToken('new-token-999');
      expect(ApiClient.instance.currentAuthToken, 'new-token-999');
    });
  });

  group('MentionItem Model', () {
    test('Parsea correctamente JSON de mención en sala', () {
      final json = {
        'id': 'notif-1',
        'type': 'MENTION',
        'isRead': false,
        'createdAt': '2026-09-23T12:00:00.000Z',
        'actor': {
          'id': 'user-author',
          'username': 'naruto',
          'displayName': 'Naruto Uzumaki',
          'avatarUrl': 'https://example.com/naruto.png',
        },
        'data': {
          'targetType': 'room',
          'targetId': 'room-101',
          'roomName': 'Valle del Fin',
          'roomImage': 'https://example.com/room.png',
          'preview': '¡Hola @sasuke ven a pelear!',
        },
      };

      final mention = MentionItem.fromJson(json);

      expect(mention.id, 'notif-1');
      expect(mention.isRead, isFalse);
      expect(mention.isRoom, isTrue);
      expect(mention.isConversation, isFalse);
      expect(mention.targetId, 'room-101');
      expect(mention.targetTitle, 'Valle del Fin');
      expect(mention.preview, '¡Hola @sasuke ven a pelear!');
      expect(mention.actorUsername, 'naruto');
      expect(mention.actorDisplayName, 'Naruto Uzumaki');

      final readMention = mention.copyWith(isRead: true);
      expect(readMention.isRead, isTrue);
    });

    test('Parsea correctamente JSON de mención en conversación privada', () {
      final json = {
        'id': 'notif-2',
        'type': 'MENTION',
        'isRead': true,
        'createdAt': '2026-09-23T12:30:00.000Z',
        'actor': {
          'id': 'user-sakura',
          'username': 'sakura',
          'displayName': 'Sakura Haruno',
        },
        'data': {
          'targetType': 'conversation',
          'targetId': 'conv-202',
          'conversationTitle': 'Chat Secreto',
          'preview': '@sasuke ¿dónde estás?',
        },
      };

      final mention = MentionItem.fromJson(json);

      expect(mention.id, 'notif-2');
      expect(mention.isRead, isTrue);
      expect(mention.isRoom, isFalse);
      expect(mention.isConversation, isTrue);
      expect(mention.targetId, 'conv-202');
      expect(mention.targetTitle, 'Chat Secreto');
    });
  });
}
