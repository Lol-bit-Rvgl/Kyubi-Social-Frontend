import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyubi/core/errors/api_exception.dart';
import 'package:kyubi/core/network/api_client.dart';
import 'package:kyubi/core/widgets/google_sign_in_button.dart';
import 'package:kyubi/repositories/auth_repository.dart';

class FakeApiClientGoogle extends Fake implements ApiClient {
  String? lastPath;
  Map<String, dynamic>? lastData;
  Map<String, dynamic> responseToReturn = {
    'accessToken': 'jwt-google-access',
    'refreshToken': 'jwt-google-refresh',
    'user': {
      'id': 'user-google-1',
      'username': 'google_user',
      'displayName': 'Google User',
      'email': 'user@gmail.com',
      'emailVerifiedAt': '2026-09-13T20:00:00.000Z',
      'onboardingCompleted': true,
      'role': 'USER',
      'followersCount': 0,
      'followingCount': 0,
      'isFollowing': false,
    },
  };

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
    return responseToReturn;
  }
}

void main() {
  group('AuthRepository - Google Sign In', () {
    late FakeApiClientGoogle fakeApi;
    late AuthRepository authRepo;

    setUp(() {
      fakeApi = FakeApiClientGoogle();
      authRepo = AuthRepository(fakeApi);
    });

    test('returns null when user cancels Google account selector', () async {
      final result = await authRepo.signInWithGoogle(
        idTokenProvider: () async => null,
      );

      expect(result, isNull);
      expect(fakeApi.lastPath, isNull);
    });

    test('sends idToken to /auth/google and returns AuthResult on success', () async {
      final result = await authRepo.signInWithGoogle(
        idTokenProvider: () async => 'sample-google-id-token',
      );

      expect(fakeApi.lastPath, '/auth/google');
      expect(fakeApi.lastData, {'idToken': 'sample-google-id-token'});
      expect(result, isNotNull);
      expect(result!.accessToken, 'jwt-google-access');
      expect(result.refreshToken, 'jwt-google-refresh');
      expect(result.user?.id, 'user-google-1');
      expect(result.user?.email, 'user@gmail.com');
    });

    test('throws ApiException when idToken is empty', () async {
      expect(
        () => authRepo.signInWithGoogle(idTokenProvider: () async => ''),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('GoogleSignInButton Widget', () {
    testWidgets('renders button with label and responds to tap', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GoogleSignInButton(
              onPressed: () => tapped = true,
              label: 'Continuar con Google',
            ),
          ),
        ),
      );

      expect(find.text('Continuar con Google'), findsOneWidget);
      expect(find.byType(GoogleLogoWidget), findsOneWidget);

      await tester.tap(find.byType(GoogleSignInButton));
      expect(tapped, isTrue);
    });

    testWidgets('shows loading spinner and disables tap when loading', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GoogleSignInButton(
              loading: true,
              onPressed: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Continuar con Google'), findsNothing);

      await tester.tap(find.byType(GoogleSignInButton));
      expect(tapped, isFalse);
    });
  });
}
