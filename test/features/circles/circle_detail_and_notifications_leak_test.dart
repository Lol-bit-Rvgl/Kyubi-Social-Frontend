import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kyubi/core/storage/session_store.dart';
import 'package:kyubi/features/circles/presentation/circle_detail_controller.dart';
import 'package:kyubi/features/circles/presentation/circle_detail_screen.dart';
import 'package:kyubi/features/notifications/presentation/notifications_controller.dart';
import 'package:kyubi/models/circle.dart';
import 'package:kyubi/models/notification_item.dart';
import 'package:kyubi/models/post_author.dart';
import 'package:kyubi/models/room.dart';
import 'package:kyubi/repositories/circle_repository.dart';
import 'package:kyubi/repositories/room_repository.dart';
import 'package:kyubi/services/providers.dart';

class _FakeCircleRepository implements CircleRepository {
  _FakeCircleRepository(this.circle);
  final Circle circle;

  @override
  Future<Circle> getCircle(String id) async => circle;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRoomRepository implements RoomRepository {
  _FakeRoomRepository(this.rooms);
  final List<Room> rooms;

  @override
  Future<List<Room>> getSalas({
    int limit = 30,
    String? circleId,
    String? query,
    String? category,
  }) async => rooms;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const authorA = PostAuthor(
    id: 'user-a',
    username: 'alice',
    displayName: 'Alice Wonderland',
  );

  const authorB = PostAuthor(
    id: 'user-b',
    username: 'bob',
    displayName: 'Bob Builder',
  );

  final testCircle = Circle(
    id: 'circle-anime',
    name: 'Anime & Manga Fan Club',
    description: 'Comunidad dedicada a discusión de anime y manga',
    creator: authorA,
    members: const [
      CircleMember(
        user: authorB,
        role: CircleRole.admin,
        joinedAt: '2026-01-01',
      ),
    ],
  );

  group('NotificationsCache - Per-user isolation & logout cleanup', () {
    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});
    });

    test('Saves and reads notifications correctly for a specific user', () async {
      const item = NotificationItem(
        id: 'notif-1',
        type: 'LIKE',
        timeAgo: 'hace 5m',
        createdAt: '2026-09-20T12:00:00Z',
        actor: authorA,
        text: 'le dio like a tu post',
      );

      await NotificationsCache.save([item], userId: 'user-a');

      final loadedA = await NotificationsCache.read(userId: 'user-a');
      expect(loadedA.length, 1);
      expect(loadedA.first['id'], 'notif-1');
      expect(loadedA.first['text'], 'le dio like a tu post');

      // User B should NOT see user A's cache (isolated storage key)
      final loadedB = await NotificationsCache.read(userId: 'user-b');
      expect(loadedB, isEmpty);
    });

    test('Clear removes user cache completely without leaking', () async {
      const itemA = NotificationItem(
        id: 'notif-a',
        type: 'REPOST',
        timeAgo: 'hace 10m',
        createdAt: '2026-09-20T12:00:00Z',
        actor: authorA,
      );

      const itemB = NotificationItem(
        id: 'notif-b',
        type: 'COMMENT',
        timeAgo: 'hace 1m',
        createdAt: '2026-09-20T12:00:00Z',
        actor: authorB,
      );

      await NotificationsCache.save([itemA], userId: 'user-a');
      await NotificationsCache.save([itemB], userId: 'user-b');

      // Clear user A
      await NotificationsCache.clear(userId: 'user-a');

      expect(await NotificationsCache.read(userId: 'user-a'), isEmpty);
      // User B should remain unaffected
      final loadedB = await NotificationsCache.read(userId: 'user-b');
      expect(loadedB.length, 1);
      expect(loadedB.first['id'], 'notif-b');
    });
  });

  group('NotificationsNotifier - Clear reset', () {
    test('clear() resets state to empty items', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(notificationsControllerProvider.notifier);
      notifier.clear();

      final state = container.read(notificationsControllerProvider);
      expect(state.items, isEmpty);
    });
  });

  group('CircleDetailController & Salas Tab Binding', () {
    test('CircleDetailNotifier loads real rooms via RoomRepository', () async {
      const room = Room(
        id: 'room-101',
        name: 'Debate Semanal Shingeki',
        host: authorA,
        participantCount: 5,
      );

      final fakeCircleRepo = _FakeCircleRepository(testCircle);
      final fakeRoomRepo = _FakeRoomRepository([room]);

      final container = ProviderContainer(
        overrides: [
          circleRepositoryProvider.overrideWithValue(fakeCircleRepo),
          roomRepositoryProvider.overrideWithValue(fakeRoomRepo),
        ],
      );
      addTearDown(container.dispose);

      final subscription = container.listen(
        circleDetailControllerProvider('circle-anime'),
        (_, _) {},
      );
      addTearDown(subscription.close);

      // Wait microtasks / load
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = container.read(circleDetailControllerProvider('circle-anime'));
      expect(state.rooms.length, 1);
      expect(state.rooms.first.id, 'room-101');
      expect(state.rooms.first.name, 'Debate Semanal Shingeki');
    });

    testWidgets('Salas Tab renders empty state when no rooms exist and does NOT use ghost room', (tester) async {
      final fakeCircleRepo = _FakeCircleRepository(testCircle);
      final fakeRoomRepo = _FakeRoomRepository([]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            circleRepositoryProvider.overrideWithValue(fakeCircleRepo),
            roomRepositoryProvider.overrideWithValue(fakeRoomRepo),
          ],
          child: const MaterialApp(
            home: CircleDetailScreen(circleId: 'circle-anime'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap on the 'Salas' tab (tab index 2)
      final salasTab = find.widgetWithText(Tab, 'Salas');
      expect(salasTab, findsOneWidget);
      await tester.tap(salasTab);
      await tester.pumpAndSettle();

      // Verify the empty state is displayed
      expect(
        find.text('No hay salas en vivo en este círculo en este momento'),
        findsOneWidget,
      );
      expect(find.text('Crear sala'), findsOneWidget);
      // Ghost room text should NEVER exist
      expect(find.text('Anime & Manga Fan Club Lounge'), findsNothing);
    });

    testWidgets('Salas Tab renders real room with live tag and Entrar button', (tester) async {
      const liveRoom = Room(
        id: 'real-room-42',
        name: 'Sala de Teorías y Spoilers',
        host: authorA,
        participantCount: 8,
      );

      final fakeCircleRepo = _FakeCircleRepository(testCircle);
      final fakeRoomRepo = _FakeRoomRepository([liveRoom]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            circleRepositoryProvider.overrideWithValue(fakeCircleRepo),
            roomRepositoryProvider.overrideWithValue(fakeRoomRepo),
          ],
          child: const MaterialApp(
            home: CircleDetailScreen(circleId: 'circle-anime'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap on the 'Salas' tab
      await tester.tap(find.widgetWithText(Tab, 'Salas'));
      await tester.pumpAndSettle();

      // Verify room details
      expect(find.text('Sala de Teorías y Spoilers'), findsOneWidget);
      expect(find.text('LIVE'), findsOneWidget);
      expect(find.text('Host: @alice · 8 activos'), findsOneWidget);
      expect(find.text('Entrar'), findsOneWidget);

      // Verify empty state is NOT rendered
      expect(
        find.text('No hay salas en vivo en este círculo en este momento'),
        findsNothing,
      );
    });

    testWidgets('Info Tab displays clickable leader and moderator items', (tester) async {
      final fakeCircleRepo = _FakeCircleRepository(testCircle);
      final fakeRoomRepo = _FakeRoomRepository([]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            circleRepositoryProvider.overrideWithValue(fakeCircleRepo),
            roomRepositoryProvider.overrideWithValue(fakeRoomRepo),
          ],
          child: const MaterialApp(
            home: CircleDetailScreen(circleId: 'circle-anime'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap on 'Info' tab
      await tester.tap(find.widgetWithText(Tab, 'Info'));
      await tester.pumpAndSettle();

      // Find Moderator cards
      expect(find.text('Voluntarios & Moderadores'), findsOneWidget);
      expect(find.text('Bob Builder'), findsOneWidget);
      expect(find.text('@bob'), findsOneWidget);
      expect(find.text('🛡️ Admin'), findsOneWidget);
    });
  });
}
