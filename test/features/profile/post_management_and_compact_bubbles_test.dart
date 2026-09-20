import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyubi/features/messages/presentation/widgets/chat_bubble.dart';
import 'package:kyubi/features/profile/presentation/user_posts_controller.dart';
import 'package:kyubi/features/salas/presentation/widgets/role_chat_bubble.dart';
import 'package:kyubi/models/post.dart';
import 'package:kyubi/models/post_author.dart';
import 'package:kyubi/models/reaction.dart';
import 'package:kyubi/repositories/post_repository.dart';
import 'package:kyubi/services/providers.dart';

class _FakePostRepository implements PostRepository {
  _FakePostRepository({this.shouldFailDelete = false});

  final bool shouldFailDelete;
  int deleteCalls = 0;
  String? lastDeletedId;

  @override
  Future<FeedPage> getUserPosts({
    required String usernameOrId,
    int limit = 30,
    String? cursor,
  }) async {
    return FeedPage(
      posts: [
        _samplePost('p1', 'Post 1'),
        _samplePost('p2', 'Post 2'),
        _samplePost('p3', 'Post 3'),
      ],
      nextCursor: null,
    );
  }

  @override
  Future<void> deletePost(String id) async {
    deleteCalls++;
    lastDeletedId = id;
    if (shouldFailDelete) {
      throw Exception('Network failure');
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Post _samplePost(String id, String body, {String visibility = 'PUBLIC'}) => Post(
  id: id,
  type: 'TEXT',
  title: '',
  body: body,
  visibility: visibility,
  author: const PostAuthor(
    id: 'user-1',
    username: 'tester',
    displayName: 'Tester',
  ),
  reactions: const ReactionCounts(
    like: 0,
    love: 0,
    laugh: 0,
    wow: 0,
    sad: 0,
    angry: 0,
  ),
  stats: const PostStats(views: 0, shares: 0, comments: 0),
  isLiked: false,
  timeAgo: 'ahora',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UserPostsNotifier - Optimistic Operations', () {
    test('removePost elimina inmediatamente el post local', () async {
      final fakeRepo = _FakePostRepository();
      final container = ProviderContainer(
        overrides: [
          postRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(userPostsProvider('user-1').notifier);
      await pumpEventQueue();

      expect(container.read(userPostsProvider('user-1')).posts.length, 3);

      notifier.removePost('p2');
      final posts = container.read(userPostsProvider('user-1')).posts;
      expect(posts.length, 2);
      expect(posts.any((p) => p.id == 'p2'), isFalse);
    });

    test('updatePost actualiza el contenido y visibilidad de un post local', () async {
      final fakeRepo = _FakePostRepository();
      final container = ProviderContainer(
        overrides: [
          postRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(userPostsProvider('user-1').notifier);
      await pumpEventQueue();

      final updated = _samplePost('p1', 'Contenido modificado', visibility: 'PRIVATE');
      notifier.updatePost(updated);

      final post = container.read(userPostsProvider('user-1')).posts.firstWhere((p) => p.id == 'p1');
      expect(post.body, 'Contenido modificado');
      expect(post.visibility, 'PRIVATE');
      expect(post.isPrivate, isTrue);
    });

    test('deletePost elimina optimista y llama a deletePost en repo', () async {
      final fakeRepo = _FakePostRepository();
      final container = ProviderContainer(
        overrides: [
          postRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(userPostsProvider('user-1').notifier);
      await pumpEventQueue();

      final success = await notifier.deletePost('p3');
      expect(success, isTrue);
      expect(fakeRepo.deleteCalls, 1);
      expect(fakeRepo.lastDeletedId, 'p3');

      final posts = container.read(userPostsProvider('user-1')).posts;
      expect(posts.length, 2);
      expect(posts.any((p) => p.id == 'p3'), isFalse);
    });

    test('deletePost revierte el estado si el repo arroja error', () async {
      final fakeRepo = _FakePostRepository(shouldFailDelete: true);
      final container = ProviderContainer(
        overrides: [
          postRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(userPostsProvider('user-1').notifier);
      await pumpEventQueue();

      final success = await notifier.deletePost('p2');
      expect(success, isFalse);
      expect(fakeRepo.deleteCalls, 1);

      // Revertido
      final posts = container.read(userPostsProvider('user-1')).posts;
      expect(posts.length, 3);
      expect(posts.any((p) => p.id == 'p2'), isTrue);
    });
  });

  group('Compactación de Burbujas', () {
    testWidgets('DirectChatMessageBubble usa padding compacto', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DirectChatMessageBubble(
              body: 'si',
              timestamp: '12:00',
              isMine: true,
            ),
          ),
        ),
      );

      final paddingWidgets = tester.widgetList<Padding>(find.byType(Padding)).toList();
      // Outer alignment padding is 2.5 vertical
      final hasCompactOuter = paddingWidgets.any(
        (p) => p.padding == const EdgeInsets.symmetric(vertical: 2.5),
      );
      expect(hasCompactOuter, isTrue);

      // Container padding is 12 horizontal, 6 vertical
      final containerFinder = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.padding == const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      );
      expect(containerFinder, findsOneWidget);
    });

    testWidgets('RoleChatBubble usa padding compacto', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RoleChatBubble(
              body: 'si',
              senderName: 'KyubiUser',
              isMine: false,
              timestamp: '12:00',
              messageType: 'message',
            ),
          ),
        ),
      );

      // Outer row padding is 14 horizontal, 3.5 vertical
      final paddingWidgets = tester.widgetList<Padding>(find.byType(Padding)).toList();
      final hasCompactOuter = paddingWidgets.any(
        (p) => p.padding == const EdgeInsets.symmetric(horizontal: 14, vertical: 3.5),
      );
      expect(hasCompactOuter, isTrue);

      // Inner text bubble container padding is 12 horizontal, 6 vertical
      final containerFinder = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.padding == const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      );
      expect(containerFinder, findsOneWidget);
    });
  });
}
