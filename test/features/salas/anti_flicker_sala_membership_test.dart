import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kyubi/features/salas/presentation/sala_detail_screen.dart';
import 'package:kyubi/features/salas/presentation/widgets/chat_message_input_bar.dart';
import 'package:kyubi/models/post_author.dart';
import 'package:kyubi/models/room.dart';
import 'package:kyubi/models/user.dart';
import 'package:kyubi/repositories/room_repository.dart';
import 'package:kyubi/services/auth_controller.dart';
import 'package:kyubi/services/providers.dart';
import 'package:kyubi/services/room_socket.dart';

class _FakeRoomRepository implements RoomRepository {
  _FakeRoomRepository({this.room});

  final Room? room;

  @override
  Future<Room> getSala(String id) async {
    if (room != null) return room!;
    throw Exception('Room not found');
  }

  @override
  Future<RoomMessagePage> getRoomMessages(
    String id, {
    int limit = 50,
    String? before,
    String sort = 'asc',
  }) async =>
      const RoomMessagePage(messages: [], hasMore: false);

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
  required String roomId,
  required User currentUser,
  required RoomRepository repo,
  required RoomSocketService socket,
  bool forceConnected = false,
}) {
  final router = GoRouter(
    initialLocation: '/sala/$roomId',
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

  final memberUser = const User(
    id: 'user-member-1',
    username: 'member1',
    displayName: 'Miembro Uno',
  );

  final visitorUser = const User(
    id: 'user-visitor-2',
    username: 'visitor2',
    displayName: 'Visitante Dos',
  );

  final roomHost = const PostAuthor(
    id: 'user-host-0',
    username: 'host_sala',
    displayName: 'Host Oficial',
  );

  group('Anti-Flicker Sala Membership & Join Button Tests', () {
    testWidgets(
        'Miembro existente ve ChatMessageInputBar de inmediato sin parpadeo de "Unirse a la sala"',
        (tester) async {
      final room = Room(
        id: 'room-antiflicker-1',
        name: 'Sala Gamer',
        host: roomHost,
        isHost: false,
        isParticipant: true,
        participants: [
          const RoomParticipant(
            user: PostAuthor(
              id: 'user-member-1',
              username: 'member1',
              displayName: 'Miembro Uno',
            ),
            role: 'MEMBER',
            joinedAt: '2026-09-26T10:00:00Z',
          ),
        ],
      );

      final fakeRepo = _FakeRoomRepository(room: room);
      final fakeSocket = _FakeRoomSocketService();

      await tester.pumpWidget(
        _buildTestApp(
          roomId: room.id,
          currentUser: memberUser,
          repo: fakeRepo,
          socket: fakeSocket,
          forceConnected: false, // ¡Prueba clave! forceConnected es false pero es miembro
        ),
      );

      // Primer frame de bombeo:
      await tester.pump();

      // En ningún momento debe mostrar el botón "Unirse a la sala"
      expect(find.text('Unirse a la sala'), findsNothing);

      // Se debe renderizar el ChatMessageInputBar de inmediato
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(ChatMessageInputBar), findsOneWidget);
      expect(find.text('Unirse a la sala'), findsNothing);
    });

    testWidgets(
        'Host de la sala ve ChatMessageInputBar de inmediato sin botón "Unirse a la sala"',
        (tester) async {
      final hostUser = const User(
        id: 'user-host-0',
        username: 'host_sala',
        displayName: 'Host Oficial',
      );

      final room = Room(
        id: 'room-antiflicker-host',
        name: 'Sala Del Creador',
        host: roomHost,
        isHost: true,
        isParticipant: true,
        participants: const [],
      );

      final fakeRepo = _FakeRoomRepository(room: room);
      final fakeSocket = _FakeRoomSocketService();

      await tester.pumpWidget(
        _buildTestApp(
          roomId: room.id,
          currentUser: hostUser,
          repo: fakeRepo,
          socket: fakeSocket,
          forceConnected: false,
        ),
      );

      await tester.pump();
      expect(find.text('Unirse a la sala'), findsNothing);
      expect(find.byType(ChatMessageInputBar), findsOneWidget);
    });

    testWidgets(
        'Visitante real ve botón "Unirse a la sala" una vez cargada la sala',
        (tester) async {
      final room = Room(
        id: 'room-antiflicker-visitor',
        name: 'Sala Pública Exploratoria',
        host: roomHost,
        isHost: false,
        isParticipant: false,
        participants: const [],
      );

      final fakeRepo = _FakeRoomRepository(room: room);
      final fakeSocket = _FakeRoomSocketService();

      await tester.pumpWidget(
        _buildTestApp(
          roomId: room.id,
          currentUser: visitorUser,
          repo: fakeRepo,
          socket: fakeSocket,
          forceConnected: false,
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // El visitante sí debe ver "Unirse a la sala"
      expect(find.text('Unirse a la sala'), findsOneWidget);
      expect(find.byType(ChatMessageInputBar), findsNothing);
    });
  });
}
