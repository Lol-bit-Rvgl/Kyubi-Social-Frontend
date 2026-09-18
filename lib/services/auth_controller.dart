import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors/api_exception.dart';
import '../core/network/api_client.dart';
import '../core/services/notification_service.dart';
import '../core/storage/session_store.dart';
import '../models/user.dart';
import '../repositories/auth_repository.dart';
import '../features/messages/presentation/conversations_controller.dart';
import '../features/messages/presentation/follow_requests_controller.dart';
import '../features/salas/presentation/room_invites_controller.dart';
import '../features/salas/presentation/salas_controller.dart';
import '../routing/router_refresh.dart';
import 'providers.dart';
import 'voice/voice_room_controller.dart';

enum AuthStatus { unknown, unauthenticated, authenticated }

/// Centinela para distinguir "no pasar este campo" de "ponerlo a null" en
/// [AuthState.copyWith] (permite limpiar `error`/`user` explícitamente).
class _Unset {
  const _Unset();
}

/// Estado global de autenticación.
class AuthState {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.error,
    this.busy = false,
  });

  static const _unset = _Unset();

  final AuthStatus status;
  final User? user;
  final String? error;
  final bool busy;

  bool get isAuthenticated => status == AuthStatus.authenticated;

  AuthState copyWith({
    AuthStatus? status,
    Object? user = _unset,
    Object? error = _unset,
    bool? busy,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: identical(user, _unset) ? this.user : user as User?,
      error: identical(error, _unset) ? this.error : error as String?,
      busy: busy ?? this.busy,
    );
  }
}

typedef AuthController = AuthNotifier;

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState();

  AuthRepository get _auth => ref.read(authRepositoryProvider);

  void _purgeUserSessionState() {
    final currentUserId = state.user?.id;
    try {
      ref.read(chatSocketProvider).disconnect();
    } catch (_) {}
    try {
      ref.read(notificationSocketProvider).disconnect();
    } catch (_) {}
    try {
      ref.read(roomSocketProvider).disconnect();
    } catch (_) {}
    try {
      ref.read(voiceRoomProvider.notifier).leaveRoom();
    } catch (_) {}
    try {
      ref.read(salasControllerProvider.notifier).clearAll();
    } catch (_) {}
    try {
      ref.read(roomInvitesControllerProvider.notifier).clear();
    } catch (_) {}
    try {
      ConversationsCache.clear(userId: currentUserId);
      RoomsCache.clear(userId: currentUserId);
    } catch (_) {}

    ref.invalidate(salasControllerProvider);
    ref.invalidate(conversationsControllerProvider);
    ref.invalidate(unreadCountProvider);
    ref.invalidate(followRequestsControllerProvider);
    ref.invalidate(roomInvitesControllerProvider);
  }

  void _onUserSessionAuthenticated() {
    try {
      ref.read(notificationSocketProvider).connect();
    } catch (_) {}
    try {
      ref.read(chatSocketProvider).connect();
    } catch (_) {}
    try {
      ref.read(roomSocketProvider).connect();
    } catch (_) {}

    ref.invalidate(salasControllerProvider);
    ref.invalidate(conversationsControllerProvider);
    ref.invalidate(unreadCountProvider);
    ref.invalidate(followRequestsControllerProvider);
    ref.invalidate(roomInvitesControllerProvider);
  }

  Future<void> restoreSession() async {
    final repo = SessionRepository(_auth);
    try {
      final user = await repo.restoreUser();
      state = user != null
          ? AuthState(status: AuthStatus.authenticated, user: user)
          : const AuthState(status: AuthStatus.unauthenticated);
      if (user != null) {
        _onUserSessionAuthenticated();
        // Push: registrar token FCM tras restaurar sesión.
        NotificationService.instance.syncTokenWithBackend(
          ref.read(apiClientProvider),
        );
      }
    } on Exception catch (e) {
      state = AuthState(
        status: AuthStatus.unauthenticated,
        error: extractErrorMessage(e),
      );
    }
  }

  /// Extrae un mensaje de error limpio y legible para el usuario en español,
  /// evitando exponer excepciones crudas tipo `DioException [bad response]`.
  static String extractErrorMessage(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map) {
        if (data['message'] != null &&
            data['message'].toString().trim().isNotEmpty) {
          return data['message'].toString().trim();
        }
        if (data['error'] is String &&
            data['error'].toString().trim().isNotEmpty) {
          final errStr = data['error'].toString().trim();
          if (errStr != 'validation_error' && errStr != 'bad_request') {
            return errStr;
          }
        }
      }
      final statusCode = error.response?.statusCode;
      if (statusCode == 401) {
        return 'Credenciales incorrectas. Verifica tu correo y contraseña.';
      }
      if (statusCode == 409) {
        return 'El correo electrónico o nombre de usuario ya está registrado.';
      }
      if (statusCode == 400) {
        return 'Los datos proporcionados no son válidos. Por favor verifícalos.';
      }
      return mapDioException(error).message;
    }
    if (error is ApiException) {
      if (error.statusCode == 401) {
        return 'Credenciales incorrectas. Verifica tu correo y contraseña.';
      }
      if (error.statusCode == 409) {
        return 'El correo electrónico o nombre de usuario ya está registrado.';
      }
      return error.message;
    }
    final errorStr = error.toString();
    if (errorStr.startsWith('Exception: ')) {
      return errorStr.substring('Exception: '.length);
    }
    if (errorStr.contains('DioException') ||
        errorStr.contains('[bad response]')) {
      return 'Ocurrió un error al procesar tu solicitud.';
    }
    return errorStr;
  }

  Future<bool> login({required String email, required String password}) async {
    state = state.copyWith(busy: true, error: null);
    try {
      final result = await _auth.login(email: email, password: password);
      _purgeUserSessionState();
      await SessionRepository(_auth).saveSession(result);
      final user = result.user ?? await _auth.me();
      state = AuthState(
        status: AuthStatus.authenticated,
        user: user,
        busy: false,
      );
      _onUserSessionAuthenticated();
      // Push: registrar token FCM del dispositivo en el backend.
      await NotificationService.instance.syncTokenWithBackend(
        ref.read(apiClientProvider),
      );
      return true;
    } on Exception catch (e) {
      state = state.copyWith(busy: false, error: extractErrorMessage(e));
      return false;
    }
  }

  Future<bool> register({
    required String email,
    required String username,
    required String password,
    String? displayName,
  }) async {
    state = state.copyWith(busy: true, error: null);
    try {
      final result = await _auth.register(
        email: email,
        username: username,
        password: password,
        displayName: displayName,
      );
      _purgeUserSessionState();
      await SessionRepository(_auth).saveSession(result);
      final user = result.user ?? await _auth.me();
      state = AuthState(
        status: AuthStatus.authenticated,
        user: user,
        busy: false,
      );
      _onUserSessionAuthenticated();
      // Push: registrar token FCM del dispositivo en el backend.
      await NotificationService.instance.syncTokenWithBackend(
        ref.read(apiClientProvider),
      );
      return true;
    } on Exception catch (e) {
      state = state.copyWith(busy: false, error: extractErrorMessage(e));
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    state = state.copyWith(busy: true, error: null);
    try {
      final result = await _auth.signInWithGoogle();
      if (result == null) {
        // Cancelado voluntariamente por el usuario en el selector de Google
        state = state.copyWith(busy: false);
        return false;
      }
      _purgeUserSessionState();
      await SessionRepository(_auth).saveSession(result);
      final user = result.user ?? await _auth.me();
      state = AuthState(
        status: AuthStatus.authenticated,
        user: user,
        busy: false,
      );
      _onUserSessionAuthenticated();
      // Push: registrar token FCM del dispositivo en el backend.
      await NotificationService.instance.syncTokenWithBackend(
        ref.read(apiClientProvider),
      );
      return true;
    } on Exception catch (e) {
      state = state.copyWith(busy: false, error: extractErrorMessage(e));
      return false;
    }
  }

  Future<void> logout() async {
    // 1. Desconectar sockets y purgar estado en memoria de inmediato
    _purgeUserSessionState();

    // 2. Notificar al backend de la revocación del token de sesión (con timeout)
    try {
      final refresh = await TokenStorage.refreshToken();
      if (refresh != null && refresh.isNotEmpty) {
        await _auth
            .logout(refreshToken: refresh)
            .timeout(const Duration(seconds: 2));
      }
    } catch (_) {}

    // 3. Desregistrar token FCM en el backend (con timeout)
    try {
      await NotificationService.instance
          .unregisterToken(ref.read(apiClientProvider))
          .timeout(const Duration(seconds: 2));
    } catch (e) {
      debugPrint('[FCM] Error o timeout desregistrando token: $e');
    }

    // 4. Limpiar almacenamiento seguro local (tokens, usuario y caché)
    try {
      final repo = SessionRepository(_auth);
      await repo.clearSession();
    } catch (e) {
      debugPrint('[Auth] Error limpiando sesión local: $e');
    } finally {
      // 5. Garantizar SIEMPRE la transición a no autenticado y notificar al router raíz
      state = const AuthState(status: AuthStatus.unauthenticated);
      ref.read(routerRefreshProvider).notifySessionChanged();
    }
  }

  void updateUser(User user) {
    final currentTheme = state.user?.themeSettings;
    User resolvedUser = user;
    if (currentTheme != null &&
        (user.extensions == null || user.extensions!['themeSettings'] == null)) {
      resolvedUser = user.copyWith(
        extensions: {
          ...?user.extensions,
          'themeColor': currentTheme.primaryColor,
          'themeSettings': currentTheme.toJson(),
        },
      );
    }
    state = state.copyWith(user: resolvedUser);
    LastUserStorage.save(resolvedUser.toJson());
  }

  Future<void> loadCurrentUser() async {
    try {
      final user = await _auth.me();
      updateUser(user);
    } catch (_) {
      await restoreSession();
    }
  }

  void clearError() => state = state.copyWith(error: null);

  Future<void> forgotPassword(String email) => _auth.forgotPassword(email);

  Future<void> resetPassword({
    String? token,
    String? code,
    String? email,
    required String password,
  }) => _auth.resetPassword(
    token: token,
    code: code,
    email: email,
    password: password,
  );

  Future<void> deleteAccount({String? password}) async {
    state = state.copyWith(busy: true, error: null);
    try {
      await _auth.deleteAccount(password: password);
      _purgeUserSessionState();
      await SessionRepository(_auth).clearSession();
      state = const AuthState(status: AuthStatus.unauthenticated);
      ref.read(routerRefreshProvider).notifySessionChanged();
    } on Exception catch (e) {
      state = state.copyWith(busy: false, error: e.toString());
    }
  }

  /// Cierre de sesión forzado por sanción del staff (SUSPEND/BAN).
  /// No llama al backend: los tokens ya fueron invalidados desde el panel.
  Future<void> forceLogoutBySanction() async {
    _purgeUserSessionState();
    try {
      await TokenStorage.clear();
      await LastUserStorage.clear();
      await ConversationsCache.clear();
    } catch (_) {
      // Ignorar errores de storage: el reseteo de sesión debe completar igual.
    }
    state = const AuthState(status: AuthStatus.unauthenticated);
    ref.read(routerRefreshProvider).notifySessionChanged();
  }
}

final authControllerProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
