import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyubi/core/widgets/app_avatar.dart';
import 'package:kyubi/core/widgets/user_preview_card.dart';
import 'package:kyubi/features/home/presentation/widgets/header_profile.dart';
import 'package:kyubi/models/user.dart';
import 'package:kyubi/services/auth_controller.dart';
import 'package:kyubi/services/providers.dart';

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(this._user);
  final User? _user;

  @override
  AuthState build() => AuthState(
        status: _user != null
            ? AuthStatus.authenticated
            : AuthStatus.unauthenticated,
        user: _user,
      );
}

class _FakeUnreadCountNotifier extends UnreadCountNotifier {
  @override
  int build() => 0;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testUser = User(
    id: 'user_123',
    username: 'kitsune',
    displayName: 'Kitsune Celestial',
    avatarUrl: 'https://example.com/avatar.png',
  );

  group('Avatar AspectRatio & Anti-Deformation Tests', () {
    testWidgets('1. AppAvatar mantiene relación 1:1 estricta (width == height)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: AppAvatar(
                name: 'Kitsune Celestial',
                radius: 20,
              ),
            ),
          ),
        ),
      );

      final avatarFinder = find.byType(AppAvatar);
      expect(avatarFinder, findsOneWidget);

      final size = tester.getSize(avatarFinder);
      expect(size.width, equals(40.0));
      expect(size.height, equals(40.0));
      expect(size.width / size.height, equals(1.0));
    });

    testWidgets('2. HeaderProfile avatar se renderiza en contenedor estrictamente cuadrado 40x40', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(
              () => _FakeAuthNotifier(testUser),
            ),
            unreadCountProvider.overrideWith(
              () => _FakeUnreadCountNotifier(),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: CustomScrollView(
                slivers: [
                  HeaderProfile(),
                ],
              ),
            ),
          ),
        ),
      );

      final appAvatarFinder = find.byType(AppAvatar);
      expect(appAvatarFinder, findsOneWidget);

      final avatarSize = tester.getSize(appAvatarFinder);
      expect(avatarSize.width, equals(38.0));
      expect(avatarSize.height, equals(38.0));

      // Busca el AspectRatio que envuelve al avatar en HeaderProfile
      final aspectRatios = tester.widgetList<AspectRatio>(find.byType(AspectRatio));
      final hasOneToOne = aspectRatios.any((ar) => ar.aspectRatio == 1.0);
      expect(hasOneToOne, isTrue);
    });

    testWidgets('3. UserPreviewCard avatar y halo conservan dimensiones 1:1 en modo estándar y compacto', (tester) async {
      // Modo Compacto (Drawer)
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: UserPreviewCard(
                user: testUser,
                isCompact: true,
              ),
            ),
          ),
        ),
      );

      final compactAvatarFinder = find.byType(AppAvatar);
      expect(compactAvatarFinder, findsOneWidget);

      final compactSize = tester.getSize(compactAvatarFinder);
      expect(compactSize.width, equals(compactSize.height));
      expect(compactSize.width, equals(52.0)); // radius 26.0 * 2 = 52.0

      // Modo Estándar
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: UserPreviewCard(
                user: testUser,
                isCompact: false,
              ),
            ),
          ),
        ),
      );

      final standardAvatarFinder = find.byType(AppAvatar);
      expect(standardAvatarFinder, findsOneWidget);

      final standardSize = tester.getSize(standardAvatarFinder);
      expect(standardSize.width, equals(standardSize.height));
      expect(standardSize.width, equals(58.0)); // radius 29.0 * 2 = 58.0
    });
  });
}
