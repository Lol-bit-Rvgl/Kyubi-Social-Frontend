import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kyubi/features/salas/presentation/sala_detail_screen.dart';
import 'package:kyubi/models/post_author.dart';
import 'package:kyubi/models/room.dart';
import 'package:kyubi/models/user.dart';
import 'package:kyubi/repositories/room_repository.dart';
import 'package:kyubi/services/auth_controller.dart';
import 'package:kyubi/services/providers.dart';
import 'package:kyubi/services/room_socket.dart';

class _FakeRoomRepository implements RoomRepository {
  _FakeRoomRepository(this.room, {this.messages = const []});

  final Room room;
  final List<RoomChatMessage> messages;

  @override
  Future<Room> getSala(String id) async => room;

  @override
  Future<RoomMessagePage> getRoomMessages(
    String id, {
    int limit = 50,
    String? before,
    String sort = 'asc',
  }) async =>
      RoomMessagePage(messages: messages, hasMore: false);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRoomSocketService implements RoomSocketService {
  final _eventsController = StreamController<RoomSocketEvent>.broadcast();

  @override
  Stream<RoomSocketEvent> get events => _eventsController.stream;

  @override
  bool get isConnected => true;

  @override
  Future<void> connect() async {}

  @override
  void joinRoom(String roomId) {}

  @override
  void leaveRoom(String roomId) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(this.initialUser);

  final User? initialUser;

  @override
  AuthState build() => AuthState(
        status: initialUser != null
            ? AuthStatus.authenticated
            : AuthStatus.unauthenticated,
        user: initialUser,
      );
}

Widget _buildTestApp({
  required Room room,
  required User currentUser,
  required RoomRepository repo,
  required RoomSocketService socket,
  bool forceConnected = false,
}) {
  final router = GoRouter(
    initialLocation: '/sala/${room.id}',
    routes: [
      GoRoute(
        path: '/sala/:id',
        builder: (context, state) => SalaDetailScreen(
          roomId: state.pathParameters['id']!,
          forceConnected: forceConnected,
        ),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      authControllerProvider
          .overrideWith(() => _FakeAuthNotifier(currentUser)),
      roomRepositoryProvider.overrideWithValue(repo),
      roomSocketProvider.overrideWithValue(socket),
    ],
    child: MaterialApp.router(
      routerConfig: router,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final currentUser = const User(
    id: 'visitor-user-1',
    username: 'visitor',
    displayName: 'Visitante',
  );

  final roomHost = const PostAuthor(
    id: 'host-user-1',
    username: 'host_kyubi',
    displayName: 'Host Principal',
  );

  group('Sala Spam & Quick Chips Removal Verification', () {
    test('Código fuente: _buildQuickGreetings y los chips rápidos fueron eliminados de sala_detail_screen.dart', () {
      final file = File('lib/features/salas/presentation/sala_detail_screen.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      // Ningún remanente de la barra de saludos rápidos o chips fijos
      expect(content.contains('_buildQuickGreetings'), isFalse);
      expect(content.contains("greetings = ['Hi', 'Hello, 👋'"), isFalse);
      expect(content.contains('Invite me, 🥳'), isFalse);
    });

    testWidgets('Los chips rápidos ("Hi", "Invite me", etc.) nunca aparecen en la pantalla', (tester) async {
      final room = Room(
        id: 'room-spam-test',
        name: 'Sala de Conversación',
        host: roomHost,
        isHost: false,
        isParticipant: false,
        participants: const [],
      );

      final fakeRepo = _FakeRoomRepository(room);
      final fakeSocket = _FakeRoomSocketService();

      await tester.pumpWidget(
        _buildTestApp(
          room: room,
          currentUser: currentUser,
          repo: fakeRepo,
          socket: fakeSocket,
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Hi'), findsNothing);
      expect(find.text('Hello, 👋'), findsNothing);
      expect(find.text('Invite me, 🥳'), findsNothing);
      expect(find.text('How are you doing'), findsNothing);
    });

    testWidgets('Visitante no puede responder desde el menú contextual y ve advertencia de unirse a la sala', (tester) async {
      final message = RoomChatMessage(
        id: 'msg-123',
        roomId: 'room-reply-test',
        senderId: 'host-user-1',
        sender: roomHost,
        body: 'Bienvenidos a la sala de prueba',
        type: 'TEXT',
        createdAt: DateTime.now(),
      );

      final room = Room(
        id: 'room-reply-test',
        name: 'Sala de Prueba',
        host: roomHost,
        isHost: false,
        isParticipant: false,
        participants: const [],
      );

      final fakeRepo = _FakeRoomRepository(room, messages: [message]);
      final fakeSocket = _FakeRoomSocketService();

      await tester.pumpWidget(
        _buildTestApp(
          room: room,
          currentUser: currentUser,
          repo: fakeRepo,
          socket: fakeSocket,
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Verificar que el mensaje cargó
      expect(find.text('Bienvenidos a la sala de prueba', findRichText: true), findsOneWidget);

      // Long-press sobre el mensaje para abrir el menú contextual
      await tester.longPress(find.text('Bienvenidos a la sala de prueba', findRichText: true));
      await tester.pumpAndSettle();

      // Debe aparecer la opción Responder con subtítulo indicando unirse
      expect(find.text('Responder'), findsOneWidget);
      expect(find.text('Únete a la sala para responder'), findsOneWidget);

      // Tocar Responder
      await tester.tap(find.text('Responder'));
      await tester.pumpAndSettle();

      // Debe mostrar el SnackBar informativo
      expect(find.text('Debes unirte a la sala para responder a un mensaje'), findsOneWidget);
    });
  });
}
