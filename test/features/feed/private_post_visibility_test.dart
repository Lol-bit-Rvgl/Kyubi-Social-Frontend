import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyubi/features/feed/presentation/widgets/post_card.dart';
import 'package:kyubi/features/saved/presentation/bookmarks_controller.dart';
import 'package:kyubi/models/post.dart';
import 'package:kyubi/models/post_author.dart';
import 'package:kyubi/models/reaction.dart';

class _FakeBookmarksNotifier extends BookmarksNotifier {
  @override
  BookmarksState build() => const BookmarksState();
}

/// Post de prueba con visibilidad configurable.
Post buildPost({String visibility = 'PUBLIC'}) => Post(
  id: 'post-1',
  type: 'TEXT',
  title: '',
  body: 'Contenido de prueba',
  visibility: visibility,
  author: const PostAuthor(
    id: 'u1',
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

Map<String, dynamic> postJson({String? visibility}) => {
  'id': 'post-1',
  'type': 'TEXT',
  'title': '',
  'body': 'Contenido de prueba',
  'visibility': ?visibility,
  'author': {'id': 'u1', 'username': 'tester', 'displayName': 'Tester'},
  'reactions': {
    'like': 0,
    'love': 0,
    'laugh': 0,
    'wow': 0,
    'sad': 0,
    'angry': 0,
  },
  'stats': {'views': 0, 'shares': 0, 'comments': 0},
  'isLiked': false,
  'timeAgo': 'ahora',
};

void main() {
  group('Post.visibility — modelo', () {
    test('isPrivate solo es true con visibility PRIVATE', () {
      expect(buildPost(visibility: 'PRIVATE').isPrivate, isTrue);
      expect(buildPost(visibility: 'PUBLIC').isPrivate, isFalse);
      expect(buildPost(visibility: 'FOLLOWERS').isPrivate, isFalse);
      expect(buildPost(visibility: 'CIRCLE').isPrivate, isFalse);
    });

    test('fromJson sin visibility cae en PUBLIC (compatibilidad)', () {
      final post = Post.fromJson(postJson());
      expect(post.visibility, 'PUBLIC');
      expect(post.isPrivate, isFalse);
    });

    test('fromJson respeta visibility PRIVATE del backend', () {
      final post = Post.fromJson(postJson(visibility: 'PRIVATE'));
      expect(post.visibility, 'PRIVATE');
      expect(post.isPrivate, isTrue);
    });
  });

  group('PostCard — insignia de privacidad', () {
    Future<void> pumpCard(WidgetTester tester, Post post) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bookmarksControllerProvider.overrideWith(
              _FakeBookmarksNotifier.new,
            ),
          ],
          child: MaterialApp(home: Scaffold(body: PostCard(post: post))),
        ),
      );
      await tester.pump();
    }

    testWidgets('Muestra el candado con tooltip en posts privados', (
      tester,
    ) async {
      await pumpCard(tester, buildPost(visibility: 'PRIVATE'));

      expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
      expect(find.byTooltip('Visible solo para ti'), findsOneWidget);
    });

    testWidgets('No muestra candado en posts públicos', (tester) async {
      await pumpCard(tester, buildPost(visibility: 'PUBLIC'));

      expect(find.byIcon(Icons.lock_rounded), findsNothing);
    });
  });
}