import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyubi/core/constants/app_assets.dart';
import 'package:kyubi/core/widgets/liquid_glass_button.dart';
import 'package:kyubi/core/widgets/state_views.dart';
import 'package:kyubi/features/messages/presentation/conversation_controller.dart';
import 'package:kyubi/features/messages/presentation/conversation_screen.dart';
import 'package:kyubi/features/messages/presentation/conversations_controller.dart';
import 'package:kyubi/features/messages/presentation/follow_requests_controller.dart';
import 'package:kyubi/features/messages/presentation/mentions_controller.dart';
import 'package:kyubi/features/messages/presentation/widgets/follow_requests_list.dart';
import 'package:kyubi/features/salas/presentation/room_invites_controller.dart';
import 'package:kyubi/models/user.dart';
import 'package:kyubi/services/auth_controller.dart';
import 'package:kyubi/features/messages/presentation/messages_screen.dart';
import 'package:kyubi/features/salas/presentation/salas_controller.dart';
import 'package:kyubi/models/post_author.dart';
import 'package:kyubi/models/room.dart';

void main() {
  group('AppAssets - Constantes de Assets Oficiales de Estados Vacíos', () {
    test('Define las rutas correctas para los assets oficiales de diseño', () {
      expect(AppAssets.iconSolicitudesChat, 'assets/icons/Solicitudes chat_.jpg');
      expect(AppAssets.iconMenciones, 'assets/icons/Opción de menciones 1.jpg');
      expect(AppAssets.iconSalasVacias, 'assets/icons/Salas_.jpg');
      expect(AppAssets.iconMensajesVacios, 'assets/icons/Mensajes_.jpg');

      // Aliases
      expect(AppAssets.emptyStateSolicitudes, 'assets/icons/Solicitudes chat_.jpg');
      expect(AppAssets.emptyStateMenciones, 'assets/icons/Opción de menciones 1.jpg');
      expect(AppAssets.emptyStateSalas, 'assets/icons/Salas_.jpg');
      expect(AppAssets.emptyStateMensajes, 'assets/icons/Mensajes_.jpg');
    });
  });

  group('EmptyView - Renderizado con ImageWidget, Aura Glow y LiquidGlassButton', () {
    testWidgets('EmptyView renderiza imageWidget con aura/glow cósmico y sin color magenta', (tester) async {
      bool actionTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFD100D1), // Magenta legado para verificar sustitución
            ),
          ),
          home: Scaffold(
            body: EmptyView(
              imageWidget: Image.asset(
                AppAssets.iconMensajesVacios,
                width: 90,
                height: 90,
                fit: BoxFit.contain,
              ),
              title: 'Sin conversaciones directas',
              message: 'Inicia un chat desde el perfil de cualquier usuario.',
              actionLabel: 'Buscar usuarios',
              onAction: () => actionTapped = true,
            ),
          ),
        ),
      );

      // Verificación de textos
      expect(find.text('Sin conversaciones directas'), findsOneWidget);
      expect(find.text('Inicia un chat desde el perfil de cualquier usuario.'), findsOneWidget);

      // Verificación de imageWidget (Image.asset oficial)
      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);
      final imageWidget = tester.widget<Image>(imageFinder);
      expect(imageWidget.image, isA<AssetImage>());
      expect((imageWidget.image as AssetImage).assetName, AppAssets.iconMensajesVacios);
      expect(imageWidget.width, 90);
      expect(imageWidget.height, 90);

      // Verificación de LiquidGlassButton
      expect(find.byType(LiquidGlassButton), findsOneWidget);
      expect(find.text('Buscar usuarios'), findsOneWidget);

      final button = tester.widget<LiquidGlassButton>(find.byType(LiquidGlassButton));
      expect(button.borderRadius, 18.0);
      expect(button.customGradient, isNotNull);

      // Verificar que el gradiente NO sea magenta (#D100D1 / #FF007F)
      final colors = button.customGradient!.colors;
      expect(colors.contains(const Color(0xFFD100D1)), isFalse);
      expect(colors.contains(const Color(0xFFFF007F)), isFalse);
      expect(colors.first, const Color(0xFFBA68C8)); // Morado cósmico

      // Verificar que el tap ejecute onAction
      await tester.tap(find.byType(LiquidGlassButton));
      expect(actionTapped, isTrue);
    });
  });

  group('Módulo de Mensajes - Estados Vacíos con Assets Oficiales', () {
    testWidgets('FollowRequestsList muestra asset oficial de Solicitudes chat_', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            followRequestsControllerProvider.overrideWith(
              () => _MockFollowRequestsNotifier(const FollowRequestsState(items: [], loading: false)),
            ),
            conversationsControllerProvider.overrideWith(
              () => _MockConversationsNotifier(const ConversationsState(conversations: [], loading: false)),
            ),
            roomInvitesControllerProvider.overrideWith(
              () => _MockRoomInvitesNotifier(const RoomInvitesState(invites: [], loading: false)),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: FollowRequestsList(),
            ),
          ),
        ),
      );

      expect(find.text('Sin invitaciones pendientes'), findsOneWidget);

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);
      final imageWidget = tester.widget<Image>(imageFinder);
      expect((imageWidget.image as AssetImage).assetName, AppAssets.iconSolicitudesChat);
      expect(imageWidget.width, 90);
      expect(imageWidget.height, 90);
    });

    testWidgets('ConversationScreen vacío muestra asset oficial de Mensajes_', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            conversationChatProvider.overrideWith(
              () => _MockConversationChatNotifier(const ConversationChatState(messages: [], loading: false)),
            ),
            authControllerProvider.overrideWith(
              () => _MockAuthNotifier(),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ConversationScreen(conversationId: 'conv-1'),
            ),
          ),
        ),
      );

      expect(find.text('Sin mensajes'), findsOneWidget);

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);
      final imageWidget = tester.widget<Image>(imageFinder);
      expect((imageWidget.image as AssetImage).assetName, AppAssets.iconMensajesVacios);
      expect(imageWidget.width, 90);
      expect(imageWidget.height, 90);
    });
  });

  group('MessagesScreen - Layout Anclado sin NestedScrollView', () {
    testWidgets('Header, barra de búsqueda y TabBar permanecen anclados en Column', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(() => _MockAuthNotifier()),
            conversationsControllerProvider.overrideWith(
              () => _MockConversationsNotifier(
                const ConversationsState(loading: false, conversations: []),
              ),
            ),
            followRequestsControllerProvider.overrideWith(
              () => _MockFollowRequestsNotifier(
                const FollowRequestsState(loading: false, items: []),
              ),
            ),
            salasControllerProvider.overrideWith(
              () => _MockSalasNotifier(),
            ),
            roomInvitesControllerProvider.overrideWith(
              () => _MockRoomInvitesNotifier(
                const RoomInvitesState(loading: false, invites: []),
              ),
            ),
            mentionsControllerProvider.overrideWith(
              () => _MockMentionsNotifier(),
            ),
          ],
          child: const MaterialApp(
            home: MessagesScreen(),
          ),
        ),
      );

      // Verificamos que no exista NestedScrollView
      expect(find.byType(NestedScrollView), findsNothing);

      // Verificamos que los componentes principales estén montados dentro de Column
      expect(find.byType(TabBarView), findsOneWidget);
      expect(find.text('My Chats'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byType(TabBar), findsOneWidget);
    });
  });

  group('SalasState.activeRoomsForUser - Separación Estricta Rooms vs Invites', () {
    const currentUserId = 'user-current';
    const hostUser = PostAuthor(
      id: 'user-host',
      username: 'host_user',
      displayName: 'Host User',
    );
    const currentUserAuthor = PostAuthor(
      id: currentUserId,
      username: 'current_user',
      displayName: 'Current User',
    );

    test('Excluye estrictamente salas donde el usuario tiene rol INVITED', () {
      final invitedRoom = Room(
        id: 'room-invited-1',
        name: 'Sala Secreta VIP',
        host: hostUser,
        access: RoomAccess.private,
        participants: [
          RoomParticipant(
            user: currentUserAuthor,
            role: 'INVITED',
            joinedAt: '2026-09-18T20:00:00.000Z',
          ),
        ],
      );

      final state = SalasState(rooms: [invitedRoom]);
      final activeRooms = state.activeRoomsForUser(currentUserId);

      expect(activeRooms, isEmpty);
    });

    test('Incluye salas donde el usuario es el Host', () {
      final hostRoom = Room(
        id: 'room-host-1',
        name: 'Mi Sala Propia',
        host: currentUserAuthor,
        isHost: true,
      );

      final state = SalasState(rooms: [hostRoom]);
      final activeRooms = state.activeRoomsForUser(currentUserId);

      expect(activeRooms, hasLength(1));
      expect(activeRooms.first.id, 'room-host-1');
    });

    test('Incluye salas donde el usuario es PARTICIPANT activo', () {
      final joinedRoom = Room(
        id: 'room-joined-1',
        name: 'Sala de Música',
        host: hostUser,
        participants: [
          RoomParticipant(
            user: currentUserAuthor,
            role: 'PARTICIPANT',
            joinedAt: '2026-09-18T19:00:00.000Z',
          ),
        ],
      );

      final state = SalasState(rooms: [joinedRoom]);
      final activeRooms = state.activeRoomsForUser(currentUserId);

      expect(activeRooms, hasLength(1));
      expect(activeRooms.first.id, 'room-joined-1');
    });
  });

  group('FollowRequestsList & RoomInvitesList - Renderizado Directo de Invitaciones', () {
    const host = PostAuthor(
      id: 'host-1',
      username: 'eprin',
      displayName: 'Eprin Host',
    );

    testWidgets('Muestra RoomInvitesList cuando hay invitaciones y 0 follow requests (sin falso empty view)', (tester) async {
      const privateRoom = Room(
        id: 'room-priv-1',
        name: 'Cueva de Rol',
        host: host,
        access: RoomAccess.private,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(
              () => _MockAuthNotifier(),
            ),
            followRequestsControllerProvider.overrideWith(
              () => _MockFollowRequestsNotifier(
                const FollowRequestsState(loading: false, items: []),
              ),
            ),
            conversationsControllerProvider.overrideWith(
              () => _MockConversationsNotifier(
                const ConversationsState(loading: false, conversations: []),
              ),
            ),
            roomInvitesControllerProvider.overrideWith(
              () => _MockRoomInvitesNotifier(
                const RoomInvitesState(loading: false, invites: [privateRoom]),
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: FollowRequestsList(),
            ),
          ),
        ),
      );

      // No debe mostrar el empty state
      expect(find.text('Sin invitaciones pendientes'), findsNothing);

      // Debe mostrar la sección de invitaciones a salas y el badge con 🥀
      expect(find.text('Invitaciones a Salas'), findsOneWidget);
      expect(find.text('Cueva de Rol'), findsOneWidget);
      expect(find.text('🥀'), findsOneWidget);
      expect(find.text('Invitado por @eprin'), findsOneWidget);

      // Debe renderizar los botones de Aceptar y Rechazar
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    });
  });
}

// ── Notificadores simulados para las pruebas ──

class _MockFollowRequestsNotifier extends FollowRequestsNotifier {
  _MockFollowRequestsNotifier(this._initialState);
  final FollowRequestsState _initialState;

  @override
  FollowRequestsState build() => _initialState;
}

class _MockConversationsNotifier extends ConversationsNotifier {
  _MockConversationsNotifier(this._initialState);
  final ConversationsState _initialState;

  @override
  ConversationsState build() => _initialState;
}

class _MockConversationChatNotifier extends ConversationChatNotifier {
  _MockConversationChatNotifier(this._initialState);
  final ConversationChatState _initialState;

  @override
  ConversationChatState build(String conversationId) => _initialState;
}

class _MockAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => AuthState(
        user: const User(
          id: 'user-1',
          username: 'tester',
          email: 'test@kyubi.app',
          displayName: 'Tester',
        ),
      );
}

class _MockSalasNotifier extends SalasNotifier {
  @override
  SalasState build() => const SalasState(loading: false, rooms: []);
}

class _MockRoomInvitesNotifier extends RoomInvitesNotifier {
  _MockRoomInvitesNotifier([this._initialState = const RoomInvitesState(loading: false, invites: [])]);
  final RoomInvitesState _initialState;

  @override
  RoomInvitesState build() => _initialState;
}

class _MockMentionsNotifier extends MentionsNotifier {
  @override
  MentionsState build() => const MentionsState();
}
