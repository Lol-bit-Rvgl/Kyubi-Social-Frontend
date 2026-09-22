import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kyubi/core/errors/api_exception.dart';
import 'package:kyubi/features/circles/presentation/circle_detail_screen.dart';
import 'package:kyubi/features/salas/presentation/sala_detail_screen.dart';
import 'package:kyubi/features/salas/presentation/salas_controller.dart';
import 'package:kyubi/models/circle.dart';
import 'package:kyubi/models/post_author.dart';
import 'package:kyubi/models/room.dart';
import 'package:kyubi/models/user.dart';
import 'package:kyubi/repositories/circle_repository.dart';
import 'package:kyubi/repositories/room_repository.dart';
import 'package:kyubi/services/auth_controller.dart';
import 'package:kyubi/services/providers.dart';
import 'package:kyubi/services/room_socket.dart';

// ── Fakes ────────────────────────────────────────────────────────────────────

class _FakeRoomRepository implements RoomRepository {
  _FakeRoomRepository(this.room, {this.onSend});

  final Room room;
  final Future<RoomChatMessage> Function(String body)? onSend;

  @override
  Future<Room> getSala(String id) async => room;

  @override
  Future<RoomMessagePage> getRoomMessages(
    String id, {
    int limit = 50,
    String? before,
    String sort = 'asc',
  }) async => const RoomMessagePage(messages: [], hasMore: false);

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
  }) {
    final handler = onSend;
    if (handler == null) {
      return Future.value(
        RoomChatMessage(
          id: 'srv-1',
          roomId: id,
          senderId: 'me',
          sender: const PostAuthor(id: 'me', username: 'me', displayName: 'Me'),
          body: body,
          createdAt: DateTime.now(),
          clientTempId: metadata?['clientTempId'] as String?,
        ),
      );
    }
    return handler(body);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCircleRepository implements CircleRepository {
  _FakeCircleRepository(this.circle);

  final Circle circle;

  @override
  Future<Circle> getCircle(String id) async => circle;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRoomSocketService implements RoomSocketService {
  final _eventsController = StreamController<RoomSocketEvent>.broadcast();
  final List<String> joinedRooms = [];
  int connectCalls = 0;

  @override
  Stream<RoomSocketEvent> get events => _eventsController.stream;

  @override
  bool get isConnected => true;

  @override
  Future<void> connect() async {
    connectCalls++;
  }

  @override
  void joinRoom(String roomId) {
    joinedRooms.add(roomId);
  }

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

// ── Helpers ──────────────────────────────────────────────────────────────────

const _currentUser = User(
  id: 'me',
  username: 'me_user',
  displayName: 'Yo Mismo',
);

Widget _buildSalaApp({
  required Room room,
  required RoomRepository repo,
  required RoomSocketService socket,
  bool forceConnected = true,
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
      authControllerProvider.overrideWith(
        () => _FakeAuthNotifier(_currentUser),
      ),
      roomRepositoryProvider.overrideWithValue(repo),
      roomSocketProvider.overrideWithValue(socket),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

/// Campo de composición del chat (barra inferior de la sala).
Finder _composerField() => find.byType(TextField).last;

/// Pulsa el botón ➤ de envío de la barra de mensajes.
Future<void> _tapSend(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.send_rounded).last);
  await tester.pump();
}

Room _room(String id) => Room(
  id: id,
  name: 'Sala $id',
  host: const PostAuthor(
    id: 'me',
    username: 'me_user',
    displayName: 'Yo Mismo',
  ),
  isHost: true,
  isParticipant: true,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  group('Envío real de mensajes en salas (persistencia + socket + errores)', () {
    testWidgets(
      'Un envío rechazado por el backend no deja mensajes fantasma y muestra "Error al enviar mensaje"',
      (tester) async {
        final room = _room('room-fail');
        final repo = _FakeRoomRepository(
          room,
          onSend: (_) async => throw const ApiException(
            message: 'Debes entrar a la sala para enviar mensajes',
            statusCode: 403,
          ),
        );
        final socket = _FakeRoomSocketService();

        await tester.pumpWidget(
          _buildSalaApp(room: room, repo: repo, socket: socket),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.enterText(_composerField(), 'Mensaje fantasma');
        await tester.pump();

        await _tapSend(tester);
        // Microtask del POST fallido + rebuild con la reversión y el aviso.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(
          find.text('Mensaje fantasma', findRichText: true),
          findsNothing,
          reason: 'El mensaje optimista debe retirarse si no se persistió',
        );
        expect(find.text('Error al enviar mensaje'), findsOneWidget);

        // El store de sesión tampoco conserva restos `local-`.
        final container = ProviderScope.containerOf(
          tester.element(find.byType(SalaDetailScreen)),
          listen: false,
        );
        final stored = container
            .read(salasControllerProvider.notifier)
            .messagesFor(room.id);
        expect(stored, isEmpty);
      },
    );

    testWidgets(
      'Un envío confirmado por el backend reemplaza el optimista y permanece en el historial',
      (tester) async {
        final room = _room('room-ok');
        final repo = _FakeRoomRepository(room);
        final socket = _FakeRoomSocketService();

        await tester.pumpWidget(
          _buildSalaApp(room: room, repo: repo, socket: socket),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.enterText(_composerField(), 'Mensaje persistido');
        await tester.pump();

        await _tapSend(tester);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(
          find.text('Mensaje persistido', findRichText: true),
          findsOneWidget,
        );
        expect(find.text('Error al enviar mensaje'), findsNothing);

        final container = ProviderScope.containerOf(
          tester.element(find.byType(SalaDetailScreen)),
          listen: false,
        );
        final stored = container
            .read(salasControllerProvider.notifier)
            .messagesFor(room.id);
        expect(stored.length, 1);
        expect(
          stored.every((m) => !'${m['id'] ?? ''}'.startsWith('local-')),
          isTrue,
          reason: 'El mensaje debe haberse sustituido por el id del servidor',
        );
      },
    );

    testWidgets(
      'La sala queda unida al socket (room:join) al entrar y se re-asegura al enviar',
      (tester) async {
        final room = _room('room-socket');
        final socket = _FakeRoomSocketService();

        await tester.pumpWidget(
          _buildSalaApp(
            room: room,
            repo: _FakeRoomRepository(room),
            socket: socket,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(socket.joinedRooms, contains(room.id));
        final joinsAfterEnter = socket.joinedRooms.length;

        await tester.enterText(_composerField(), 'Hola');
        await tester.pump();
        await _tapSend(tester);
        await tester.pump(const Duration(milliseconds: 50));

        expect(
          socket.joinedRooms.length,
          greaterThan(joinsAfterEnter),
          reason:
              'Antes de publicar se re-emite room:join de forma idempotente',
        );
      },
    );

    test(
      'Código fuente: _sendPersisted revierte el optimista y avisa en vez de ignorar el error',
      () {
        final file = File(
          'lib/features/salas/presentation/sala_detail_screen.dart',
        );
        expect(file.existsSync(), isTrue);
        final content = file.readAsStringSync();

        expect(
          content.contains("_showSendError('Error al enviar mensaje')"),
          isTrue,
        );
        expect(
          content.contains('salas.deleteRoomMessage(widget.roomId, localId)'),
          isTrue,
        );
        expect(
          content.contains(
            'Sin conexión: se conserva el mensaje optimista con estado local.',
          ),
          isFalse,
          reason:
              'El catch silencioso que generaba mensajes fantasma fue eliminado',
        );
      },
    );
  });

  group('Comunidades: FAB fantasma', () {
    test('Código fuente: circles_screen fija floatingActionButton: null', () {
      final file = File(
        'lib/features/circles/presentation/circles_screen.dart',
      );
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      expect(content.contains('floatingActionButton: null'), isTrue);
      expect(
        content.contains('FloatingActionButton('),
        isFalse,
        reason:
            'Comunidades no debe montar ningún FAB (el "+ Crear" va en la cabecera)',
      );
    });

    testWidgets(
      'CircleDetailScreen retira el FAB Publicar en el primer fotograma del pop',
      (tester) async {
        final circleRepo = _FakeCircleRepository(
          Circle(
            id: 'circle-1',
            name: 'Anime Club',
            creator: const PostAuthor(
              id: 'user-a',
              username: 'alice',
              displayName: 'Alice',
            ),
            isMember: true,
          ),
        );
        final roomRepo = _FakeRoomRepository(
          Room(
            id: 'room-x',
            name: 'Sala del círculo',
            host: const PostAuthor(
              id: 'user-a',
              username: 'alice',
              displayName: 'Alice',
            ),
          ),
        );

        final navigatorKey = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              circleRepositoryProvider.overrideWithValue(circleRepo),
              roomRepositoryProvider.overrideWithValue(roomRepo),
            ],
            child: MaterialApp(
              navigatorKey: navigatorKey,
              home: const Scaffold(body: Center(child: Text('Comunidades'))),
            ),
          ),
        );

        navigatorKey.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => const CircleDetailScreen(circleId: 'circle-1'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Publicar'), findsOneWidget);

        navigatorKey.currentState!.pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));

        expect(find.text('Comunidades'), findsOneWidget);
        expect(
          find.text('Publicar'),
          findsNothing,
          reason:
              'El FAB no debe quedar flotando sobre Comunidades durante el pop',
        );

        await tester.pumpAndSettle();
      },
    );
  });
}
