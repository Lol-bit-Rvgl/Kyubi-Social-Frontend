import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kyubi/core/config/app_config.dart';
import 'package:kyubi/core/storage/session_store.dart';
import 'package:kyubi/core/widgets/chat_bubble.dart';
import 'package:kyubi/features/feed/presentation/feed_controller.dart';
import 'package:kyubi/models/chat_message.dart';
import 'package:kyubi/models/post.dart';
import 'package:kyubi/models/room.dart';
import 'package:kyubi/repositories/post_repository.dart';
import 'package:kyubi/repositories/room_repository.dart';
import 'package:kyubi/services/providers.dart';

class _FakePostRepository implements PostRepository {
  _FakePostRepository({this.throwTimeout = false});

  final bool throwTimeout;

  @override
  Future<FeedPage> getFeed({
    String category = 'para_ti',
    bool followingOnly = false,
    int page = 1,
    int limit = 20,
    String? cursor,
  }) async {
    if (throwTimeout) {
      throw Exception('El servidor está iniciando, reintentando automáticamente... DioException [receive timeout]');
    }
    return const FeedPage(posts: []);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRoomRepository implements RoomRepository {
  @override
  Future<List<Room>> getSalas({
    int limit = 50,
    String? circleId,
    String? query,
    String? category,
  }) async {
    return [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('1. Ajuste de Timeouts para Cold Starts', () {
    test('AppConfig connectTimeout y receiveTimeout están configurados en 45 segundos', () {
      expect(AppConfig.connectTimeout, const Duration(seconds: 45));
      expect(AppConfig.receiveTimeout, const Duration(seconds: 45));
    });
  });

  group('2. FeedCache y Cache-First con Tolerancia a Cold Start', () {
    final mockPost = Post.fromJson(<String, dynamic>{
      'id': 'post-1',
      'type': 'TEXT',
      'title': 'Título',
      'body': 'Contenido del feed cacheado',
      'author': <String, dynamic>{'id': 'author-1', 'username': 'kyubi', 'displayName': 'Kyubi User'},
      'reactions': <String, dynamic>{},
      'stats': <String, dynamic>{},
      'isLiked': false,
    });

    test('FeedCache puede guardar, leer y limpiar posts', () async {
      await FeedCache.save([mockPost], category: 'para_ti');
      final cached = await FeedCache.read(category: 'para_ti');

      expect(cached, isNotEmpty);
      expect(cached.first['id'], 'post-1');
      expect(cached.first['body'], 'Contenido del feed cacheado');

      await FeedCache.clear(category: 'para_ti');
      final cleared = await FeedCache.read(category: 'para_ti');
      expect(cleared, isEmpty);
    });

    test('FeedState soporta isServerWakingUp flag sin perder posts cacheados', () {
      const state = FeedState(posts: [], isServerWakingUp: false);
      expect(state.isServerWakingUp, isFalse);

      final wakingUpState = state.copyWith(
        posts: [mockPost],
        isServerWakingUp: true,
      );
      expect(wakingUpState.isServerWakingUp, isTrue);
      expect(wakingUpState.posts.length, 1);
      expect(wakingUpState.posts.first.id, 'post-1');
    });

    test('FeedNotifier tolera cold start manteniendo posts cacheados e indicando isServerWakingUp', () async {
      // 1. Guardar post en caché previo
      await FeedCache.save([mockPost], category: 'para_ti');

      // 2. Montar provider con repositorio que falla por timeout (Render despertando)
      final fakePostRepo = _FakePostRepository(throwTimeout: true);
      final fakeRoomRepo = _FakeRoomRepository();

      final container = ProviderContainer(
        overrides: [
          postRepositoryProvider.overrideWithValue(fakePostRepo),
          roomRepositoryProvider.overrideWithValue(fakeRoomRepo),
        ],
      );
      addTearDown(container.dispose);

      // 3. Leer controller inicial
      final state = container.read(feedControllerProvider);
      expect(state.category, 'para_ti');

      // Esperar microtasks y llamadas asíncronas de caché y carga
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final finalState = container.read(feedControllerProvider);

      // Los posts cacheados se mantienen visibles
      expect(finalState.posts, isNotEmpty);
      expect(finalState.posts.first.id, 'post-1');
      // No debe sustituir toda la pantalla con error bloqueante
      expect(finalState.error, isNull);
      // isServerWakingUp debe estar activo para el banner informativo
      expect(finalState.isServerWakingUp, isTrue);
    });
  });

  group('3. Mensajería Directa Optimista e Indicador de Estado (Sending vs Sent)', () {
    test('Message computa status sending para temp- y local- IDs', () {
      final now = DateTime.now().toUtc();
      final tempMsg = Message(
        id: 'temp-1234567890',
        conversationId: 'c1',
        senderId: 'u1',
        sender: const ChatAuthor(id: 'u1', username: 'yo', displayName: 'Yo'),
        body: 'Hola optimista',
        createdAt: now,
      );
      expect(tempMsg.status, 'sending');
      expect(tempMsg.isSending, isTrue);

      final sentMsg = Message(
        id: 'msg-real-uuid',
        conversationId: 'c1',
        senderId: 'u1',
        sender: const ChatAuthor(id: 'u1', username: 'yo', displayName: 'Yo'),
        body: 'Hola optimista',
        createdAt: now,
        extensions: const {'status': 'sent'},
      );
      expect(sentMsg.status, 'sent');
      expect(sentMsg.isSending, isFalse);
    });

    testWidgets('DirectChatMessageBubble muestra icono de reloj (pending) cuando isSending es true', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DirectChatMessageBubble(
              body: 'Mensaje enviándose...',
              timestamp: '12:00',
              isMine: true,
              isSending: true,
            ),
          ),
        ),
      );

      // Icono de reloj en envío
      expect(find.byIcon(Icons.access_time_rounded), findsOneWidget);
      expect(find.byIcon(Icons.done_all_rounded), findsNothing);
    });

    testWidgets('DirectChatMessageBubble muestra doble check cian cuando isSending es false (confirmado)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DirectChatMessageBubble(
              body: 'Mensaje confirmado',
              timestamp: '12:01',
              isMine: true,
              isSending: false,
            ),
          ),
        ),
      );

      // Icono de doble check
      expect(find.byIcon(Icons.done_all_rounded), findsOneWidget);
      expect(find.byIcon(Icons.access_time_rounded), findsNothing);
    });
  });
}
