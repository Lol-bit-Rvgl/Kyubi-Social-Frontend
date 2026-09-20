import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyubi/core/network/api_client.dart';
import 'package:kyubi/features/roles/presentation/role_library_screen.dart';
import 'package:kyubi/models/character.dart';
import 'package:kyubi/models/role_character.dart';
import 'package:kyubi/models/user.dart';
import 'package:kyubi/repositories/character_repository.dart';
import 'package:kyubi/services/auth_controller.dart';

class _FakeApiClient extends Fake implements ApiClient {
  String? lastGetPath;

  @override
  Future<Map<String, dynamic>> getJson(String path, {Map<String, dynamic>? query}) async {
    lastGetPath = path;
    if (path == '/characters/mine') {
      return {
        'total': 1,
        'data': [
          {
            'id': 'char-101',
            'userId': 'user-1',
            'name': 'Kitsune Shinobi',
            'tagline': 'Guerrero Espectral',
            'description': 'Protector del clan del zorro',
            'avatarUrl': 'https://kyubi.app/cdn/shinobi.png',
            'themeColor': '#FF0055',
          }
        ],
      };
    }
    return {'data': []};
  }
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
  group('1. Modelo de Monedas y Privacidad de Usuario', () {
    test('User.coins retorna el valor explícito de extensions["coins"]', () {
      const user = User(
        id: 'u-1',
        username: 'fox',
        displayName: 'Fox',
        level: 1,
        extensions: {'coins': 999},
      );
      expect(user.coins, 999);
    });

    test('User.coins retorna el valor anidado de extensions["wallet"]["coins"]', () {
      const user = User(
        id: 'u-2',
        username: 'wolf',
        displayName: 'Wolf',
        level: 1,
        extensions: {
          'wallet': {'coins': 750}
        },
      );
      expect(user.coins, 750);
    });

    test('User.coins calcula defensivamente con el nivel si no hay extensions', () {
      const user = User(
        id: 'u-3',
        username: 'tanuki',
        displayName: 'Tanuki',
        level: 2,
      );
      // level * 150 + 420 = 2 * 150 + 420 = 720
      expect(user.coins, 720);
    });
  });

  group('2. Repositorio de Personajes y Endpoint Canónico', () {
    test('getMyRoles consulta /characters/mine', () async {
      final fakeApi = _FakeApiClient();
      final repo = CharacterRepository(fakeApi);

      final roles = await repo.getMyRoles();

      expect(fakeApi.lastGetPath, '/characters/mine');
      expect(roles.length, 1);
      expect(roles.first.id, 'char-101');
      expect(roles.first.name, 'Kitsune Shinobi');
      expect(roles.first.role, 'Guerrero Espectral');
      expect(roles.first.avatarUrl, 'https://kyubi.app/cdn/shinobi.png');
      expect(roles.first.themeColor, '#FF0055');
    });

    test('Character.toRoleCharacter propaga avatarUrl y themeColor', () {
      final character = Character(
        id: 'char-101',
        userId: 'user-1',
        name: 'Kitsune Shinobi',
        role: 'Guerrero Espectral',
        avatarUrl: 'https://kyubi.app/cdn/shinobi.png',
        themeColor: '#FF0055',
      );

      final role = character.toRoleCharacter(
        currentUserId: 'user-1',
        currentUsername: 'FoxMaster',
      );

      expect(role.id, 'char-101');
      expect(role.name, 'Kitsune Shinobi');
      expect(role.avatarUrl, 'https://kyubi.app/cdn/shinobi.png');
      expect(role.colorHex, '#FF0055');
      expect(role.isTaken, true);
      expect(role.takenByUserId, 'user-1');
      expect(role.takenByUsername, 'FoxMaster');
    });
  });

  group('3. Persistencia de Rol y Avatar al "Bajar" (toVacant)', () {
    test('toVacant preserva avatarUrl y limpia al ocupante', () {
      const occupiedRole = RoleCharacter(
        id: 'char-101',
        name: 'Kitsune Shinobi',
        avatarUrl: 'https://kyubi.app/cdn/edited_avatar.png',
        colorHex: '#00E5FF',
        tagline: 'Mago',
        description: 'Poder arcano',
        isTaken: true,
        takenByUserId: 'user-1',
        takenByUsername: 'PlayerOne',
      );

      final vacantRole = occupiedRole.toVacant();

      expect(vacantRole.id, 'char-101');
      expect(vacantRole.name, 'Kitsune Shinobi');
      // La avatarUrl DEBE conservarse intacta
      expect(vacantRole.avatarUrl, 'https://kyubi.app/cdn/edited_avatar.png');
      expect(vacantRole.colorHex, '#00E5FF');
      expect(vacantRole.tagline, 'Mago');
      // La ocupación DEBE ser liberada
      expect(vacantRole.isTaken, false);
      expect(vacantRole.takenByUserId, isNull);
      expect(vacantRole.takenByUsername, isNull);
    });
  });

  group('4. Selector de Personajes (RoleLibraryScreen.showPicker)', () {
    const testUser = User(
      id: 'user-1',
      username: 'fox',
      displayName: 'Fox',
    );

    testWidgets('RoleLibraryScreen muestra fichas y retorna RoleCharacter al seleccionar', (tester) async {
      final fakeApi = _FakeApiClient();
      final repo = CharacterRepository(fakeApi);

      RoleCharacter? selectedRole;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(() => _FakeAuthNotifier(testUser)),
            characterRepositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  selectedRole = await RoleLibraryScreen.showPicker(context);
                },
                child: const Text('Abrir Picker'),
              ),
            ),
          ),
        ),
      );

      // Tocar el botón para abrir el picker
      await tester.tap(find.text('Abrir Picker'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Debe mostrar el título del picker
      expect(find.text('Seleccionar Personaje'), findsOneWidget);

      // Debe mostrar el personaje cargado desde /characters/mine
      expect(find.text('Kitsune Shinobi'), findsOneWidget);

      // Tocar la tarjeta del personaje
      await tester.tap(find.text('Kitsune Shinobi'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // El bottom sheet se cerró y devolvió la ficha
      expect(selectedRole, isNotNull);
      expect(selectedRole?.id, 'char-101');
      expect(selectedRole?.name, 'Kitsune Shinobi');
      expect(selectedRole?.avatarUrl, 'https://kyubi.app/cdn/shinobi.png');
      expect(selectedRole?.colorHex, '#FF0055');
    });
  });
}
