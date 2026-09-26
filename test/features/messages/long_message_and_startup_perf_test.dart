import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kyubi/features/messages/presentation/conversation_controller.dart';
import 'package:kyubi/features/salas/presentation/sala_chat_controller.dart';
import 'package:kyubi/features/salas/presentation/widgets/chat_message_input_bar.dart';
import 'package:kyubi/models/chat_message.dart';
import 'package:kyubi/models/room.dart';
import 'package:kyubi/repositories/chat_repository.dart';
import 'package:kyubi/repositories/room_repository.dart';
import 'package:kyubi/services/chat_socket.dart';
import 'package:kyubi/services/providers.dart';
import 'package:kyubi/services/room_socket.dart';

class _FakeChatSocketService implements ChatSocketService {
  @override
  bool get isConnected => true;

  @override
  Stream<ChatSocketEvent> get events => const Stream.empty();

  @override
  Future<void> connect() async {}

  @override
  void joinConversation(String conversationId) {}

  @override
  void leaveConversation(String conversationId) {}

  @override
  void sendTyping(String conversationId, {bool isTyping = true}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRoomSocketService implements RoomSocketService {
  @override
  bool get isConnected => true;

  @override
  Stream<RoomSocketEvent> get events => const Stream.empty();

  @override
  Future<void> connect() async {}

  @override
  void joinRoom(String roomId) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FailingChatRepository implements ChatRepository {
  _FailingChatRepository(this.errorResponse);

  final dynamic errorResponse;

  @override
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
    throw DioException(
      requestOptions: RequestOptions(path: '/conversations/$conversationId/messages'),
      response: Response(
        requestOptions: RequestOptions(path: '/conversations/$conversationId/messages'),
        statusCode: 400,
        data: errorResponse,
      ),
    );
  }

  @override
  Future<MessagePage> getMessages(
    String conversationId, {
    String? before,
    int limit = 30,
  }) async {
    return const MessagePage(messages: [], hasMore: false, total: 0);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FailingRoomRepository implements RoomRepository {
  _FailingRoomRepository(this.errorResponse);

  final dynamic errorResponse;

  @override
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
    throw DioException(
      requestOptions: RequestOptions(path: '/salas/$id/messages'),
      response: Response(
        requestOptions: RequestOptions(path: '/salas/$id/messages'),
        statusCode: 400,
        data: errorResponse,
      ),
    );
  }

  @override
  Future<RoomMessagePage> getRoomMessages(
    String id, {
    String? before,
    int limit = 30,
    String sort = 'desc',
  }) async {
    return const RoomMessagePage(messages: [], hasMore: false, total: 0);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Mensajes largos y manejo descriptivo de errores en envío', () {
    testWidgets('ChatMessageInputBar permite escribir hasta 4000 caracteres y muestra contador > 3500', (tester) async {
      String? sentText;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatMessageInputBar(
              onSendMessage: (text) => sentText = text,
              onSendImage: (_) {},
              onSendAudio: (_, _, _) {},
              onSendDiceRoll: (_, _, _) {},
              onSendPoll: (_, _) {},
            ),
          ),
        ),
      );

      final textFieldFinder = find.byType(TextField);
      expect(textFieldFinder, findsOneWidget);

      final textField = tester.widget<TextField>(textFieldFinder);
      expect(textField.maxLength, 4000);

      // Simular texto de 3600 caracteres (más de 3500 activa el contador)
      final longText = 'a' * 3600;
      await tester.enterText(textFieldFinder, longText);
      await tester.pump();

      expect(find.text('3600/4000'), findsOneWidget);

      // Enviar
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();

      expect(sentText, equals(longText));
    });

    test('ConversationController captura DioException y extrae mensaje descriptivo del backend', () async {
      final fakeSocket = _FakeChatSocketService();
      final failingRepo = _FailingChatRepository({
        'message': 'El mensaje no puede superar los 4000 caracteres',
      });

      final container = ProviderContainer(
        overrides: [
          chatSocketProvider.overrideWithValue(fakeSocket),
          chatRepositoryProvider.overrideWithValue(failingRepo),
        ],
      );
      addTearDown(container.dispose);

      // Mantener vivo el autoDispose notifier durante el test
      final sub = container.listen(conversationChatProvider('conv-123'), (_, _) {});
      addTearDown(sub.close);

      // Esperar que la carga inicial se complete
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final controller = container.read(conversationChatProvider('conv-123').notifier);

      final longText = 'A' * 4000;
      final ok = await controller.send(longText);

      expect(ok, isTrue);

      // El mensaje optimista fue insertado con status 'sending'
      final stateBeforeAsync = container.read(conversationChatProvider('conv-123'));
      expect(stateBeforeAsync.messages.length, 1);
      expect(stateBeforeAsync.messages.first.body, equals(longText));

      // Esperar la resolución del despacho asíncrono
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final stateAfterError = container.read(conversationChatProvider('conv-123'));
      expect(stateAfterError.error, equals('El mensaje no puede superar los 4000 caracteres'));
      expect(stateAfterError.messages.first.status, equals('error'));
      expect(
        stateAfterError.messages.first.extensions?['errorMessage'],
        equals('El mensaje no puede superar los 4000 caracteres'),
      );
    });

    test('SalaChatController captura DioException y extrae mensaje descriptivo de salas', () async {
      final fakeSocket = _FakeRoomSocketService();
      final failingRepo = _FailingRoomRepository({
        'error': 'Tu cuenta se encuentra silenciada temporalmente',
      });

      final container = ProviderContainer(
        overrides: [
          roomSocketProvider.overrideWithValue(fakeSocket),
          roomRepositoryProvider.overrideWithValue(failingRepo),
        ],
      );
      addTearDown(container.dispose);

      // Mantener vivo el autoDispose notifier durante el test
      final sub = container.listen(salaChatControllerProvider('room-123'), (_, _) {});
      addTearDown(sub.close);

      final controller = container.read(salaChatControllerProvider('room-123').notifier);

      // Esperar que la carga inicial se complete
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final ok = await controller.send('Hola a todos en la sala');
      expect(ok, isTrue);

      // Esperar el despacho asíncrono con fallo
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final stateAfterError = container.read(salaChatControllerProvider('room-123'));
      expect(stateAfterError.error, equals('Tu cuenta se encuentra silenciada temporalmente'));
      expect(stateAfterError.messages.first.metadata?['status'], equals('error'));
      expect(
        stateAfterError.messages.first.metadata?['errorMessage'],
        equals('Tu cuenta se encuentra silenciada temporalmente'),
      );
    });
  });
}
