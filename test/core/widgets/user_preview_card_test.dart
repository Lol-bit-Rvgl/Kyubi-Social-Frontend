import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyubi/core/widgets/liquid_glass_container.dart';
import 'package:kyubi/core/widgets/user_preview_card.dart';
import 'package:kyubi/models/user.dart';

void main() {
  group('UserPreviewCard Tests', () {
    const testUser = User(
      id: 'usr-123',
      username: 'sakura_fox',
      displayName: 'Sakura Kitsune',
      bio: 'Viajera cósmica en busca de historias y roleplay.',
      bannerUrl: 'https://example.com/banner.jpg',
      usernameColor: '#FF69B4',
      level: 12,
      isOnline: true,
    );

    const testUserNoBanner = User(
      id: 'usr-456',
      username: 'ronin_wolf',
      displayName: 'Ronin Solitario',
      bio: null,
      bannerUrl: null,
      level: 3,
      isOnline: false,
    );

    testWidgets('Renders UserPreviewCard with avatar, name, badges, bio, and custom background', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: UserPreviewCard(
                user: testUser,
              ),
            ),
          ),
        ),
      );

      // Verify Liquid Glass frame and card components
      expect(find.byType(LiquidGlassContainer), findsOneWidget);
      expect(find.text('Sakura Kitsune'), findsOneWidget);
      expect(find.text('@sakura_fox'), findsOneWidget);
      expect(find.text('Activo'), findsOneWidget);
      expect(find.text('Nv. 12'), findsOneWidget);
      expect(find.text('Viajera cósmica en busca de historias y roleplay.'), findsOneWidget);
      expect(find.text('Ver perfil completo'), findsOneWidget);
    });

    testWidgets('Renders UserPreviewCard with default cosmic background and no bio cleanly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: UserPreviewCard(
                user: testUserNoBanner,
                activityStatus: 'En sala',
              ),
            ),
          ),
        ),
      );

      expect(find.text('Ronin Solitario'), findsOneWidget);
      expect(find.text('@ronin_wolf'), findsOneWidget);
      expect(find.text('En sala'), findsOneWidget);
      expect(find.text('Nv. 3'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Invokes onViewProfile and onMention callbacks when actions are tapped', (tester) async {
      bool viewProfileCalled = false;
      bool mentionCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: UserPreviewCard(
                user: testUser,
                onViewProfile: () => viewProfileCalled = true,
                onMention: () => mentionCalled = true,
              ),
            ),
          ),
        ),
      );

      // Tap "Ver perfil completo"
      await tester.tap(find.text('Ver perfil completo'));
      await tester.pump();
      expect(viewProfileCalled, isTrue);

      // Tap Mention button
      await tester.tap(find.byIcon(Icons.alternate_email_rounded));
      await tester.pump();
      expect(mentionCalled, isTrue);
    });

    testWidgets('showUserPreviewDialog renders floating modal and closes on action', (tester) async {
      bool viewProfileTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showUserPreviewDialog(
                    context,
                    testUser,
                    onViewProfile: () => viewProfileTriggered = true,
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      // Open Dialog
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.byType(UserPreviewCard), findsOneWidget);
      expect(find.text('Sakura Kitsune'), findsOneWidget);

      // Tap action inside dialog
      await tester.tap(find.text('Ver perfil completo'));
      await tester.pumpAndSettle();

      expect(viewProfileTriggered, isTrue);
      // Dialog should be dismissed
      expect(find.byType(UserPreviewCard), findsNothing);
    });
  });
}
