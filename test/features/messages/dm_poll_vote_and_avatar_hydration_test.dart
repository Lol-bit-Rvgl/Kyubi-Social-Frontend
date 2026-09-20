import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyubi/core/storage/session_store.dart';
import 'package:kyubi/core/widgets/chat_bubble.dart';
import 'package:kyubi/features/feed/presentation/widgets/interactive_poll_card.dart';
import 'package:kyubi/models/user.dart';
import 'package:kyubi/repositories/auth_repository.dart';

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.userToReturn});
  User? userToReturn;

  @override
  Future<User> me() async {
    if (userToReturn != null) return userToReturn!;
    throw Exception('Error de red al consultar me()');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('1. InteractivePollCard - Recálculo dinámico y UI optimista', () {
    testWidgets(
      'Al votar con totalVotesCount: 0, actualiza a 1 voto y 100% de inmediato',
      (tester) async {
        String? votedOptionId;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: InteractivePollCard(
                question: '¿Cuál es tu color favorito?',
                totalVotesCount: 0,
                options: const [
                  PollOptionData(id: 'opt_1', text: 'Azul', votes: 0),
                  PollOptionData(id: 'opt_2', text: 'Rojo', votes: 0),
                ],
                onVote: (optId) {
                  votedOptionId = optId;
                },
              ),
            ),
          ),
        );

        // Inicialmente 0 votos
        expect(find.text('0 votos'), findsOneWidget);
        expect(find.text('Toca para votar'), findsOneWidget);
        expect(find.text('100%'), findsNothing);

        // Tocar opción 1 (Azul)
        await tester.tap(find.text('Azul'));
        await tester.pumpAndSettle();

        // Callback disparado
        expect(votedOptionId, 'opt_1');

        // La UI optimista debe mostrar 1 voto, Has votado y 100% (NO quedarse en 0 votos y 0%)
        expect(find.text('1 voto'), findsOneWidget);
        expect(find.text('Has votado'), findsOneWidget);
        expect(find.text('100%'), findsOneWidget);
        expect(find.text('0%'), findsOneWidget); // Para la opción no elegida
      },
    );

    testWidgets(
      'Muestra estado previo si el usuario ya votó',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: InteractivePollCard(
                question: '¿Pizza o Hamburguesa?',
                totalVotesCount: 5,
                userVotedOptionId: 'opt_1',
                options: [
                  PollOptionData(id: 'opt_1', text: 'Pizza', votes: 4),
                  PollOptionData(id: 'opt_2', text: 'Hamburguesa', votes: 1),
                ],
              ),
            ),
          ),
        );

        expect(find.text('5 votos'), findsOneWidget);
        expect(find.text('Has votado'), findsOneWidget);
        expect(find.text('80%'), findsOneWidget);
        expect(find.text('20%'), findsOneWidget);
        expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      },
    );
  });

  group('2. ChatMessageBubble y DirectChatMessageBubble - Integración de Encuesta', () {
    testWidgets(
      'ChatMessageBubble pasa onPollVote y currentUserId correctamente',
      (tester) async {
        String? selectedOptionId;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ChatMessageBubble(
                displayName: 'Amigo',
                body: '📊 Encuesta: ¿Jugamos?',
                timestamp: '14:30',
                mediaType: 'poll',
                currentUserId: 'user-me',
                extensions: const {
                  'poll': {
                    'question': '¿Jugamos?',
                    'options': [
                      {'id': 'opt_1', 'text': 'Ahora', 'votes': 0},
                      {'id': 'opt_2', 'text': 'Más tarde', 'votes': 0},
                    ],
                    'totalVotes': 0,
                    'votes': <String, dynamic>{},
                  },
                },
                onPollVote: (optId) {
                  selectedOptionId = optId;
                },
              ),
            ),
          ),
        );

        expect(find.byType(InteractivePollCard), findsOneWidget);
        expect(find.text('¿Jugamos?'), findsOneWidget);
        expect(find.text('0 votos'), findsOneWidget);

        // Votar opción 1
        await tester.tap(find.text('Ahora'));
        await tester.pumpAndSettle();

        expect(selectedOptionId, 'opt_1');
        expect(find.text('1 voto'), findsOneWidget);
        expect(find.text('100%'), findsOneWidget);
      },
    );

    testWidgets(
      'ChatMessageBubble detecta opción votada previamente por currentUserId',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: ChatMessageBubble(
                displayName: 'Amigo',
                body: '📊 Encuesta: ¿Comida?',
                timestamp: '14:30',
                mediaType: 'poll',
                currentUserId: 'user-123',
                extensions: {
                  'poll': {
                    'question': '¿Comida?',
                    'options': [
                      {'id': 'opt_tacos', 'text': 'Tacos', 'votes': 2},
                      {'id': 'opt_pasta', 'text': 'Pasta', 'votes': 1},
                    ],
                    'totalVotes': 3,
                    'votes': {
                      'user-123': 'opt_tacos',
                      'user-456': 'opt_tacos',
                      'user-789': 'opt_pasta',
                    },
                  },
                },
              ),
            ),
          ),
        );

        expect(find.text('Has votado'), findsOneWidget);
        expect(find.text('3 votos'), findsOneWidget);
        expect(find.text('67%'), findsOneWidget);
        expect(find.text('33%'), findsOneWidget);
        expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      },
    );
  });

  group('3. Hidratación de Sesión y Avatar en Frame 0', () {
    test('LastUserStorage guarda y recupera avatarUrl y perfil completo', () async {
      const user = User(
        id: 'user-001',
        username: 'kyubi_fox',
        displayName: 'Kyubi Fox',
        avatarUrl: 'https://cdn.kyubi.app/avatars/user-001.webp',
        extensions: {'coins': 250},
      );

      await LastUserStorage.save(user.toJson());
      final cachedJson = await LastUserStorage.read();

      expect(cachedJson, isNotNull);
      final restored = User.fromJson(cachedJson!);
      expect(restored.id, 'user-001');
      expect(restored.avatarUrl, 'https://cdn.kyubi.app/avatars/user-001.webp');
      expect(restored.effectiveAvatarUrl, 'https://cdn.kyubi.app/avatars/user-001.webp');
      expect(restored.coins, 250);
    });

    test('SessionRepository.restoreUser() persiste me() en LastUserStorage y soporta fallback', () async {
      await TokenStorage.saveTokens(accessToken: 'valid-acc', refreshToken: 'valid-ref');

      const fullUser = User(
        id: 'user-002',
        username: 'shinobi',
        displayName: 'Shinobi',
        avatarUrl: 'https://cdn.kyubi.app/avatars/shinobi.webp',
        extensions: {'coins': 999},
      );

      final fakeAuth = _FakeAuthRepository(userToReturn: fullUser);
      final repo = SessionRepository(fakeAuth);

      final result = await repo.restoreUser();
      expect(result, isNotNull);
      expect(result!.avatarUrl, 'https://cdn.kyubi.app/avatars/shinobi.webp');

      // Verificar que se guardó en LastUserStorage
      final storedJson = await LastUserStorage.read();
      expect(storedJson, isNotNull);
      expect(storedJson!['avatarUrl'], 'https://cdn.kyubi.app/avatars/shinobi.webp');

      // Ahora simular fallo de red: debe recurrir a la caché guardada
      fakeAuth.userToReturn = null; // Fuerza excepción
      final fallbackResult = await repo.restoreUser();
      expect(fallbackResult, isNotNull);
      expect(fallbackResult!.avatarUrl, 'https://cdn.kyubi.app/avatars/shinobi.webp');
    });
  });
}
