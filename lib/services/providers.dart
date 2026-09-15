import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_client.dart';
import '../repositories/auth_repository.dart';
import '../repositories/bookmarks_repository.dart';
import '../repositories/chat_repository.dart';
import '../repositories/circle_repository.dart';
import '../repositories/follow_requests_repository.dart';
import '../repositories/notification_repository.dart';
import '../repositories/post_repository.dart';
import '../repositories/role_slots_repository.dart';
import '../repositories/room_repository.dart';
import '../repositories/search_repository.dart';
import '../repositories/story_repository.dart';
import '../repositories/upload_repository.dart';
import '../repositories/user_repository.dart';
import '../repositories/voice_repository.dart';
import '../repositories/wall_repository.dart';
import 'chat_socket.dart';
import 'notification_socket.dart';
import 'room_socket.dart';

/// Inyección de dependencias globales.
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient.instance);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(apiClientProvider)),
);

final userRepositoryProvider = Provider<UserRepository>(
  (ref) => UserRepository(ref.watch(apiClientProvider)),
);

final postRepositoryProvider = Provider<PostRepository>(
  (ref) => PostRepository(ref.watch(apiClientProvider)),
);

final roleSlotsRepositoryProvider = Provider<RoleSlotsRepository>(
  (ref) => RoleSlotsRepository(ref.watch(apiClientProvider)),
);

final bookmarksRepositoryProvider = Provider<BookmarksRepository>(
  (ref) => BookmarksRepository(ref.watch(apiClientProvider)),
);

final followRequestsRepositoryProvider = Provider<FollowRequestsRepository>(
  (ref) => FollowRequestsRepository(ref.watch(apiClientProvider)),
);

final wallRepositoryProvider = Provider<WallRepository>(
  (ref) => WallRepository(ref.watch(apiClientProvider)),
);

final uploadRepositoryProvider = Provider<UploadRepository>(
  (ref) => UploadRepository(ref.watch(apiClientProvider)),
);

final searchRepositoryProvider = Provider<SearchRepository>(
  (ref) => SearchRepository(ref.watch(apiClientProvider)),
);

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => ChatRepository(ref.watch(apiClientProvider)),
);

final chatSocketProvider = Provider<ChatSocketService>(
  (ref) {
    final socket = ChatSocketService.instance;
    // Al descartarse el ProviderScope (restart/logout/cambio de cuenta) se
    // desconecta el socket. `disconnect()` conserva el StreamController (bus)
    // para el siguiente login, evitando sockets huérfanos o listeners dobles.
    ref.onDispose(() => socket.disconnect());
    return socket;
  },
);

final roomSocketProvider = Provider<RoomSocketService>(
  (ref) {
    final socket = RoomSocketService.instance;
    ref.onDispose(() => socket.disconnect());
    return socket;
  },
);

final notificationSocketProvider = Provider<NotificationSocketService>(
  (ref) {
    final socket = NotificationSocketService.instance;
    ref.onDispose(() => socket.disconnect());
    return socket;
  },
);

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepository(ref.watch(apiClientProvider)),
);

final circleRepositoryProvider = Provider<CircleRepository>(
  (ref) => CircleRepository(ref.watch(apiClientProvider)),
);

final roomRepositoryProvider = Provider<RoomRepository>(
  (ref) => RoomRepository(ref.watch(apiClientProvider)),
);

final storyRepositoryProvider = Provider<StoryRepository>(
  (ref) => StoryRepository(ref.watch(apiClientProvider)),
);

final voiceRepositoryProvider = Provider<VoiceRepository>(
  (ref) => VoiceRepository(ref.watch(apiClientProvider)),
);

/// Conteo de notificaciones sin leer para la campana. Se refresca al entrar
/// a la pantalla de actividad o al navegar dentro de la app.
final unreadCountProvider = NotifierProvider<UnreadCountNotifier, int>(
  UnreadCountNotifier.new,
);

class UnreadCountNotifier extends Notifier<int> {
  NotificationRepository get _repo => ref.read(notificationRepositoryProvider);

  bool _disposed = false;

  @override
  int build() {
    ref.onDispose(() => _disposed = true);
    Future.microtask(_load);
    return 0;
  }

  Future<void> _load() async {
    if (_disposed) return;
    try {
      final page = await _repo.getNotifications(page: 1, limit: 1);
      if (_disposed) return;
      state = page.unread;
    } catch (_) {
      // Sin red no mostramos badge; el resto de la app gestiona el error.
    }
  }

  Future<void> refresh() => _load();

  void clear() => state = 0;

  void increment() => state++;
}
