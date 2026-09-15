import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyubi/core/widgets/app_drawer.dart';
import 'package:kyubi/models/user.dart';

void main() {
  group('KyubiDrawer Tests', () {
    const testUser = User(
      id: 'u1',
      username: 'kitsune',
      displayName: 'Kitsune Hero',
      bannerUrl: 'https://example.com/banner.jpg',
      usernameColor: '#BA68C8',
      level: 5,
    );

    const testUserNoBanner = User(
      id: 'u2',
      username: 'neko',
      displayName: 'Neko Chan',
      bannerUrl: null,
      level: 1,
    );

    testWidgets('Renders KyubiDrawer with retained options and verified absence of purged options', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              drawer: const KyubiDrawer(user: testUser),
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  child: const Text('Open Drawer'),
                ),
              ),
            ),
          ),
        ),
      );

      // Open drawer
      await tester.tap(find.text('Open Drawer'));
      await tester.pumpAndSettle();

      expect(find.byType(KyubiDrawer), findsOneWidget);
      expect(find.byType(Drawer), findsOneWidget);
      expect(find.byType(BackdropFilter), findsWidgets);
      expect(find.text('Kitsune Hero'), findsOneWidget);
      expect(find.text('@kitsune'), findsOneWidget);
      expect(find.text('Nv. 5'), findsOneWidget);

      // Opciones conservadas exclusivamente
      expect(find.text('Mi Perfil'), findsOneWidget);
      expect(find.text('Guardados'), findsOneWidget);
      expect(find.text('Ajustes & Cuenta'), findsOneWidget);
      expect(find.text('Cerrar sesión'), findsOneWidget);

      // Opciones purgadas que no deben existir
      expect(find.text('Fichas de Rol (OCs)'), findsNothing);
      expect(find.text('Salas en vivo (RP)'), findsNothing);
      expect(find.text('Comunidades'), findsNothing);
      expect(find.text('Billetera & Monedas'), findsNothing);
      expect(find.text('Tienda de Cosméticos'), findsNothing);
    });

    testWidgets('Renders KyubiDrawer with default cosmic background and fallback color when color is null', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              drawer: const KyubiDrawer(user: testUserNoBanner),
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  child: const Text('Open Drawer'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Drawer'));
      await tester.pumpAndSettle();

      expect(find.byType(KyubiDrawer), findsOneWidget);
      expect(find.text('Neko Chan'), findsOneWidget);
      expect(find.text('@neko'), findsOneWidget);
      expect(find.text('Nv. 1'), findsOneWidget);

      // Color de respaldo por defecto
      final profileText = tester.widget<Text>(find.text('Mi Perfil'));
      expect(profileText.style?.color, const Color(0xFFE0E0E0));
    });

    testWidgets('Renders retained DrawerTiles with dynamic profile color', (tester) async {
      const customColorUser = User(
        id: 'u3',
        username: 'colored_user',
        displayName: 'Colored User',
        usernameColor: '#00E5FF',
        level: 8,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              drawer: const KyubiDrawer(user: customColorUser),
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  child: const Text('Open Drawer'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Drawer'));
      await tester.pumpAndSettle();

      const expectedColor = Color(0xFF00E5FF);

      // Verificar color en los textos de los DrawerTile
      final profileText = tester.widget<Text>(find.text('Mi Perfil'));
      expect(profileText.style?.color, expectedColor);

      final savedText = tester.widget<Text>(find.text('Guardados'));
      expect(savedText.style?.color, expectedColor);

      final settingsText = tester.widget<Text>(find.text('Ajustes & Cuenta'));
      expect(settingsText.style?.color, expectedColor);

      // Verificar propiedades color en widgets DrawerTile
      final drawerTiles = tester.widgetList<DrawerTile>(find.byType(DrawerTile));
      final profileTile = drawerTiles.firstWhere((t) => t.label == 'Mi Perfil');
      expect(profileTile.color, expectedColor);

      final savedTile = drawerTiles.firstWhere((t) => t.label == 'Guardados');
      expect(savedTile.color, expectedColor);

      final settingsTile = drawerTiles.firstWhere((t) => t.label == 'Ajustes & Cuenta');
      expect(settingsTile.color, expectedColor);
    });

    testWidgets('Triggers onProfileTap callback when header is tapped', (tester) async {
      bool profileTapped = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              drawer: KyubiDrawer(
                user: testUser,
                onProfileTap: () => profileTapped = true,
              ),
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  child: const Text('Open Drawer'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Drawer'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Kitsune Hero'));
      await tester.pumpAndSettle();

      expect(profileTapped, isTrue);
    });

    testWidgets('Renders Cerrar sesión tile with themed accent color', (tester) async {
      final userWithAccent = User.fromJson({
        'id': 'u-accent',
        'username': 'cyber_fox',
        'displayName': 'Cyber Fox',
        'themeSettings': {
          'primaryColor': '#7C4DFF',
          'accentColor': '#00E5FF',
          'glassStyle': 'transparent',
        },
      });

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              drawer: KyubiDrawer(user: userWithAccent),
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  child: const Text('Open Drawer'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Drawer'));
      await tester.pumpAndSettle();

      final drawerTiles = tester.widgetList<DrawerTile>(find.byType(DrawerTile));
      final logoutTile = drawerTiles.firstWhere((t) => t.label == 'Cerrar sesión');
      expect(logoutTile.color, const Color(0xFF00E5FF));

      final logoutText = tester.widget<Text>(find.text('Cerrar sesión'));
      expect(logoutText.style?.color, const Color(0xFF00E5FF));
    });
  });
}
