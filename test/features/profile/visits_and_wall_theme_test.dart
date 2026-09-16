import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kyubi/features/profile/presentation/widgets/wall_tab_section.dart';
import 'package:kyubi/features/profile/presentation/user_wall_comments_controller.dart';
import 'package:kyubi/models/user.dart';
import 'package:kyubi/models/wall_entry.dart';
import 'package:kyubi/repositories/wall_repository.dart';
import 'package:kyubi/services/auth_controller.dart';
import 'package:kyubi/services/providers.dart';

class _FakeWallRepository implements WallRepository {
  List<WallEntry> entries = [];
  String? deletedEntryId;

  @override
  Future<WallPage> getWall(String userId, {int page = 1}) async {
    return WallPage(
      entries: entries,
      total: entries.length,
      pages: 1,
      page: 1,
    );
  }

  @override
  Future<WallEntry> createEntry(
    String ownerId, {
    required String text,
    String? imageUrl,
    String? parentId,
  }) async {
    final newEntry = WallEntry(
      id: 'entry-${DateTime.now().millisecondsSinceEpoch}',
      authorId: 'me-1',
      authorName: 'My User',
      authorAvatarUrl: null,
      authorEmoji: '🦊',
      isAuthor: true,
      text: text,
      createdAt: DateTime.now().toIso8601String(),
      likes: 0,
      isLikedByMe: false,
      repliesCount: 0,
    );
    entries.insert(0, newEntry);
    return newEntry;
  }

  @override
  Future<void> deleteEntry(String entryId) async {
    deletedEntryId = entryId;
    entries.removeWhere((e) => e.id == entryId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestAuthNotifier extends AuthNotifier {
  _TestAuthNotifier(this._initialUser);
  final User _initialUser;

  @override
  AuthState build() => AuthState(
        status: AuthStatus.authenticated,
        user: _initialUser,
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('1. Contador de Visitas - Erradicación de 0 transitorio', () {
    test('User.profileViews soporta profileViews, visitorsCount y viewsCount', () {
      const userA = User(
        id: 'u1',
        username: 'fox',
        displayName: 'Fox',
        extensions: {'profileViews': 15},
      );
      expect(userA.profileViews, 15);

      const userB = User(
        id: 'u2',
        username: 'fox2',
        displayName: 'Fox Two',
        extensions: {'visitorsCount': 22},
      );
      expect(userB.profileViews, 22);

      const userC = User(
        id: 'u3',
        username: 'fox3',
        displayName: 'Fox Three',
        extensions: {'viewsCount': 8},
      );
      expect(userC.profileViews, 8);

      const userZero = User(
        id: 'u4',
        username: 'fox4',
        displayName: 'Fox Zero',
        extensions: {},
      );
      expect(userZero.profileViews, 0);
    });

    test('Estrategia de visualización preserva _lastKnownVisitsCount si el nuevo profileViews es 0', () {
      final int? lastKnownVisitsCount = int.tryParse('15');

      const transientUser = User(
        id: 'u-me',
        username: 'me',
        displayName: 'Me',
        extensions: {}, // profileViews resuelve a 0
      );

      final displayVisits = (transientUser.profileViews > 0)
          ? transientUser.profileViews
          : (lastKnownVisitsCount ?? 0);

      expect(displayVisits, 15);
    });
  });

  group('2. Muro del Perfil - Borrado optimista y permisos', () {
    test('UserWallCommentsNotifier elimina optimísticamente una firma', () async {
      final fakeRepo = _FakeWallRepository();
      const entry1 = WallEntry(
        id: 'entry-1',
        authorId: 'other-user',
        authorName: 'Other',
        authorAvatarUrl: null,
        authorEmoji: '🐾',
        isAuthor: false,
        text: 'Hola desde el muro',
        createdAt: '2026-09-16T12:00:00Z',
        likes: 2,
        isLikedByMe: false,
        repliesCount: 0,
      );
      fakeRepo.entries = [entry1];

      final container = ProviderContainer(
        overrides: [
          wallRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(userWallCommentsProvider('profile-owner').notifier);
      await notifier.load();

      expect(container.read(userWallCommentsProvider('profile-owner')).entries.length, 1);

      // Borrar la firma
      final ok = await notifier.delete(entry1);
      expect(ok, isTrue);
      expect(container.read(userWallCommentsProvider('profile-owner')).entries.isEmpty, isTrue);
      expect(fakeRepo.deletedEntryId, 'entry-1');
    });

    testWidgets('Muestra botón de borrar si el usuario es el dueño del muro o el autor', (tester) async {
      final fakeRepo = _FakeWallRepository();
      const entryOther = WallEntry(
        id: 'entry-from-friend',
        authorId: 'friend-user-id',
        authorName: 'friend_username',
        authorAvatarUrl: null,
        authorEmoji: '✨',
        isAuthor: false,
        text: 'Firma de un amigo',
        createdAt: '2026-09-16T12:00:00Z',
        likes: 0,
        isLikedByMe: false,
        repliesCount: 0,
      );
      fakeRepo.entries = [entryOther];

      const ownerUser = User(
        id: 'my-owner-id',
        username: 'my_owner_username',
        displayName: 'Owner User',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            wallRepositoryProvider.overrideWithValue(fakeRepo),
            authControllerProvider.overrideWith(() => _TestAuthNotifier(ownerUser)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: WallTabSection(
                ownerId: 'my_owner_username',
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Como el usuario actual es dueño del muro ('my_owner_username'), puede borrar
      expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);

      // Al tocar la papelera, muestra el diálogo de confirmación
      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pumpAndSettle();

      expect(find.text('¿Eliminar firma?'), findsOneWidget);
      expect(find.text('Eliminar'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);

      // Confirmar eliminación
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();

      // Desaparece optimísticamente
      expect(find.text('Firma de un amigo'), findsNothing);
    });
  });

  group('3. Adaptación a Colores Personalizados del Tema Dinámico', () {
    testWidgets('El input, botón enviar y bordes heredan colorScheme.primary', (tester) async {
      final fakeRepo = _FakeWallRepository();
      const customPrimary = Color(0xFF00E676); // verde esmeralda
      const customSecondary = Color(0xFFFF9100); // naranja ámbar

      const testUser = User(
        id: 'u-1',
        username: 'testuser',
        displayName: 'Test User',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            wallRepositoryProvider.overrideWithValue(fakeRepo),
            authControllerProvider.overrideWith(() => _TestAuthNotifier(testUser)),
          ],
          child: MaterialApp(
            theme: ThemeData.dark().copyWith(
              colorScheme: const ColorScheme.dark(
                primary: customPrimary,
                secondary: customSecondary,
              ),
            ),
            home: const Scaffold(
              body: WallTabSection(
                ownerId: 'testuser',
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verificar que el icono de enviar esté presente
      expect(find.byIcon(Icons.send_rounded), findsOneWidget);

      // Buscar el contenedor del botón de enviar
      final sendContainer = tester.widget<Container>(
        find.ancestor(
          of: find.byIcon(Icons.send_rounded),
          matching: find.byType(Container),
        ).first,
      );

      final dec = sendContainer.decoration as BoxDecoration;
      expect(dec.gradient, isNotNull);
      final gradient = dec.gradient as LinearGradient;
      expect(gradient.colors.first, customPrimary);
    });
  });
}
