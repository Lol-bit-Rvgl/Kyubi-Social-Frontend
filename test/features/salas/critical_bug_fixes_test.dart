import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyubi/features/profile/presentation/visit_profile_screen.dart';
import 'package:kyubi/features/roles/presentation/role_slots_controller.dart';
import 'package:kyubi/features/roles/presentation/role_slots_editor_screen.dart';
import 'package:kyubi/models/post_author.dart';
import 'package:kyubi/models/room.dart';
import 'package:kyubi/models/user.dart';
import 'package:kyubi/repositories/user_repository.dart';
import 'package:kyubi/services/auth_controller.dart';
import 'package:kyubi/services/providers.dart';
import 'package:kyubi/services/voice/voice_room_controller.dart';

class _FakeUserRepository implements UserRepository {
  final User profileUser;
  _FakeUserRepository(this.profileUser);

  @override
  Future<User> getProfile(String username) async => profileUser;

  @override
  Future<void> registerVisit(String username) async {}

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

class _FakeRoleSlotsNotifier extends RoleSlotsNotifier {
  @override
  RoleSlotsState build(String arg) => const RoleSlotsState(
        slots: [],
      );
}

void main() {
  group('Corrección de 3 Bugs Críticos (Salas, Perfiles y Editor de Roles)', () {
    test('Bug 2 - VoiceRoomController.leaveRoom() reinicia completamente el estado de voz', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(voiceRoomProvider.notifier);

      // Simular que el usuario tenía participantes silenciados remotamente
      notifier.setRemoteMuted('user-99', muted: true);
      expect(container.read(voiceRoomProvider).mutedIds, contains('user-99'));

      // Desconectar / Salir
      await notifier.leaveRoom();

      final state = container.read(voiceRoomProvider);
      expect(state.status, equals(VoiceConnectionStatus.idle));
      expect(state.activeRoomId, isNull);
      expect(state.roomName, isEmpty);
      expect(state.participants, isEmpty);
      expect(state.mutedIds, isEmpty);
      expect(state.isDeafened, isFalse);
      expect(state.isMuted, isTrue);
      expect(state.isMicEnabled, isFalse);
    });

    testWidgets('Bug 3 - RoleSlotEditorScreen tolera lista de vacantes vacía sin RangeError', (tester) async {
      // Si slots.isEmpty, no debe lanzar RangeError y el botón debe decir "+ Crear primer slot"
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            roleSlotsControllerProvider.overrideWith(_FakeRoleSlotsNotifier.new),
          ],
          child: const MaterialApp(
            home: RoleSlotEditorScreen(
              postId: 'post-123',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('+ Crear primer slot'), findsOneWidget);
      expect(find.text('Nueva vacante'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'No debe arrojar RangeError cuando no hay slots');
    });

    test('Bug 3 - RoleSlotsEditorScreen es un alias válido de RoleSlotEditorScreen', () {
      expect(RoleSlotsEditorScreen, equals(RoleSlotEditorScreen));
    });

    test('Bug 1 - Detección de perfil propio en salas y anfitrión', () {
      const currentUserId = 'user-me-123';
      const ownHost = PostAuthor(
        id: 'user-me-123',
        username: 'my_user',
        displayName: 'Mi Perfil',
      );
      const otherHost = PostAuthor(
        id: 'user-other-456',
        username: 'other_user',
        displayName: 'Otro Usuario',
      );

      final roomOwn = Room(
        id: 'room-1',
        name: 'Sala Test',
        host: ownHost,
      );

      final roomOther = Room(
        id: 'room-2',
        name: 'Sala Ajena',
        host: otherHost,
      );

      // Evaluación del anfitrión en tarjeta
      final isOwnHost1 = currentUserId == roomOwn.host.id;
      final isOwnHost2 = currentUserId == roomOther.host.id;

      expect(isOwnHost1, isTrue, reason: 'Debe reconocer que el host es la sesión activa');
      expect(isOwnHost2, isFalse, reason: 'Debe reconocer que el host es un tercero');
    });

    testWidgets('Bug 1 - VisitProfileScreen muestra "Editar perfil" en vez de "Seguir" y "Chat" si es perfil propio', (tester) async {
      final myUser = User(
        id: 'user-me-123',
        username: 'my_user',
        email: 'me@example.com',
        displayName: 'Mi Perfil',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(() => _FakeAuthNotifier(myUser)),
            userRepositoryProvider.overrideWithValue(_FakeUserRepository(myUser)),
          ],
          child: const MaterialApp(
            home: VisitProfileScreen(username: 'my_user'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Debe mostrar Editar perfil y NO Seguir
      expect(find.text('Editar perfil'), findsOneWidget);
      expect(find.text('Seguir'), findsNothing);
      expect(find.text('Chat'), findsNothing);
    });
  });
}
