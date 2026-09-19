import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyubi/core/widgets/state_views.dart';
import 'package:kyubi/features/friends/presentation/friends_controller.dart';
import 'package:kyubi/features/friends/presentation/friends_list_screen.dart';
import 'package:kyubi/features/friends/presentation/friends_list_sheet.dart';
import 'package:kyubi/models/chat_conversation.dart';
import 'package:kyubi/models/user.dart';
import 'package:kyubi/repositories/chat_repository.dart';
import 'package:kyubi/repositories/user_repository.dart';
import 'package:kyubi/services/providers.dart';

/// Repositorio de usuarios simulado que solo implementa `getFriends`.
class _FakeUserRepository implements UserRepository {
  _FakeUserRepository({this.friends = const [], this.error});

  List<User> friends;
  Object? error;
  int calls = 0;

  @override
  Future<List<User>> getFriends() async {
    calls++;
    final failure = error;
    if (failure != null) throw failure;
    return friends;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Chat simulado que siempre falla al abrir la conversación directa.
class _FailingChatRepository implements ChatRepository {
  @override
  Future<Conversation> openOrCreateDirect(
    String userId, {
    String? username,
  }) async {
    throw Exception('sin conexión');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _friendA = User(
  id: 'friend-1',
  username: 'sakura_fox',
  displayName: 'Sakura Kitsune',
  bio: 'Amistad bilateral',
  level: 7,
  isOnline: true,
);

const _friendB = User(
  id: 'friend-2',
  username: 'ronin_wolf',
  displayName: 'Ronin Solitario',
  level: 3,
  isOnline: false,
);

List<Override> _overrides(_FakeUserRepository fake, {ChatRepository? chat}) => [
  userRepositoryProvider.overrideWithValue(fake),
  if (chat != null) chatRepositoryProvider.overrideWithValue(chat),
];

Widget _host(Widget child, {required List<Override> overrides}) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(home: Scaffold(body: child)),
);
void main() {
  group('FriendsNotifier (seguimiento mutuo bilateral)', () {
    test('carga la lista de amigos al construirse', () async {
      final fake = _FakeUserRepository(friends: const [_friendA, _friendB]);
      final container = ProviderContainer(
        overrides: _overrides(fake),
      );
      addTearDown(container.dispose);

      container.listen(friendsControllerProvider, (_, _) {}, fireImmediately: true);
      await pumpEventQueue();

      final state = container.read(friendsControllerProvider);
      expect(state.friends.map((f) => f.id).toList(), ['friend-1', 'friend-2']);
      expect(state.friends.first.handle, '@sakura_fox');
      expect(state.loading, isFalse);
      expect(state.error, isNull);
      expect(fake.calls, 1);
    });

    test('expone error y se recupera con refresh', () async {
      final fake = _FakeUserRepository(error: Exception('boom'));
      final container = ProviderContainer(
        overrides: _overrides(fake),
      );
      addTearDown(container.dispose);

      container.listen(friendsControllerProvider, (_, _) {}, fireImmediately: true);
      await pumpEventQueue();

      expect(container.read(friendsControllerProvider).error, isNotNull);
      expect(container.read(friendsControllerProvider).friends, isEmpty);

      // El backend vuelve a responder: el refresco limpia el error.
      fake.error = null;
      fake.friends = const [_friendA];
      await container.read(friendsControllerProvider.notifier).refresh();
      await pumpEventQueue();

      final state = container.read(friendsControllerProvider);
      expect(state.error, isNull);
      expect(state.refreshing, isFalse);
      expect(state.friends.single.id, 'friend-1');
      expect(fake.calls, 2);
    });

    test('estado vacío cuando no hay seguimiento recíproco', () async {
      final fake = _FakeUserRepository(friends: const []);
      final container = ProviderContainer(
        overrides: _overrides(fake),
      );
      addTearDown(container.dispose);

      container.listen(friendsControllerProvider, (_, _) {}, fireImmediately: true);
      await pumpEventQueue();

      final state = container.read(friendsControllerProvider);
      expect(state.friends, isEmpty);
      expect(state.isEmpty, isTrue);
      expect(state.error, isNull);
    });
  });
  group('FriendsListView / UI de amigos', () {
    testWidgets('renderiza nombre, @username y estado de conexión', (tester) async {
      final fake = _FakeUserRepository(friends: const [_friendA, _friendB]);

      await tester.pumpWidget(
        _host(const FriendsListView(), overrides: _overrides(fake)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sakura Kitsune'), findsOneWidget);
      expect(find.text('@sakura_fox'), findsOneWidget);
      expect(find.text('En línea'), findsOneWidget);

      expect(find.text('Ronin Solitario'), findsOneWidget);
      expect(find.text('@ronin_wolf'), findsOneWidget);
      expect(find.text('Desconectado'), findsOneWidget);

      // Cada fila ofrece la acción de abrir conversación.
      expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('al tocar un amigo se dispara onFriendTap con ese amigo', (tester) async {
      final fake = _FakeUserRepository(friends: const [_friendA, _friendB]);
      final tapped = <String>[];

      await tester.pumpWidget(
        _host(
          FriendsListView(onFriendTap: (user) => tapped.add(user.id)),
          overrides: _overrides(fake),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ronin Solitario'));
      await tester.pump();

      expect(tapped, ['friend-2']);
    });

    testWidgets('muestra el EmptyState cuando no hay amigos mutuos', (tester) async {
      final fake = _FakeUserRepository(friends: const []);

      await tester.pumpWidget(
        _host(const FriendsListView(), overrides: _overrides(fake)),
      );
      await tester.pumpAndSettle();

      expect(find.byType(EmptyView), findsOneWidget);
      expect(find.text('Aún no tienes amigos'), findsOneWidget);
      expect(
        find.text(
          'Sigue a personas que te sigan de vuelta para convertirlos en amigos.',
        ),
        findsOneWidget,
      );
      expect(find.text('Buscar personas'), findsOneWidget);
    });

    testWidgets('muestra ErrorView y reintenta la carga', (tester) async {
      final fake = _FakeUserRepository(error: Exception('boom'));

      await tester.pumpWidget(
        _host(const FriendsListView(), overrides: _overrides(fake)),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ErrorView), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);

      fake.error = null;
      fake.friends = const [_friendA];
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(find.byType(ErrorView), findsNothing);
      expect(find.text('Sakura Kitsune'), findsOneWidget);
    });

    testWidgets('sin onFriendTap, un fallo al abrir el chat muestra aviso', (tester) async {
      final fake = _FakeUserRepository(friends: const [_friendA]);

      await tester.pumpWidget(
        _host(
          const FriendsListView(),
          overrides: _overrides(fake, chat: _FailingChatRepository()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sakura Kitsune'));
      await tester.pumpAndSettle();

      expect(find.text('No se pudo abrir la conversación'), findsOneWidget);
    });
  });

  group('FriendsListSheet / FriendsListScreen', () {
    testWidgets('FriendsListSheet.show despliega la hoja con la lista', (tester) async {
      final fake = _FakeUserRepository(friends: const [_friendA]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: _overrides(fake),
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => FriendsListSheet.show(context),
                  child: const Text('Abrir amigos'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir amigos'));
      await tester.pumpAndSettle();

      expect(find.byType(FriendsListSheet), findsOneWidget);
      expect(find.text('Amigos'), findsOneWidget);
      expect(find.text('1 amigo con seguimiento mutuo'), findsOneWidget);
      expect(find.text('Sakura Kitsune'), findsOneWidget);
    });

    testWidgets('FriendsListScreen renderiza AppBar y lista', (tester) async {
      final fake = _FakeUserRepository(friends: const [_friendA, _friendB]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: _overrides(fake),
          child: const MaterialApp(home: FriendsListScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Amigos'), findsOneWidget);
      expect(find.text('2 amigos con seguimiento mutuo'), findsOneWidget);
      expect(find.text('Sakura Kitsune'), findsOneWidget);
      expect(find.text('Ronin Solitario'), findsOneWidget);
    });
  });
}

