import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyubi/features/messages/presentation/conversation_controller.dart';
import 'package:kyubi/features/messages/presentation/conversation_info_screen.dart';
import 'package:kyubi/models/chat_conversation.dart';
import 'package:kyubi/models/chat_message.dart';
import 'package:kyubi/models/user.dart';
import 'package:kyubi/services/auth_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

class _FakeConversationChatNotifier extends ConversationChatNotifier {
  _FakeConversationChatNotifier(this._initial);
  final ConversationChatState _initial;

  @override
  ConversationChatState build(String arg) => _initial;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const convId = 'conv_dm_456';
  const myId = 'user_me_123';
  const otherId = 'user_other_789';

  final currentUser = const User(
    id: myId,
    username: 'naruto',
    displayName: 'Naruto Uzumaki',
    avatarUrl: 'https://example.com/naruto.png',
  );

  final otherMember = const ChatMember(
    id: 'member_other',
    username: 'sasuke',
    displayName: 'Sasuke Uchiha',
    avatarUrl: 'https://example.com/sasuke.png',
    isOnline: true,
  );

  final testConversation = Conversation(
    id: convId,
    type: 'direct',
    members: [otherMember],
    otherMember: const ChatAuthor(
      id: otherId,
      username: 'sasuke',
      displayName: 'Sasuke Uchiha',
      avatarUrl: 'https://example.com/sasuke.png',
      isOnline: true,
    ),
    extensions: const {'streakDays': 5},
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'chat_bg_$convId': 'assets/images/backgrounds/jay_sen_1.png',
    });
  });

  group('ConversationInfoScreen - Estructura Visual y Secciones', () {
    testWidgets(
      '1. Renderiza Cabecera de Usuario y Tarjeta de Fondo del Chat',
      (tester) async {
        final state = ConversationChatState(
          conversation: testConversation,
          messages: const [],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authControllerProvider.overrideWith(
                () => _FakeAuthNotifier(currentUser),
              ),
              conversationChatProvider.overrideWith(
                () => _FakeConversationChatNotifier(state),
              ),
            ],
            child: const MaterialApp(
              home: ConversationInfoScreen(conversationId: convId),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Cabecera de identidad
        expect(find.text('Sasuke Uchiha'), findsWidgets);
        expect(find.text('@sasuke'), findsWidgets);
        expect(find.text('Ver perfil completo'), findsOneWidget);

        // Tarjeta de fondo de chat
        expect(find.text('Fondo del chat'), findsOneWidget);
        expect(find.text('Personaliza el wallpaper...'), findsOneWidget);
        expect(find.text('Cambiar'), findsOneWidget);
      },
    );

    testWidgets(
      '2. Renderiza Sección de Gamificación (Insignia central, racha y progreso)',
      (tester) async {
        final state = ConversationChatState(
          conversation: testConversation,
          messages: const [],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authControllerProvider.overrideWith(
                () => _FakeAuthNotifier(currentUser),
              ),
              conversationChatProvider.overrideWith(
                () => _FakeConversationChatNotifier(state),
              ),
            ],
            child: const MaterialApp(
              home: ConversationInfoScreen(conversationId: convId),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Racha de 5 días -> Nivel 2 (Gorro de Mago)
        expect(
          find.text('Racha de amistad: 5 días (Nivel 2) — Gorro de Mago'),
          findsOneWidget,
        );
        expect(
          find.text('5 días consecutivos enviándose mensajes'),
          findsOneWidget,
        );
        // Faltan 10 días para Nivel 3 (15 - 5 = 10)
        expect(
          find.text('Faltan 10 días para desbloquear el Nivel 3'),
          findsOneWidget,
        );
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
      },
    );

    testWidgets(
      '3. Renderiza fallback cuando no hay fotos compartidas',
      (tester) async {
        final emptyState = ConversationChatState(
          conversation: testConversation,
          messages: const [],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authControllerProvider.overrideWith(
                () => _FakeAuthNotifier(currentUser),
              ),
              conversationChatProvider.overrideWith(
                () => _FakeConversationChatNotifier(emptyState),
              ),
            ],
            child: const MaterialApp(
              home: ConversationInfoScreen(conversationId: convId),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Multimedia'), findsOneWidget);
        expect(find.text('No hay fotos compartidas'), findsOneWidget);
      },
    );

    testWidgets(
      '4. Renderiza carrusel multimedia cuando hay fotos compartidas',
      (tester) async {
        final messageWithImage = Message(
          id: 'msg_img_1',
          conversationId: convId,
          senderId: myId,
          sender: const ChatAuthor(
            id: myId,
            username: 'naruto',
            displayName: 'Naruto Uzumaki',
          ),
          body: '',
          mediaUrl: 'https://example.com/ramen.png',
          mediaType: 'image',
          createdAt: DateTime.now(),
        );

        final stateWithImages = ConversationChatState(
          conversation: testConversation,
          messages: [messageWithImage],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authControllerProvider.overrideWith(
                () => _FakeAuthNotifier(currentUser),
              ),
              conversationChatProvider.overrideWith(
                () => _FakeConversationChatNotifier(stateWithImages),
              ),
            ],
            child: const MaterialApp(
              home: ConversationInfoScreen(conversationId: convId),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Multimedia'), findsOneWidget);
        expect(find.text('No hay fotos compartidas'), findsNothing);
        expect(find.text('1'), findsOneWidget);
      },
    );

    testWidgets(
      '5. Renderiza Participantes y Diálogo Modal al presionar Eliminar Conversación',
      (tester) async {
        final state = ConversationChatState(
          conversation: testConversation,
          messages: const [],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authControllerProvider.overrideWith(
                () => _FakeAuthNotifier(currentUser),
              ),
              conversationChatProvider.overrideWith(
                () => _FakeConversationChatNotifier(state),
              ),
            ],
            child: const MaterialApp(
              home: ConversationInfoScreen(conversationId: convId),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Participantes
        expect(find.text('Participantes'), findsOneWidget);
        expect(find.text('Tú'), findsWidgets);
        expect(find.text('Naruto Uzumaki'), findsOneWidget);
        expect(find.text('Sasuke Uchiha'), findsWidgets);

        // Botón destructivo
        final deleteBtn = find.text('Eliminar conversación');
        expect(deleteBtn, findsOneWidget);

        // Tap en el botón
        await tester.ensureVisible(deleteBtn);
        await tester.tap(deleteBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Diálogo de confirmación modal
        expect(
          find.text(
            '¿Deseas eliminar esta conversación? Los mensajes se borrarán de tu bandeja.',
          ),
          findsOneWidget,
        );
        expect(find.text('Cancelar'), findsOneWidget);
        expect(find.text('Eliminar'), findsOneWidget);

        // Cancelar cierra el diálogo
        await tester.tap(find.text('Cancelar'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(
          find.text(
            '¿Deseas eliminar esta conversación? Los mensajes se borrarán de tu bandeja.',
          ),
          findsNothing,
        );
      },
    );
  });
}
