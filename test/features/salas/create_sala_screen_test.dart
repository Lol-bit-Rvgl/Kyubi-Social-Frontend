import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyubi/features/salas/presentation/create_sala_screen.dart';
import 'package:kyubi/models/circle.dart';
import 'package:kyubi/models/user.dart';
import 'package:kyubi/repositories/circle_repository.dart';
import 'package:kyubi/repositories/user_repository.dart';
import 'package:kyubi/services/auth_controller.dart';
import 'package:kyubi/services/providers.dart';

class _FakeCircleRepository implements CircleRepository {
  @override
  Future<List<Circle>> getMyCircles({int limit = 30}) async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUserRepository implements UserRepository {
  @override
  Future<FollowListResult> getFollowing(String usernameOrId, {String? cursor, int limit = 20}) async {
    return const FollowListResult(items: [], nextCursor: null);
  }

  @override
  Future<FollowListResult> getFollowers(String usernameOrId, {String? cursor, int limit = 20}) async {
    return const FollowListResult(items: [], nextCursor: null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => AuthState(
        status: AuthStatus.authenticated,
        user: User(
          id: 'test-user-1',
          username: 'testuser',
          email: 'test@example.com',
          displayName: 'Test User',
          createdAt: DateTime.now(),
        ),
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestWidget({bool isPrivateInitial = false, String? circleId}) {
    return ProviderScope(
      overrides: [
        circleRepositoryProvider.overrideWithValue(_FakeCircleRepository()),
        userRepositoryProvider.overrideWithValue(_FakeUserRepository()),
        authControllerProvider.overrideWith(_FakeAuthNotifier.new),
      ],
      child: MaterialApp(
        home: CreateSalaScreen(
          isPrivateInitial: isPrivateInitial,
          circleId: circleId,
        ),
      ),
    );
  }

  group('CreateSalaScreen - Estado inicial de Acceso (isPrivateInitial)', () {
    testWidgets('Por defecto (isPrivateInitial: false) inicializa el acceso en "Pública"', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestWidget(isPrivateInitial: false));
      await tester.pumpAndSettle();

      final dropdownFinder = find.byType(DropdownButtonFormField<String>);
      expect(dropdownFinder, findsOneWidget);

      expect(find.text('Pública'), findsOneWidget);
    });

    testWidgets('Con isPrivateInitial: true inicializa el acceso en "Privada"', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestWidget(isPrivateInitial: true));
      await tester.pumpAndSettle();

      final dropdownFinder = find.byType(DropdownButtonFormField<String>);
      expect(dropdownFinder, findsOneWidget);

      expect(find.text('Privada'), findsOneWidget);
    });

    testWidgets('Permite alternar entre Pública y Privada dinámicamente', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestWidget(isPrivateInitial: false));
      await tester.pumpAndSettle();

      expect(find.text('Pública'), findsOneWidget);

      // Abrir dropdown y seleccionar Privada
      await tester.tap(find.text('Pública'));
      await tester.pumpAndSettle();

      final privadaItemFinder = find.text('Privada').last;
      await tester.tap(privadaItemFinder);
      await tester.pumpAndSettle();

      expect(find.text('Privada'), findsOneWidget);
    });
  });
}
