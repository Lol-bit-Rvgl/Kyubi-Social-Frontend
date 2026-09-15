import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyubi/core/network/api_client.dart';
import 'package:kyubi/features/auth/presentation/reset_password/reset_password_screen.dart';
import 'package:kyubi/repositories/auth_repository.dart';
import 'package:kyubi/services/providers.dart';

class FakeAuthApiClient extends Fake implements ApiClient {
  String? lastPath;
  Map<String, dynamic>? lastData;

  @override
  Future<Map<String, dynamic>> postJson(
    String path, {
    Object? data,
    Map<String, dynamic>? query,
  }) async {
    lastPath = path;
    if (data is Map<String, dynamic>) {
      lastData = data;
    }
    return {'success': true};
  }
}

void main() {
  group('AuthRepository - Password Reset Flow', () {
    late FakeAuthApiClient fakeApi;
    late AuthRepository authRepo;

    setUp(() {
      fakeApi = FakeAuthApiClient();
      authRepo = AuthRepository(fakeApi);
    });

    test('forgotPassword sends normalized email payload', () async {
      await authRepo.forgotPassword('  User@Example.COM ');
      expect(fakeApi.lastPath, '/auth/forgot-password');
      expect(fakeApi.lastData, {'email': 'user@example.com'});
    });

    test('requestPasswordReset delegates to forgotPassword', () async {
      await authRepo.requestPasswordReset('hola@kyubi.app');
      expect(fakeApi.lastPath, '/auth/forgot-password');
      expect(fakeApi.lastData, {'email': 'hola@kyubi.app'});
    });

    test('resetPassword with OTP code sends code, email, and password', () async {
      await authRepo.resetPassword(
        email: 'user@example.com',
        code: '123456',
        password: 'new-secure-password',
      );
      expect(fakeApi.lastPath, '/auth/reset-password');
      expect(fakeApi.lastData?['email'], 'user@example.com');
      expect(fakeApi.lastData?['code'], '123456');
      expect(fakeApi.lastData?['password'], 'new-secure-password');
      expect(fakeApi.lastData?['newPassword'], 'new-secure-password');
      expect(fakeApi.lastData?['token'], isNull);
    });

    test('resetPassword with deep link token sends token and password', () async {
      await authRepo.resetPassword(
        token: 'secure-token-123456',
        password: 'new-secure-password',
      );
      expect(fakeApi.lastPath, '/auth/reset-password');
      expect(fakeApi.lastData?['token'], 'secure-token-123456');
      expect(fakeApi.lastData?['password'], 'new-secure-password');
      expect(fakeApi.lastData?['code'], isNull);
    });
  });

  group('ResetPasswordScreen Widget Tests', () {
    testWidgets('Deep-link mode renders verified badge and hides OTP input', (tester) async {
      final fakeApi = FakeAuthApiClient();
      final authRepo = AuthRepository(fakeApi);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(authRepo),
          ],
          child: const MaterialApp(
            home: ResetPasswordScreen(
              token: 'valid-deep-link-token',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Enlace de recuperación verificado.'), findsOneWidget);
      expect(find.text('Código OTP (6 dígitos)'), findsNothing);
      expect(find.text('Nueva contraseña'), findsOneWidget);
      expect(find.text('Confirmar contraseña'), findsOneWidget);
    });

    testWidgets('In-app OTP mode renders email and 6-digit code input', (tester) async {
      final fakeApi = FakeAuthApiClient();
      final authRepo = AuthRepository(fakeApi);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(authRepo),
          ],
          child: const MaterialApp(
            home: ResetPasswordScreen(
              email: 'test@example.com',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Enlace de recuperación verificado.'), findsNothing);
      expect(find.text('Código OTP (6 dígitos)'), findsOneWidget);
      expect(find.text('Correo electrónico'), findsOneWidget);
      expect(find.text('test@example.com'), findsOneWidget);
      expect(find.text('Nueva contraseña'), findsOneWidget);
      expect(find.text('Confirmar contraseña'), findsOneWidget);
    });
  });
}
