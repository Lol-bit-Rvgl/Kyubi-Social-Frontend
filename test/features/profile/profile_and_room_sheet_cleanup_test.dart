import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyubi/features/profile/presentation/widgets/profile_sliver_app_bar.dart';
import 'package:kyubi/features/salas/presentation/widgets/room_user_profile_sheet.dart';
import 'package:kyubi/models/user.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Profile Header Cleanup Tests', () {
    const testUser = User(
      id: 'u-clean-1',
      username: 'cosmicfox',
      displayName: 'Cosmic Fox',
    );

    testWidgets('ProfileSliverAppBar no proyecta título colapsado flotante', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                const ProfileSliverAppBar(
                  user: testUser,
                  pinned: true,
                ),
                SliverToBoxAdapter(
                  child: Container(
                    height: 1200,
                    color: Colors.blueGrey,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // Deslizar para colapsar completamente el SliverAppBar
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();

      // Ningún widget de texto con displayName o @username debe aparecer en ProfileSliverAppBar
      final flexibleSpaceFinder = find.byType(FlexibleSpaceBar);
      expect(flexibleSpaceFinder, findsOneWidget);

      final flexibleSpace = tester.widget<FlexibleSpaceBar>(flexibleSpaceFinder);
      expect(flexibleSpace.title, isNull);
    });
  });

  group('RoomUserProfileSheet UI Cleanup Tests', () {
    testWidgets('No renderiza botón de 3 puntos ni botón de mute, y muestra Chat / Perfil Completo como acción principal', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RoomUserProfileSheet(
              displayName: 'Miko Kitsune',
              username: 'miko_chan',
              userId: 'u-miko-99',
              isHost: false,
              isSelf: false,
              canManage: false,
            ),
          ),
        ),
      );

      // 1. Botón 3 puntos no debe existir
      expect(find.byIcon(Icons.more_horiz_rounded), findsNothing);
      expect(find.byIcon(Icons.more_vert_rounded), findsNothing);

      // 2. Botón de mute no debe existir
      expect(find.byIcon(Icons.volume_off_rounded), findsNothing);
      expect(find.byIcon(Icons.volume_up_rounded), findsNothing);

      // 3. Botón de icono de perfil pequeño aislado no debe existir
      expect(find.byIcon(Icons.person_outline_rounded), findsNothing);

      // 4. Botón principal "Chat / Perfil Completo" está presente
      expect(find.text('Chat / Perfil Completo'), findsOneWidget);

      // 5. Como canManage es false, no debe haber botón de expulsar
      expect(find.byIcon(Icons.person_remove_rounded), findsNothing);
    });

    testWidgets('Con canManage=true renderiza botón de expulsar junto al botón principal', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RoomUserProfileSheet(
              displayName: 'Kitsune Admin',
              username: 'kitsune_admin',
              userId: 'u-admin-1',
              isHost: true,
              isSelf: false,
              canManage: true,
            ),
          ),
        ),
      );

      expect(find.text('Chat / Perfil Completo'), findsOneWidget);
      expect(find.byIcon(Icons.person_remove_rounded), findsOneWidget);
      expect(find.byIcon(Icons.volume_off_rounded), findsNothing);
      expect(find.byIcon(Icons.more_horiz_rounded), findsNothing);
    });
  });
}
