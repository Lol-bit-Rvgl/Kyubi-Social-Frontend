import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyubi/core/network/api_client.dart';
import 'package:kyubi/features/messages/presentation/conversations_controller.dart';
import 'package:kyubi/features/salas/presentation/salas_controller.dart';
import 'package:kyubi/features/salas/presentation/salas_screen.dart';
import 'package:kyubi/models/chat_conversation.dart';
import 'package:kyubi/models/chat_message.dart';
import 'package:kyubi/models/post_author.dart';
import 'package:kyubi/models/room.dart';
import 'package:kyubi/models/user.dart';
import 'package:kyubi/repositories/chat_repository.dart';
import 'package:kyubi/repositories/room_repository.dart';
import 'package:kyubi/services/auth_controller.dart';
import 'package:kyubi/services/providers.dart';

class _FakeRoomRepository implements RoomRepository {
  _FakeRoomRepository({this.onGetSalas});

  Future<List<Room>> Function({int limit, String? circleId, String? query, String? category})? onGetSalas;

  @override
  Future<List<Room>> getSalas({int limit = 50, String? circleId, String? query, String? category}) async {
    if (onGetSalas != null) {
      return onGetSalas!(limit: limit, circleId: circleId, query: query, category: category);
    }
    return [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeApiClient implements ApiClient {
  _FakeApiClient(this.dataToReturn);

  final List<Map<String, dynamic>> dataToReturn;

  @override
  Future<Map<String, dynamic>> getJson(String path, {Map<String, dynamic>? query}) async {
    return {'data': dataToReturn};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAuthNotifier extends AuthNotifier {
  final User? initialUser;
  _FakeAuthNotifier(this.initialUser);

  @override
  AuthState build() => AuthState(
        status: initialUser != null
            ? AuthStatus.authenticated
            : AuthStatus.unauthenticated,
        user: initialUser,
      );
}

const _testUser = User(
  id: 'user-me-1',
  username: 'me_user',
  displayName: 'Me User',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SalasScreen & SalasController - Race Condition & No Demo Rooms', () {
    testWidgets('Muestra estado vacío directamente y NUNCA salas demo si la API devuelve lista vacía', (tester) async {
      final fakeRepo = _FakeRoomRepository(
        onGetSalas: ({limit = 50, circleId, query, category}) async => [],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            roomRepositoryProvider.overrideWithValue(fakeRepo),
            authControllerProvider.overrideWith(() => _FakeAuthNotifier(_testUser)),
          ],
          child: const MaterialApp(
            home: SalasScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // No debe contener nombres de salas demo como 'peaceful place' o 'Guild Crimson'
      expect(find.text('peaceful place 🌿'), findsNothing);
      expect(find.text('Guild Crimson ⚔️'), findsNothing);
      expect(find.text('༺•*•El reino infinito•*•༻'), findsNothing);

      // Debe mostrar el estado vacío oficial
      expect(find.text('No hay salas activas disponibles'), findsOneWidget);
      expect(find.text('Crear Sala'), findsOneWidget);
    });

    test('Descarta respuestas tardías al conmutar rápidamente de categoría (Race condition prevention)', () async {
      final voiceCompleter = Completer<List<Room>>();
      final screeningCompleter = Completer<List<Room>>();

      final fakeRepo = _FakeRoomRepository(
        onGetSalas: ({limit = 50, circleId, query, category}) {
          if (category == 'voice') {
            return voiceCompleter.future;
          }
          if (category == 'screening') {
            return screeningCompleter.future;
          }
          return Future.value([]);
        },
      );

      final container = ProviderContainer(
        overrides: [
          roomRepositoryProvider.overrideWithValue(fakeRepo),
          authControllerProvider.overrideWith(() => _FakeAuthNotifier(_testUser)),
        ],
      );
      addTearDown(container.dispose);

      // Inicializa el controlador
      container.read(salasControllerProvider);
      await pumpEventQueue();

      final notifier = container.read(salasControllerProvider.notifier);

      // 1. El usuario pulsa 'voice'
      notifier.setCategory('voice');
      expect(container.read(salasControllerProvider).category, 'voice');
      expect(container.read(salasControllerProvider).rooms, isEmpty);
      expect(container.read(salasControllerProvider).loading, isTrue);

      // 2. Antes de que responda 'voice', el usuario cambia a 'screening'
      notifier.setCategory('screening');
      expect(container.read(salasControllerProvider).category, 'screening');
      expect(container.read(salasControllerProvider).rooms, isEmpty);
      expect(container.read(salasControllerProvider).loading, isTrue);

      // 3. Responde tardíamente la petición anterior 'voice' con salas de voz
      voiceCompleter.complete([
        const Room(
          id: 'room-voice-old',
          name: 'Sala de Voz Vieja',
          host: PostAuthor(id: 'u1', username: 'vhost', displayName: 'VHost'),
          currentMode: 'voice',
        ),
      ]);
      await pumpEventQueue();

      // La respuesta tardía debe haber sido descartada: rooms sigue vacío y category es screening
      expect(container.read(salasControllerProvider).rooms, isEmpty);
      expect(container.read(salasControllerProvider).category, 'screening');

      // 4. Responde la petición vigente 'screening'
      screeningCompleter.complete([
        const Room(
          id: 'room-screening-new',
          name: 'Sala de Cine Nueva',
          host: PostAuthor(id: 'u2', username: 'shost', displayName: 'SHost'),
          currentMode: 'screening',
        ),
      ]);
      await pumpEventQueue();

      // Ahora sí se actualiza el estado con la sala de screening
      expect(container.read(salasControllerProvider).rooms, hasLength(1));
      expect(container.read(salasControllerProvider).rooms.first.id, 'room-screening-new');
      expect(container.read(salasControllerProvider).loading, isFalse);
    });
  });

  group('Persistencia de Conversaciones & Inbox - Exclusión de Chats Vacíos', () {
    test('ChatRepository.getConversations filtra conversaciones que no tienen lastMessage', () async {
      final fakeApi = _FakeApiClient([
        {
          'id': 'conv-active',
          'type': 'DIRECT',
          'title': 'Chat Activo',
          'lastMessage': {
            'id': 'msg-1',
            'conversationId': 'conv-active',
            'senderId': 'user-2',
            'body': 'Mensaje real',
            'createdAt': '2026-09-21T10:00:00.000Z',
          },
          'members': [],
        },
        {
          'id': 'conv-empty',
          'type': 'DIRECT',
          'title': 'Chat Vacío',
          'lastMessage': null,
          'members': [],
        },
      ]);

      final repo = ChatRepository(fakeApi);
      final list = await repo.getConversations();

      expect(list, hasLength(1));
      expect(list.first.id, 'conv-active');
      expect(list.first.lastMessage, isNotNull);
    });

    test('ConversationsNotifier.upsertConversation ignora conversaciones con lastMessage == null', () {
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(() => _FakeAuthNotifier(_testUser)),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(conversationsControllerProvider.notifier);

      final emptyConv = const Conversation(
        id: 'conv-empty',
        type: 'DIRECT',
        title: 'Empty',
        lastMessage: null,
      );

      notifier.upsertConversation(emptyConv);
      expect(container.read(conversationsControllerProvider).conversations, isEmpty);

      final validConv = Conversation(
        id: 'conv-valid',
        type: 'DIRECT',
        title: 'Valid',
        lastMessage: Message(
          id: 'm-1',
          conversationId: 'conv-valid',
          senderId: 'u-1',
          sender: const ChatAuthor(id: 'u-1', username: 'u1', displayName: 'U1'),
          body: 'Hola',
          createdAt: DateTime.now(),
        ),
      );

      notifier.upsertConversation(validConv);
      expect(container.read(conversationsControllerProvider).conversations, hasLength(1));
      expect(container.read(conversationsControllerProvider).conversations.first.id, 'conv-valid');
    });
  });
}
