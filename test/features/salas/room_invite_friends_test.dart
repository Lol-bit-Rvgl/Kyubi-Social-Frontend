import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyubi/features/salas/presentation/widgets/room_invite_friends_sheet.dart';
import 'package:kyubi/models/post_author.dart';
import 'package:kyubi/models/room.dart';
import 'package:kyubi/models/user.dart';
import 'package:kyubi/repositories/user_repository.dart';
import 'package:kyubi/services/auth_controller.dart';
import 'package:kyubi/services/providers.dart';
import 'package:kyubi/services/room_socket.dart';

class _FakeUserRepository implements UserRepository {
  _FakeUserRepository({
    required this.followingUsers,
    required this.followerUsers,
  });

  final List<FollowItem> followingUsers;
  final List<FollowItem> followerUsers;

  @override
  Future<FollowListResult> getFollowing(
    String usernameOrId, {
    String? cursor,
    int limit = 20,
  }) async {
    return FollowListResult(items: followingUsers, nextCursor: null);
  }

  @override
  Future<FollowListResult> getFollowers(
    String usernameOrId, {
    String? cursor,
    int limit = 20,
  }) async {
    return FollowListResult(items: followerUsers, nextCursor: null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRoomSocketService implements RoomSocketService {
  final List<Map<String, dynamic>> emittedInvites = <Map<String, dynamic>>[];

  @override
  void emitInvite({
    required String roomId,
    required String targetUserId,
    String? roomName,
    String? roomBanner,
  }) {
    emittedInvites.add({
      'roomId': roomId,
      'targetUserId': targetUserId,
      'roomName': roomName,
      'roomBanner': roomBanner,
    });
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

void main() {
  final currentUser = User(
    id: 'my-user-id',
    email: 'me@example.com',
    username: 'my_user',
    displayName: 'Mi Usuario',
    createdAt: DateTime.now(),
  );

  final room = Room(
    id: 'room-101',
    name: 'Anime & Gaming Hangout',
    imageUrl: 'https://example.com/banner.png',
    currentMode: 'standard',
    host: const PostAuthor(
      id: 'host-1',
      username: 'host_user',
      displayName: 'El Host',
    ),
    status: RoomStatus.active,
    access: RoomAccess.public,
    kind: RoomKind.social,
  );

  final testFollowing = [
    const FollowItem(
      id: 'friend-1',
      username: 'naruto',
      displayName: 'Naruto Uzumaki',
    ),
    const FollowItem(
      id: 'friend-2',
      username: 'sasuke',
      displayName: 'Sasuke Uchiha',
    ),
  ];

  final testFollowers = [
    const FollowItem(
      id: 'friend-3',
      username: 'sakura',
      displayName: 'Sakura Haruno',
    ),
  ];

  testWidgets('RoomInviteFriendsSheet renders contacts, filters by search, and sends invite',
      (tester) async {
    final fakeRepo = _FakeUserRepository(
      followingUsers: testFollowing,
      followerUsers: testFollowers,
    );
    final fakeSocket = _FakeRoomSocketService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(() => _FakeAuthNotifier(currentUser)),
          userRepositoryProvider.overrideWithValue(fakeRepo),
          roomSocketProvider.overrideWithValue(fakeSocket),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: RoomInviteFriendsSheet(room: room),
          ),
        ),
      ),
    );

    // Esperar a que se resuelvan las promesas de carga de amigos
    await tester.pumpAndSettle();

    // 1. Verificar encabezado
    expect(find.text('Invitar amigos a la sala'), findsOneWidget);
    expect(find.text('Anime & Gaming Hangout'), findsOneWidget);

    // 2. Verificar que los contactos están presentes
    expect(find.text('Naruto Uzumaki'), findsOneWidget);
    expect(find.text('@naruto'), findsOneWidget);
    expect(find.text('Sasuke Uchiha'), findsOneWidget);
    expect(find.text('@sasuke'), findsOneWidget);
    expect(find.text('Sakura Haruno'), findsOneWidget);
    expect(find.text('@sakura'), findsOneWidget);

    // 3. Filtrar por búsqueda
    await tester.enterText(find.byType(TextField), 'Sasuke');
    await tester.pumpAndSettle();

    expect(find.text('Sasuke Uchiha'), findsOneWidget);
    expect(find.text('Naruto Uzumaki'), findsNothing);
    expect(find.text('Sakura Haruno'), findsNothing);

    // Limpiar búsqueda
    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();
    expect(find.text('Naruto Uzumaki'), findsOneWidget);

    // 4. Invitar a Naruto
    final invitarButtons = find.text('Invitar');
    expect(invitarButtons, findsWidgets);

    // Tocar el primer botón "Invitar" (Naruto)
    await tester.tap(invitarButtons.first);
    await tester.pumpAndSettle();

    // Verificar que el socket emitió el evento
    expect(fakeSocket.emittedInvites.length, 1);
    expect(fakeSocket.emittedInvites.first['roomId'], 'room-101');
    expect(fakeSocket.emittedInvites.first['targetUserId'], 'friend-1');
    expect(fakeSocket.emittedInvites.first['roomName'], 'Anime & Gaming Hangout');

    // Verificar que el botón cambió a "Invitado"
    expect(find.text('Invitado'), findsOneWidget);
  });

  testWidgets('RoomInviteFriendsSheet filters out users who are already room participants or host',
      (tester) async {
    final roomWithParticipants = Room(
      id: 'room-102',
      name: 'Gaming Room',
      currentMode: 'standard',
      host: const PostAuthor(
        id: 'friend-1', // Naruto es el host
        username: 'naruto',
        displayName: 'Naruto Uzumaki',
      ),
      participants: const [
        RoomParticipant(
          user: PostAuthor(
            id: 'friend-2', // Sasuke ya es participante
            username: 'sasuke',
            displayName: 'Sasuke Uchiha',
          ),
          role: 'PARTICIPANT',
          joinedAt: '2026-09-15T00:00:00Z',
        ),
      ],
      status: RoomStatus.active,
      access: RoomAccess.public,
      kind: RoomKind.social,
    );

    final fakeRepo = _FakeUserRepository(
      followingUsers: testFollowing,
      followerUsers: testFollowers,
    );
    final fakeSocket = _FakeRoomSocketService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(() => _FakeAuthNotifier(currentUser)),
          userRepositoryProvider.overrideWithValue(fakeRepo),
          roomSocketProvider.overrideWithValue(fakeSocket),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: RoomInviteFriendsSheet(room: roomWithParticipants),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Naruto (host) y Sasuke (participante) deben estar excluidos
    expect(find.text('Naruto Uzumaki'), findsNothing);
    expect(find.text('Sasuke Uchiha'), findsNothing);

    // Sakura (no participante) debe estar disponible
    expect(find.text('Sakura Haruno'), findsOneWidget);
    expect(find.text('Invitar'), findsOneWidget);
  });
}
