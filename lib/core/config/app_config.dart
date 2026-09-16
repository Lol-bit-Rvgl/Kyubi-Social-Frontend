import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Configuración central de la aplicación.
///
/// La URL base de la API se puede sobreescribir en build/run time con:
///   flutter run --dart-define=API_BASE_URL=http://localhost:3000
class AppConfig {
  AppConfig._();

  /// Valor explícito pasado por `--dart-define` ('' si no se definió).
  static const String _envApiBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// Origen del backend de producción (fallback cuando no hay override).
  static const String _prodApiBaseUrl =
      'https://kyubi-social-backend-1.onrender.com';

  /// true si se pasó `--dart-define=API_BASE_URL=...` explícitamente.
  static bool get hasExplicitApiBaseUrl => _envApiBaseUrl.isNotEmpty;

  /// Host de localhost desde el emulador de Android (loopback del host).
  static const String _androidEmulatorBaseUrl = 'http://10.0.2.2:3000';

  /// Heurística de emulador Android sin dependencias extra: los fingerprints
  /// de emulador (AOSP/Google) contienen "generic" o "sdk_gphone".
  static bool get isAndroidEmulator =>
      Platform.isAndroid &&
      (Platform.operatingSystemVersion.contains('generic') ||
          Platform.operatingSystemVersion.toLowerCase().contains('sdk_gphone'));

  /// Resuelve la URL por defecto cuando no hay `--dart-define`:
  /// en debug sobre emulador Android apunta al backend local del host
  /// (10.0.2.2 = loopback del host); en cualquier otro caso, a producción.
  static String _resolveDefaultBaseUrl() {
    if (kDebugMode && isAndroidEmulator) return _androidEmulatorBaseUrl;
    return _prodApiBaseUrl;
  }

  /// URL base normalizada: sin espacios en blanco ni `/` final, para que Dio
  /// y Socket.IO no failleeen resolviendo el host.
  static String get apiBaseUrl {
    var base = (_envApiBaseUrl.isNotEmpty ? _envApiBaseUrl : _resolveDefaultBaseUrl())
        .trim();
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    return base;
  }

  /// WebSocket URL. Se construye automáticamente si no se define.
  static const String wsBaseUrl = String.fromEnvironment(
    'WS_BASE_URL',
    defaultValue: '',
  );

  /// Devuelve la URL WebSocket real (auto-detecta de apiBaseUrl si no se definió).
  static String get wsUrl {
    if (wsBaseUrl.isNotEmpty) return wsBaseUrl;
    final base = apiBaseUrl;
    if (base.startsWith('https://')) {
      return base.replaceFirst('https://', 'wss://');
    }
    if (base.startsWith('http://')) {
      return base.replaceFirst('http://', 'ws://');
    }
    return 'ws://$base';
  }

  /// Rutas relativas (Dio las resuelve contra baseUrl).
  // -------------------------------------------------------------------------
  // Auth
  // -------------------------------------------------------------------------
  static const String authRegister = '/auth/register';
  static const String authLogin = '/auth/login';
  static const String authRefresh = '/auth/refresh';
  static const String authLogout = '/auth/logout';
  static const String authVerifyEmail = '/auth/verify-email';
  static const String authForgotPassword = '/auth/forgot-password';
  static const String authResetPassword = '/auth/reset-password';
  static const String authGoogle = '/auth/google';
  static const String authMe = '/auth/me';
  static const String authDeleteAccount = '/auth/delete-account';

  /// Client ID Web de Google OAuth (para google_sign_in).
  static const String googleWebClientId =
      String.fromEnvironment('GOOGLE_WEB_CLIENT_ID', defaultValue: '');

  // -------------------------------------------------------------------------
  // Usuarios
  // -------------------------------------------------------------------------
  static const String usersMe = '/users/me';
  static const String usersMeProfile = '/users/me/profile';
  static const String usersMeSetup = '/users/me/setup';
  static const String usersMeAvailability = '/users/me/availability';
  static const String usersMeAchievements = '/users/me/achievements';
  static const String usersMeStickers = '/users/me/stickers';
  static const String usersOnboarding = '/users/onboarding';
  static const String usersSetupInterests = '/users/setup/interests';
  static const String usersPaymentPassword = '/users/payment-password';
  static const String usersVerifyPaymentPassword =
      '/users/verify-payment-password';

  /// Registro de token FCM para notificaciones push.
  static const String usersDeviceToken = '/users/device-token';

  static String userProfile(String usernameOrId) =>
      '/users/$usernameOrId/profile';
  static String userFollowers(String usernameOrId) =>
      '/users/$usernameOrId/followers';
  static String userFollowing(String usernameOrId) =>
      '/users/$usernameOrId/following';
  static String userFollow(String userId) => '/users/follow/$userId';
  static String userUnfollow(String userId) => '/users/unfollow/$userId';
  static String userBlock(String usernameOrId) => '/users/$usernameOrId/block';
  static String userReport(String usernameOrId) =>
      '/users/$usernameOrId/report';
  static String userVisit(String usernameOrId) => '/users/$usernameOrId/visit';
  static String userVisits(String usernameOrId) =>
      '/users/$usernameOrId/visits';
  static String checkUsername(String username) =>
      '/users/check-username/$username';

  // -------------------------------------------------------------------------
  // Publicaciones
  // -------------------------------------------------------------------------
  static const String postsBase = '/posts';
  static const String postsFeed = '/posts/feed';
  static const String postsAiImprove = '/posts/ai-improve';
  static const String postsDraftsAutosave = '/posts/drafts/autosave';
  static const String postsDraftsMy = '/posts/drafts/my';
  static String postDetail(String id) => '/posts/$id';
  static String postReact(String id) => '/posts/$id/react';
  static String postBookmark(String id) => '/posts/$id/bookmark';
  static String postReactions(String id) => '/posts/$id/reactions';
  static String postComments(String id) => '/posts/$id/comments';
  static String postReport(String id) => '/posts/$id/report';
  static String postTranslate(String id) => '/posts/$id/translate';
  static String postJoinRp(String id) => '/posts/$id/join-rp';
  static String postUpload(String kind) => '/posts/upload/$kind';
  static String commentDetail(String id) => '/posts/comments/$id';
  static String commentLike(String id) => '/posts/comments/$id/like';

  // -------------------------------------------------------------------------
  // Vacantes de rol (RoleSlots)
  // -------------------------------------------------------------------------
  static String postSlots(String postId) => '/posts/$postId/slots';
  static String slotDetail(String slotId) => '/posts/slots/$slotId';
  static String slotAssign(String slotId) => '/posts/slots/$slotId/assign';

  // -------------------------------------------------------------------------
  // Bookmarks (publicaciones guardadas)
  // -------------------------------------------------------------------------
  static const String bookmarksBase = '/bookmarks';

  // -------------------------------------------------------------------------
  // Solicitudes de seguimiento (follow con aprobación)
  // -------------------------------------------------------------------------
  static const String followRequestsBase = '/users/me/follow-requests';
  static String followRequestRespond(String id) =>
      '/users/me/follow-requests/$id';

  // -------------------------------------------------------------------------
  // Wall (muro de perfil)
  // -------------------------------------------------------------------------
  static String wall(String userId) => '/wall/$userId';
  static String wallReact(String entryId) => '/wall/react/$entryId';

  // -------------------------------------------------------------------------
  // Upload genérico
  // -------------------------------------------------------------------------
  static String upload(String kind) => '/upload/$kind';

  // -------------------------------------------------------------------------
  // Search & Notifications
  // -------------------------------------------------------------------------
  static const String searchBase = '/search';
  static const String searchPeople = '/search/people';
  static const String searchSuggest = '/search/suggest';
  static const String searchTrending = '/search/trending';
  static const String notificationsBase = '/notifications';
  static String notificationDetail(String id) => '/notifications/$id';
  static const String roomsBase = '/rooms';
  static String roomDetail(String id) => '/rooms/$id';
  static String roomMessages(String id) => '/rooms/$id/messages';
  static const String storiesBase = '/stories';
  static const String storiesFeed = '/stories/feed';
  static String storyDetail(String id) => '/stories/$id';
  static String storyView(String id) => '/stories/$id/view';
  static const String circlesBase = '/circles';
  static const String circlesMyCircles = '/circles/my-circles';
  static const String circlesSearch = '/circles/search';
  static String circleDetail(String id) => '/circles/$id';
  static String circleJoin(String id) => '/circles/$id/join';
  static String circleLeave(String id) => '/circles/$id/leave';
  static String circlePosts(String id) => '/circles/$id/posts';

  // -------------------------------------------------------------------------
  // Salas (reuniones en vivo)
  // -------------------------------------------------------------------------
  static const String salasBase = '/salas';
  static String salaDetail(String id) => '/salas/$id';
  static String salaJoin(String id) => '/salas/$id/join';
  static String salaInvite(String id) => '/salas/$id/invite';
  static String salaLeave(String id) => '/salas/$id/leave';
  static String salaMessages(String id) => '/salas/$id/messages';
  static String salaVoiceToken(String id) => '/salas/$id/voice/token';
  static String salaStageRole(String id) => '/salas/$id/stage/role';
  static String salaMode(String id) => '/salas/$id/mode';
  static String salaMessage(String roomId, String messageId) =>
      '/salas/$roomId/messages/$messageId';
  static String salaMessageVote(String roomId, String messageId) =>
      '/salas/$roomId/messages/$messageId/vote';
  static const String messagesVoiceToken = '/messages/voice/token';

  static String chatSearch(String conversationId) =>
      '/rooms/$conversationId/messages/search';

  // -------------------------------------------------------------------------
  // Health
  // -------------------------------------------------------------------------
  static const String health = '/api/health';

  /// Tiempos de espera en milisegundos.
  ///
  /// `connectTimeout` corto (15 s): un timeout largo solo congelaba la UI
  /// esperando cold-starts de Render free-tier (30–50 s). El reintento con
  /// backoff del [ApiClient] cubre ese caso con feedback al usuario.
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 60);

  /// true si la app corre sin `--dart-define=API_BASE_URL` sobre Android
  /// (incluye emulador, donde el default resuelve a 10.0.2.2 en debug).
  static bool get isUsingDefaultEmulatorUrl =>
      !hasExplicitApiBaseUrl && Platform.isAndroid;
}
