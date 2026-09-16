import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyubi/features/create_post/presentation/create_post_screen.dart';
import 'package:kyubi/models/circle.dart';
import 'package:kyubi/models/post.dart';
import 'package:kyubi/models/post_author.dart';
import 'package:kyubi/models/reaction.dart';
import 'package:kyubi/repositories/circle_repository.dart';
import 'package:kyubi/repositories/post_repository.dart';
import 'package:kyubi/services/providers.dart';

class _FakeCircleRepository implements CircleRepository {
  _FakeCircleRepository({this.circles = const []});

  final List<Circle> circles;

  @override
  Future<List<Circle>> getMyCircles({int limit = 30}) async => circles;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakePostRepository implements PostRepository {
  String? lastCircleId;
  String? lastVisibility;

  @override
  Future<Post> createPost({
    required String body,
    String? title,
    String type = 'TEXT',
    String visibility = 'PUBLIC',
    List<String>? mediaUrls,
    List<String>? tags,
    List<String>? genres,
    String? coverImageUrl,
    String? bgImageUrl,
    double? bgOverlay,
    bool? bgBlur,
    String? audioUrl,
    bool? chapterMode,
    int? chapterNumber,
    String? fontFamily,
    String? themeBgColor,
    String? themeAccent,
    bool? warnViolence,
    bool? warnAdult,
    bool? warnDark,
    bool? warnSpoiler,
    bool? allowComments,
    bool? allowReactions,
    String? circleId,
  }) async {
    lastCircleId = circleId;
    lastVisibility = visibility;
    return Post(
      id: 'post-123',
      type: type,
      title: title ?? '',
      body: body,
      author: const PostAuthor(id: 'u1', username: 'tester', displayName: 'Tester'),
      reactions: const ReactionCounts(like: 0, love: 0, laugh: 0, wow: 0, sad: 0, angry: 0),
      stats: const PostStats(views: 0, shares: 0, comments: 0),
      isLiked: false,
      timeAgo: 'ahora',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testCircle = Circle(
    id: 'circle-anime-1',
    name: 'Anime Lovers Club',
    creator: const PostAuthor(id: 'c1', username: 'owner', displayName: 'Owner'),
    isMember: true,
  );

  Widget buildCreatePostWidget({
    List<Circle> circles = const [],
    _FakePostRepository? postRepo,
  }) {
    return ProviderScope(
      overrides: [
        circleRepositoryProvider.overrideWithValue(_FakeCircleRepository(circles: circles)),
        if (postRepo != null) postRepositoryProvider.overrideWithValue(postRepo),
      ],
      child: const MaterialApp(
        home: CreatePostScreen(),
      ),
    );
  }

  group('CreatePostScreen - Selector de Circulos y Visibilidad', () {
    testWidgets('Por defecto con visibilidad Publica no muestra selector de circulos', (tester) async {
      await tester.pumpWidget(buildCreatePostWidget(circles: [testCircle]));
      await tester.pumpAndSettle();

      expect(find.text('Visibilidad'), findsOneWidget);
      expect(find.text('Público'), findsOneWidget);
      expect(find.text('Seleccionar Círculo'), findsNothing);
      expect(find.text('No perteneces a ningún círculo aún'), findsNothing);
    });

    testWidgets('Al cambiar a Circulo con circulos disponibles muestra dropdown y el circulo', (tester) async {
      await tester.pumpWidget(buildCreatePostWidget(circles: [testCircle]));
      await tester.pumpAndSettle();

      // Tap on visibility dropdown
      await tester.tap(find.text('Público'));
      await tester.pumpAndSettle();

      // Select 'Círculo'
      await tester.tap(find.text('Círculo').last);
      await tester.pumpAndSettle();

      expect(find.text('Seleccionar Círculo'), findsOneWidget);
      expect(find.text('Anime Lovers Club'), findsOneWidget);
    });

    testWidgets('Al cambiar a Circulo sin circulos muestra advertencia y boton de explorar', (tester) async {
      await tester.pumpWidget(buildCreatePostWidget(circles: const []));
      await tester.pumpAndSettle();

      // Tap on visibility dropdown
      await tester.tap(find.text('Público'));
      await tester.pumpAndSettle();

      // Select 'Círculo'
      await tester.tap(find.text('Círculo').last);
      await tester.pumpAndSettle();

      expect(find.text('No perteneces a ningún círculo aún'), findsOneWidget);
      expect(find.text('Explorar Círculos'), findsOneWidget);
    });
  });
}
