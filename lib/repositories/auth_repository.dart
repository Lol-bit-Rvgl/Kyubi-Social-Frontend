import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../core/config/app_config.dart';
import '../core/errors/api_exception.dart';
import '../core/network/api_client.dart';
import '../core/network/client_identity.dart';
import '../core/storage/session_store.dart';
import '../models/auth_result.dart';
import '../models/user.dart';

/// Acceso a los endpoints de autenticación.
class AuthRepository {
  AuthRepository(this._api);

  final ApiClient _api;

  Future<AuthResult> register({
    required String email,
    required String username,
    required String password,
    String? displayName,
  }) async {
    final body = await _api.postJson(
      AppConfig.authRegister,
      data: {
        'email': email.trim().toLowerCase(),
        'username': username.trim(),
        'password': password,
        if (displayName != null && displayName.isNotEmpty)
          'displayName': displayName.trim(),
      },
    );
    return AuthResult.fromJson(body);
  }

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final body = await _api.postJson(
      AppConfig.authLogin,
      data: {'email': email.trim().toLowerCase(), 'password': password},
    );
    return AuthResult.fromJson(body);
  }

  Future<void> logout({String? refreshToken}) async {
    try {
      await _api.postJson(
        AppConfig.authLogout,
        data: {'refreshToken': ?refreshToken},
      );
    } on ApiException {
      // El logout local siempre se ejecuta aunque la API falle.
    }
  }

  Future<AuthResult> refreshToken(String refreshToken) async {
    final body = await _api.postJson(
      AppConfig.authRefresh,
      data: {'refreshToken': refreshToken},
    );
    return AuthResult.fromJson(body);
  }

  Future<void> forgotPassword(String email) async {
    await _api.postJson(
      AppConfig.authForgotPassword,
      data: {'email': email.trim().toLowerCase()},
    );
  }

  Future<void> requestPasswordReset(String email) => forgotPassword(email);

  Future<void> resetPassword({
    String? token,
    String? code,
    String? email,
    required String password,
  }) async {
    await _api.postJson(
      AppConfig.authResetPassword,
      data: {
        if (email != null && email.trim().isNotEmpty)
          'email': email.trim().toLowerCase(),
        if (code != null && code.trim().isNotEmpty) 'code': code.trim(),
        if (token != null && token.trim().isNotEmpty) 'token': token.trim(),
        'password': password,
        'newPassword': password,
      },
    );
  }

  Future<void> verifyEmail(String token) async {
    await _api.postJson(AppConfig.authVerifyEmail, data: {'token': token});
  }

  Future<User> me() async {
    final body = await _api.getJson(AppConfig.authMe);
    return User.fromJson(body);
  }

  Future<void> deleteAccount({String? password}) async {
    await _api.postJson(
      AppConfig.authDeleteAccount,
      data: {'password': ?password},
    );
  }

  Future<AuthResult?> signInWithGoogle({
    Future<String?> Function()? idTokenProvider,
  }) async {
    final String? idToken;
    if (idTokenProvider != null) {
      idToken = await idTokenProvider();
    } else {
      final googleSignIn = GoogleSignIn(
        serverClientId: AppConfig.googleWebClientId.isNotEmpty
            ? AppConfig.googleWebClientId
            : null,
        scopes: const ['email', 'profile'],
      );

      final GoogleSignInAccount? account;
      try {
        account = await googleSignIn.signIn();
      } catch (e) {
        debugPrint(
          '[GoogleSignIn] Error al invocar selector nativo de Google: $e',
        );
        rethrow;
      }

      if (account == null) {
        // El usuario canceló o cerró el selector de cuenta de Google
        return null;
      }

      final auth = await account.authentication;
      idToken = auth.idToken;
    }

    if (idToken == null) {
      return null;
    }

    if (idToken.isEmpty) {
      throw const ApiException(
        message: 'No se pudo obtener el token de autenticación de Google',
        type: ApiExceptionType.unauthorized,
      );
    }

    final body = await _api.postJson(
      AppConfig.authGoogle,
      data: {'idToken': idToken},
    );
    return AuthResult.fromJson(body);
  }
}

/// Repositorio de sesión: guarda/restaura/limpia tokens y usuario.
class SessionRepository {
  SessionRepository(this._auth);

  final AuthRepository _auth;

  Future<void> saveSession(AuthResult result) async {
    await TokenStorage.saveTokens(
      accessToken: result.accessToken,
      refreshToken: result.refreshToken,
    );
    await ClientIdentity.resetSid();
    if (result.user != null) {
      await LastUserStorage.save(result.user!.toJson());
    }
  }

  Future<User?> restoreUser() async {
    final access = await TokenStorage.accessToken();
    final refresh = await TokenStorage.refreshToken();
    if ((access == null || access.isEmpty) &&
        (refresh == null || refresh.isEmpty)) {
      return null;
    }
    try {
      return await _auth.me();
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        // Intenta renovar el token antes de expulsar al usuario.
        final refreshed = await ApiClient.instance.runRefreshExplicit();
        if (refreshed) {
          try {
            return await _auth.me();
          } catch (_) {}
        }
        final hasRefresh =
            (await TokenStorage.refreshToken())?.isNotEmpty == true;
        // Si el refresh sigue existiendo (fallo transitorio de red / timeout),
        // recuperamos el usuario cacheado para evitar un login forzado arbitrario.
        final cached = await LastUserStorage.read();
        if (cached != null) return User.fromJson(cached);
        if (!hasRefresh) {
          await TokenStorage.clear();
          return null;
        }
        return null;
      }
      // Sin red: recuperar el último usuario cacheado.
      final cached = await LastUserStorage.read();
      if (cached != null) return User.fromJson(cached);
      rethrow;
    }
  }

  Future<void> clearSession() async {
    await TokenStorage.clear();
    await LastUserStorage.clear();
    await ConversationsCache.clear();
    await ClientIdentity.resetSid();
  }
}

/// Cliente de session con refresco manual (para inyección).
Future<AuthResult> refreshSession(AuthRepository auth) async {
  final refresh = await TokenStorage.refreshToken();
  if (refresh == null || refresh.isEmpty) {
    throw const ApiException(
      message: 'Sesión expirada',
      type: ApiExceptionType.unauthorized,
      statusCode: 401,
    );
  }
  return auth.refreshToken(refresh);
}
