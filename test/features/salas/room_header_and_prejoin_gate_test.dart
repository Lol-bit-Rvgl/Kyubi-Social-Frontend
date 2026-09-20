import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kyubi/features/salas/presentation/sala_chat_controller.dart';
import 'package:kyubi/features/salas/presentation/sala_detail_controller.dart';
import 'package:kyubi/features/salas/presentation/sala_detail_screen.dart';
import 'package:kyubi/models/post_author.dart';
import 'package:kyubi/models/room.dart';
import 'package:kyubi/models/user.dart';
import 'package:kyubi/repositories/room_repository.dart';
import 'package:kyubi/services/auth_controller.dart';
import 'package:kyubi/services/providers.dart';
import 'package:kyubi/services/room_socket.dart';

class _FakeRoomRepository implements RoomRepository {
  _FakeRoomRepository(this.room);

  final Room room;

  @override
  Future<Room> getSala(String id) async => room;

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
  required Room room,
  required User currentUser,
  required RoomRepository repo,
  required RoomSocketService socket,
}) {
  final router = GoRouter(
    initialLocation: '/sala/${room.id}',
    routes: [
      GoRoute(
        path: '/sala/:id',
        builder: (context, state) => SalaDetailScreen(
          roomId: state.pathParameters['id']!,
          forceConnected: false,
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

  final longNameHost = const PostAuthor(
    id: 'host-long-name-id',
    username: 'super_long_host_user',
    displayName:
        'Lord Comandante Supremo y Regente Absoluto de las Sombras Eternas del Inframundo',
  );

  group('Sala Header - Sin RenderFlex Overflow con Nombres Largos', () {
    testWidgets(
      'Header se renderiza sin desbordamiento horizontal en pantallas estrechas',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final room = Room(
          id: 'room-header-test',
          name: 'Sala con Nombre Extenso y Host con Nombre Muy Largo',
          host: longNameHost,
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

        // 1. Ausencia absoluta de excepciones de desbordamiento de RenderFlex
        expect(tester.takeException(), isNull);

        // 2. Los botones de acción de la derecha están presentes y no colisionan
        expect(find.byTooltip('Invitar amigos'), findsOneWidget);
        expect(find.byTooltip('Información'), findsOneWidget);
        expect(find.byTooltip('Opciones de la sala'), findsOneWidget);
      },
    );
  });

  group('Bloqueo Pre-Join y Exclusión de Sugerencias Rápidas', () {
    testWidgets(
      'Usuario visitante ve "Unirse a la sala" y NUNCA los chips de sugerencias rápidas',
      (tester) async {
        final room = Room(
          id: 'room-prejoin-test',
          name: 'Sala de Aventura',
          host: longNameHost,
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

        // 1. Debe estar presente únicamente la barra de pre-join con el botón "Unirse a la sala"
        expect(find.text('Unirse a la sala'), findsOneWidget);

        // 2. Ninguno de los chips de sugerencias rápidas ("Hi", "Hello, 👋", etc.) debe renderizarse
        expect(find.text('Hi'), findsNothing);
        expect(find.text('Hello, 👋'), findsNothing);
        expect(find.text('Invite me, 🥳'), findsNothing);
        expect(find.text('How are you doing'), findsNothing);
      },
    );

    test(
      'SalaChatNotifier.send bloquea envíos defensivamente si el usuario no es participante',
      () async {
        final room = Room(
          id: 'room-chat-gate-test',
          name: 'Sala Privada',
          host: longNameHost,
          isHost: false,
          isParticipant: false,
          participants: const [],
        );

        final fakeRepo = _FakeRoomRepository(room);
        final fakeSocket = _FakeRoomSocketService();

        final container = ProviderContainer(
          overrides: [
            authControllerProvider
                .overrideWith(() => _FakeAuthNotifier(currentUser)),
            roomRepositoryProvider.overrideWithValue(fakeRepo),
            roomSocketProvider.overrideWithValue(fakeSocket),
          ],
        );
        addTearDown(container.dispose);

        // Cargar la sala en el controlador de detalle
        await container
            .read(salaDetailControllerProvider('room-chat-gate-test').notifier)
            .refresh();

        // Intentar enviar mensaje desde el controlador de chat
        final chatNotifier = container
            .read(salaChatControllerProvider('room-chat-gate-test').notifier);
        final sentOk = await chatNotifier.send('Mensaje sin autorización');

        // Debe ser rechazado
        expect(sentOk, isFalse);
        expect(
          container
              .read(salaChatControllerProvider('room-chat-gate-test'))
              .messages,
          isEmpty,
        );
      },
    );
  });
}
