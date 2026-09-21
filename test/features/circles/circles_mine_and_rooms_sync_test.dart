import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyubi/features/circles/presentation/circle_detail_controller.dart';
import 'package:kyubi/features/circles/presentation/circles_controller.dart';
import 'package:kyubi/features/circles/presentation/circles_screen.dart';
import 'package:kyubi/models/circle.dart';
import 'package:kyubi/models/post_author.dart';
import 'package:kyubi/models/room.dart';
import 'package:kyubi/models/user.dart';
import 'package:kyubi/repositories/circle_repository.dart';
import 'package:kyubi/repositories/room_repository.dart';
import 'package:kyubi/repositories/user_repository.dart';
import 'package:kyubi/services/providers.dart';

class _FakeCircleRepository implements CircleRepository {
  _FakeCircleRepository({
    this.circles = const [],
    this.myCircles = const [],
  });

  final List<Circle> circles;
  final List<Circle> myCircles;
  int getMyCirclesCallCount = 0;
  int? lastGetMyCirclesLimit;

  @override
  Future<List<Circle>> getCircles({
    int limit = 20,
    String? query,
    bool mine = false,
  }) async {
    return circles;
  }

  @override
  Future<List<Circle>> getMyCircles({int limit = 50}) async {
    getMyCirclesCallCount++;
    lastGetMyCirclesLimit = limit;
    return myCircles;
  }

  @override
  Future<Circle> getCircle(String id) async {
    return myCircles.firstWhere(
      (c) => c.id == id,
      orElse: () => circles.firstWhere((c) => c.id == id),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRoomRepository implements RoomRepository {
  _FakeRoomRepository({this.rooms = const []});

  final List<Room> rooms;
  int? lastLimit;
  String? lastCircleId;

  @override
  Future<List<Room>> getSalas({
    int limit = 50,
    String? circleId,
    String? query,
    String? category,
  }) async {
    lastLimit = limit;
    lastCircleId = circleId;
    return rooms;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUserRepository implements UserRepository {
  @override
  Future<List<FollowItem>> suggestPeople({int limit = 15}) async {
    return [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const author = PostAuthor(
    id: 'user-1',
    username: 'testuser',
    displayName: 'Test User',
  );

  final publicCircle = Circle(
    id: 'circle-public',
    name: 'Comunidad Pública',
    description: 'Descripción pública de prueba',
    creator: author,
    isPrivate: false,
    isCreator: true,
    role: CircleRole.owner,
    memberCount: 42,
    roomCount: 2,
    tags: const ['anime', 'gaming'],
  );

  final privateCircle = Circle(
    id: 'circle-private',
    name: 'Club Privado Exclusivo',
    description: 'Comunidad privada de prueba',
    creator: author,
    isPrivate: true,
    isCreator: true,
    role: CircleRole.owner,
    memberCount: 5,
    roomCount: 1,
    tags: const ['privado', 'vip'],
  );

  final memberCircle = Circle(
    id: 'circle-member',
    name: 'Gremio de Exploradores',
    description: 'Donde soy solo miembro',
    creator: const PostAuthor(
      id: 'other-user',
      username: 'other',
      displayName: 'Other',
    ),
    isPrivate: false,
    isCreator: false,
    role: CircleRole.member,
    memberCount: 120,
    roomCount: 0,
    tags: const ['charla'],
  );

  group('CirclesController & Repositories Sync', () {
    test('CirclesNotifier loads myCircles with limit: 50 on initialization', () async {
      final fakeCircleRepo = _FakeCircleRepository(
        circles: [publicCircle],
        myCircles: [publicCircle, privateCircle],
      );
      final fakeRoomRepo = _FakeRoomRepository();
      final fakeUserRepo = _FakeUserRepository();

      final container = ProviderContainer(
        overrides: [
          circleRepositoryProvider.overrideWithValue(fakeCircleRepo),
          roomRepositoryProvider.overrideWithValue(fakeRoomRepo),
          userRepositoryProvider.overrideWithValue(fakeUserRepo),
        ],
      );
      addTearDown(container.dispose);

      // Trigger initial load
      container.read(circlesControllerProvider);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = container.read(circlesControllerProvider);
      expect(fakeCircleRepo.getMyCirclesCallCount, greaterThanOrEqualTo(1));
      expect(fakeCircleRepo.lastGetMyCirclesLimit, 50);
      expect(state.myCircles.length, 2);
      expect(state.myCircles.any((c) => c.isPrivate), isTrue);
    });

    test('CircleDetailNotifier loads linked rooms with limit: 50', () async {
      final fakeCircleRepo = _FakeCircleRepository(myCircles: [publicCircle]);
      final fakeRoomRepo = _FakeRoomRepository(
        rooms: [
          const Room(
            id: 'room-1',
            name: 'Sala ñ',
            host: author,
            status: RoomStatus.active,
          ),
        ],
      );

      final container = ProviderContainer(
        overrides: [
          circleRepositoryProvider.overrideWithValue(fakeCircleRepo),
          roomRepositoryProvider.overrideWithValue(fakeRoomRepo),
        ],
      );
      addTearDown(container.dispose);

      // Read circle detail provider
      container.read(circleDetailControllerProvider(publicCircle.id));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(fakeRoomRepo.lastLimit, 50);
      expect(fakeRoomRepo.lastCircleId, publicCircle.id);
    });

    test('CirclesNotifier switches tabs between Explorar (0) and Mis Círculos (1)', () {
      final fakeCircleRepo = _FakeCircleRepository();
      final fakeRoomRepo = _FakeRoomRepository();
      final fakeUserRepo = _FakeUserRepository();

      final container = ProviderContainer(
        overrides: [
          circleRepositoryProvider.overrideWithValue(fakeCircleRepo),
          roomRepositoryProvider.overrideWithValue(fakeRoomRepo),
          userRepositoryProvider.overrideWithValue(fakeUserRepo),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(circlesControllerProvider.notifier);
      expect(container.read(circlesControllerProvider).currentTab, 0);

      notifier.setTab(1);
      expect(container.read(circlesControllerProvider).currentTab, 1);

      notifier.setTab(0);
      expect(container.read(circlesControllerProvider).currentTab, 0);
    });
  });

  group('CirclesScreen Widget Tests', () {
    testWidgets('Renders tabs selector with badge and toggles view', (tester) async {
      final fakeCircleRepo = _FakeCircleRepository(
        circles: [publicCircle],
        myCircles: [publicCircle, privateCircle, memberCircle],
      );
      final fakeRoomRepo = _FakeRoomRepository();
      final fakeUserRepo = _FakeUserRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            circleRepositoryProvider.overrideWithValue(fakeCircleRepo),
            roomRepositoryProvider.overrideWithValue(fakeRoomRepo),
            userRepositoryProvider.overrideWithValue(fakeUserRepo),
          ],
          child: const MaterialApp(
            home: CirclesScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Check Tabs exist
      expect(find.text('Explorar'), findsWidgets);
      expect(find.text('Mis Círculos'), findsOneWidget);
      // Badge count "3" should be rendered
      expect(find.text('3'), findsOneWidget);

      // In tab 0, "COMUNIDADES" section header is visible
      expect(find.text('COMUNIDADES'), findsOneWidget);

      // Tap "Mis Círculos" tab
      await tester.tap(find.text('Mis Círculos'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Now "Mis Círculos" list should be displayed
      expect(find.text('Club Privado Exclusivo'), findsOneWidget);
      expect(find.text('Gremio de Exploradores'), findsOneWidget);

      // Check "Privado" badge for private circle
      expect(find.text('Privado'), findsOneWidget);

      // Check role badges
      expect(find.text('👑 Creador'), findsWidgets);
      expect(find.text('🛡️ Miembro'), findsOneWidget);
    });

    testWidgets('CirclesScreen with initialTab: 1 opens directly in Mis Círculos', (tester) async {
      final fakeCircleRepo = _FakeCircleRepository(
        circles: [publicCircle],
        myCircles: [privateCircle],
      );
      final fakeRoomRepo = _FakeRoomRepository();
      final fakeUserRepo = _FakeUserRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            circleRepositoryProvider.overrideWithValue(fakeCircleRepo),
            roomRepositoryProvider.overrideWithValue(fakeRoomRepo),
            userRepositoryProvider.overrideWithValue(fakeUserRepo),
          ],
          child: const MaterialApp(
            home: CirclesScreen(initialTab: 1),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Should directly show private circle
      expect(find.text('Club Privado Exclusivo'), findsOneWidget);
      expect(find.text('Privado'), findsOneWidget);
    });
  });
}
