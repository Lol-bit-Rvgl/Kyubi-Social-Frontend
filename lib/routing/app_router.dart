import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/stories/presentation/story_controller.dart';
import '../features/auth/presentation/forgot_password/forgot_password_screen.dart';
import '../features/auth/presentation/login/login_screen.dart';
import '../features/auth/presentation/onboarding/onboarding_screen.dart';
import '../features/auth/presentation/register/register_screen.dart';
import '../features/auth/presentation/reset_password/reset_password_screen.dart';
import '../features/auth/presentation/splash/splash_screen.dart';
import '../features/auth/presentation/verify_email/verify_email_screen.dart';
import '../features/feed/presentation/feed_screen.dart';
import '../features/friends/presentation/friends_list_screen.dart';
import '../features/home/presentation/home_shell.dart';
import '../features/messages/presentation/chat_directo_screen.dart';
import '../features/messages/presentation/conversation_screen.dart';
import '../features/messages/presentation/messages_screen.dart';
import '../features/notifications/presentation/notifications_screen.dart';
import '../features/profile/presentation/edit_profile_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/profile/presentation/user_bio_screen.dart';
import '../features/profile/presentation/user_wall_detail_screen.dart';
import '../features/profile/presentation/visit_profile_screen.dart';
import '../features/profile/presentation/user_connections_screen.dart';
import '../features/profile/presentation/visitor_list_screen.dart';
import '../features/search/presentation/search_screen.dart';
import '../features/create_post/presentation/create_post_screen.dart';
import '../features/circles/presentation/circle_detail_screen.dart';
import '../features/circles/presentation/circles_screen.dart';
import '../features/circles/presentation/create_circle_post_screen.dart';
import '../features/circles/presentation/create_circle_screen.dart';
import '../models/role_character.dart';
import '../models/story.dart';
import '../models/user.dart';
import '../features/roles/presentation/role_detail_screen.dart';
import '../features/roles/presentation/role_editor_screen.dart';
import '../features/roles/presentation/role_library_screen.dart';
import '../features/roles/presentation/role_slot_detail_screen.dart';
import '../features/roles/presentation/role_slot_editor_screen.dart';
import '../models/role_slot.dart';
import '../features/salas/presentation/create_sala_screen.dart';
import '../features/salas/presentation/sala_detail_screen.dart';
import '../features/salas/presentation/salas_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/settings/presentation/legal_screen.dart';
import '../features/store/presentation/store_screen.dart';
import '../features/stories/presentation/create_story_screen.dart';
import '../features/stories/presentation/story_viewer_screen.dart';
import '../features/saved/presentation/saved_screen.dart';
import '../features/post_detail/presentation/post_detail_screen.dart';
import '../features/moderation/presentation/report_post_screen.dart';
import '../features/matchmaking/presentation/matchmaking_screen.dart';
import '../services/auth_controller.dart';
import '../core/services/notification_service.dart';
import 'router_refresh.dart';

/// Define las rutas de la aplicación y su protección.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ref.watch(routerRefreshProvider);

  final router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final status = auth.status;
      final location = state.matchedLocation;

      // Rutas públicas (auth y onboarding).
      const publicPaths = [
        '/splash',
        '/login',
        '/register',
        '/forgot-password',
        '/reset-password',
        '/verify-email',
        '/onboarding',
      ];

      if (status == AuthStatus.unknown) {
        if (location != '/splash') return '/splash';
        return null;
      }

      final isPublic = publicPaths.any(location.startsWith);
      if (!auth.isAuthenticated) {
        if (isPublic && location != '/onboarding') return null;
        return '/login';
      }

      // Usuario autenticado que aún no completó onboarding.
      if (!(auth.user?.onboardingCompleted ?? false)) {
        if (location == '/onboarding') return null;
        return '/onboarding';
      }

      if (isPublic) return '/app/feed';

      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
      GoRoute(
        path: '/forgot-password',
        builder: (_, _) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (_, state) => ResetPasswordScreen(
          token: state.uri.queryParameters['token'],
          email: state.uri.queryParameters['email'],
        ),
      ),
      GoRoute(
        path: '/verify-email',
        builder: (_, state) =>
            VerifyEmailScreen(token: state.uri.queryParameters['token'] ?? ''),
      ),
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
      // ---------------------------------------------------------------------
      // Zona autenticada: shell con pestañas.
      // ---------------------------------------------------------------------
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            HomeShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/app/feed', builder: (_, _) => const FeedScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/app/circles',
                builder: (_, _) => const CirclesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/app/messages',
                builder: (_, _) => const MessagesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/app/profile',
                builder: (_, _) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      // ---------------------------------------------------------------------
      // Pantallas protegidas fuera del shell (stack de navegación).
      // ---------------------------------------------------------------------
      GoRoute(path: '/search', builder: (_, _) => const SearchScreen()),
      GoRoute(path: '/app/search', redirect: (_, _) => '/search'),
      GoRoute(
        path: '/app/notifications',
        builder: (_, _) => const NotificationsScreen(),
      ),
      GoRoute(path: '/friends', builder: (_, _) => const FriendsListScreen()),
      GoRoute(path: '/app/friends', redirect: (_, _) => '/friends'),
      GoRoute(
        path: '/create-post',
        builder: (_, _) => const CreatePostScreen(),
      ),
      GoRoute(path: '/circles', builder: (_, _) => const CirclesScreen()),
      GoRoute(path: '/circles/mine', redirect: (_, _) => '/circles'),
      GoRoute(
        path: '/circles/create',
        builder: (_, _) => const CreateCircleScreen(),
      ),
      GoRoute(
        path: '/circles/:circleId',
        builder: (_, state) =>
            CircleDetailScreen(circleId: state.pathParameters['circleId']!),
      ),
      GoRoute(
        path: '/circles/:circleId/create-post',
        builder: (_, state) =>
            CreateCirclePostScreen(circleId: state.pathParameters['circleId']!),
      ),
      GoRoute(path: '/salas', builder: (_, _) => const SalasScreen()),
      GoRoute(
        path: '/salas/create',
        builder: (_, state) {
          final isPrivate = state.uri.queryParameters['private'] == 'true' ||
              state.extra == true ||
              (state.extra is Map && (state.extra as Map)['private'] == true) ||
              (state.extra is Map && (state.extra as Map)['isPrivate'] == true);
          return CreateSalaScreen(isPrivateInitial: isPrivate);
        },
      ),
      GoRoute(
        path: '/salas/create/:circleId',
        builder: (_, state) {
          final isPrivate = state.uri.queryParameters['private'] == 'true' ||
              state.extra == true ||
              (state.extra is Map && (state.extra as Map)['private'] == true) ||
              (state.extra is Map && (state.extra as Map)['isPrivate'] == true);
          return CreateSalaScreen(
            circleId: state.pathParameters['circleId'],
            isPrivateInitial: isPrivate,
          );
        },
      ),
      GoRoute(
        path: '/salas/:salaId',
        builder: (_, state) => SalaDetailScreen(
          roomId: state.pathParameters['salaId']!,
          forceConnected: state.extra == true,
        ),
      ),
      GoRoute(path: '/roles/create', redirect: (_, _) => '/characters/create'),
      GoRoute(
        path: '/roles/library',
        builder: (_, _) => const RoleLibraryScreen(),
      ),
      GoRoute(
        path: '/characters/library',
        redirect: (_, _) => '/roles/library',
      ),
      GoRoute(
        path: '/characters/create',
        builder: (_, state) => RoleEditorScreen(
          initialRole: state.extra is RoleCharacter
              ? state.extra as RoleCharacter
              : null,
        ),
      ),
      GoRoute(
        path: '/characters/:id',
        builder: (_, state) =>
            RoleDetailScreen(roleId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/role-slots/editor/:postId',
        builder: (context, state) {
          final postId = state.pathParameters['postId'];
          if (postId == null || postId.isEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) context.go('/main');
            });
            return const Scaffold(
              backgroundColor: Color(0xFF0D0B14),
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final targetSlotId = state.uri.queryParameters['slotId'] ??
              state.uri.queryParameters['targetSlotId'];
          return RoleSlotEditorScreen(
            postId: postId,
            slot: state.extra is RoleSlot ? state.extra as RoleSlot : null,
            targetSlotId: targetSlotId,
          );
        },
      ),
      GoRoute(
        path: '/role-slots/:slotId',
        builder: (context, state) {
          final slot = state.extra is RoleSlot ? state.extra as RoleSlot : null;
          if (slot == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) context.go('/main');
            });
            return const Scaffold(
              backgroundColor: Color(0xFF0D0B14),
              body: Center(
                child: Text(
                  'Vacante no disponible',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            );
          }
          return RoleSlotDetailScreen(
            slot: slot,
            isPostAuthor: state.uri.queryParameters['author'] == '1',
          );
        },
      ),
      GoRoute(
        path: '/post/:id',
        builder: (_, state) =>
            PostDetailScreen(postId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/conversation/:id',
        builder: (_, state) =>
            ConversationScreen(conversationId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/dm/:id',
        builder: (_, state) =>
            ChatDirectoScreen(conversationId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/report-post/:id',
        builder: (_, state) =>
            ReportPostScreen(postId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      GoRoute(path: '/legal', builder: (_, _) => const LegalScreen()),
      GoRoute(path: '/store', builder: (_, _) => const StoreScreen()),
      GoRoute(path: '/saved', builder: (_, _) => const SavedScreen()),
      GoRoute(
        path: '/edit-profile',
        builder: (_, _) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/profile-bio',
        builder: (context, state) {
          final user = state.extra is User
              ? state.extra as User
              : ref.read(authControllerProvider).user;
          if (user == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) context.go('/main');
            });
            return const Scaffold(
              backgroundColor: Color(0xFF0D0B14),
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return UserBioScreen(user: user, isOwnProfile: true);
        },
      ),
      GoRoute(
        path: '/profile/wall',
        builder: (_, state) {
          final user = state.extra is User
              ? state.extra as User
              : ref.read(authControllerProvider).user;
          return UserWallDetailScreen(
            username: user?.username ?? '',
            userId: user?.id ?? '',
          );
        },
      ),
      GoRoute(
        path: '/profile/:username/bio',
        builder: (context, state) {
          final username = state.pathParameters['username'] ?? '';
          final extraUser = state.extra is User ? state.extra as User : null;
          final authUser = ref.read(authControllerProvider).user;
          final isOwn = authUser != null &&
              (authUser.username.toLowerCase() == username.toLowerCase() ||
               authUser.id == username ||
               (extraUser != null && authUser.id == extraUser.id));
          final user = extraUser ?? (isOwn ? authUser : null);

          if (user != null) {
            return UserBioScreen(user: user, isOwnProfile: isOwn);
          }

          return UserBioScreen(
            username: username,
            isOwnProfile: isOwn,
          );
        },
      ),
      GoRoute(
        path: '/profile/:username',
        builder: (_, state) {
          final username = state.pathParameters['username']!;
          final authUser = ref.read(authControllerProvider).user;
          if (authUser != null &&
              (authUser.username.toLowerCase() == username.toLowerCase() ||
               authUser.id == username)) {
            return const ProfileScreen();
          }
          return VisitProfileScreen(username: username);
        },
      ),
      GoRoute(
        path: '/profile/:username/connections',
        builder: (_, state) {
          final tab = state.uri.queryParameters['tab'] ?? 'followers';
          return UserConnectionsScreen(
            username: state.pathParameters['username']!,
            initialTab: tab,
          );
        },
      ),
      GoRoute(
        path: '/profile/:username/followers',
        builder: (_, state) => UserConnectionsScreen(
          username: state.pathParameters['username']!,
          initialTab: 'followers',
        ),
      ),
      GoRoute(
        path: '/profile/:username/following',
        builder: (_, state) => UserConnectionsScreen(
          username: state.pathParameters['username']!,
          initialTab: 'following',
        ),
      ),
      GoRoute(
        path: '/profile/:username/visitors',
        builder: (_, state) =>
            VisitorListScreen(username: state.pathParameters['username']!),
      ),
      GoRoute(
        path: '/profile/:username/wall',
        builder: (_, state) {
          final username = state.pathParameters['username'] ?? '';
          final extraUser = state.extra is User ? state.extra as User : null;
          return UserWallDetailScreen(
            username: username,
            userId: extraUser?.id ?? username,
          );
        },
      ),
      GoRoute(
        path: '/wall/:username',
        redirect: (_, state) =>
            '/profile/${state.pathParameters['username']}/wall',
      ),
      GoRoute(
        path: '/create-story',
        builder: (_, _) => const CreateStoryScreen(),
      ),
      GoRoute(
        path: '/story-viewer',
        builder: (context, state) {
          final group =
              state.extra is StoryGroup ? state.extra as StoryGroup : null;
          if (group != null) {
            return StoryViewerScreen(group: group);
          }
          final userId = state.uri.queryParameters['userId'];
          if (userId != null && userId.isNotEmpty) {
            final storyState = ref.read(storyControllerProvider);
            final matched = storyState.groups.cast<StoryGroup?>().firstWhere(
              (g) => g?.author.id == userId,
              orElse: () => null,
            );
            if (matched != null) {
              return StoryViewerScreen(group: matched);
            }
          }
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.go('/main');
          });
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: Text(
                'Historia no disponible',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          );
        },
      ),
      GoRoute(
        path: '/matchmaking',
        builder: (_, _) => const MatchmakingScreen(),
      ),
    ],
  );

  // ── Navegación profunda desde notificaciones push (FCM) ──
  // Payload: { type: 'message'|'comment'|'mention'|'wall'|..., targetId }
  NotificationService.instance.onNotificationTap = (type, targetId) {
    if (targetId.isEmpty) return;
    switch (type) {
      case 'message':
        router.push('/conversation/$targetId');
      case 'comment':
      case 'mention':
      case 'reaction':
        router.push('/post/$targetId');
      case 'wall':
        router.push('/app/feed');
      default:
        break;
    }
  };

  return router;
});
