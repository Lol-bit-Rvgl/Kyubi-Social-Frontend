import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyubi/features/matchmaking/presentation/matchmaking_controller.dart';
import 'package:kyubi/features/messages/presentation/widgets/match_decision_bar.dart';
import 'package:kyubi/models/chat_conversation.dart';
import 'package:kyubi/services/chat_socket.dart';

void main() {
  group('ChatSocketEvent - Matchmaking Events', () {
    test('ChatMatchFound contiene peer, categoría y conversationId', () {
      final event = ChatMatchFound(
        {'id': 'user-2', 'username': 'peer_user'},
        'Roleplay',
        conversationId: 'conv-101',
      );
      expect(event.conversationId, 'conv-101');
      expect(event.category, 'Roleplay');
      expect(event.peer['username'], 'peer_user');
    });

    test('ChatMatchMutualAccept propaga el conversationId', () {
      final event = ChatMatchMutualAccept('conv-101');
      expect(event.conversationId, 'conv-101');
    });

    test('ChatMatchPeerAccepted propaga conversationId y acceptedByUserId', () {
      final event = ChatMatchPeerAccepted('conv-101', 'user-2');
      expect(event.conversationId, 'conv-101');
      expect(event.acceptedByUserId, 'user-2');
    });

    test('ChatMatchClosed propaga conversationId y motivo', () {
      final event = ChatMatchClosed('conv-101', 'partner_left');
      expect(event.conversationId, 'conv-101');
      expect(event.reason, 'partner_left');
    });
  });

  group('Conversation - Getters de Matchmaking', () {
    test('parsea correctamente una conversación ordinaria (no match)', () {
      final conv = Conversation.fromJson({
        'id': 'conv-1',
        'type': 'DIRECT',
      });
      expect(conv.isMatch, isFalse);
      expect(conv.matchStatus, 'none');
      expect(conv.matchAcceptedBy, isEmpty);
      expect(conv.isMatchAccepted, isFalse);
      expect(conv.isMatchClosed, isFalse);
    });

    test('parsea correctamente un match pendiente con aceptaciones', () {
      final conv = Conversation.fromJson({
        'id': 'conv-2',
        'type': 'DIRECT',
        'extensions': {
          'isMatch': true,
          'status': 'pending',
          'acceptedBy': ['user-1'],
        },
      });
      expect(conv.isMatch, isTrue);
      expect(conv.matchStatus, 'pending');
      expect(conv.matchAcceptedBy, ['user-1']);
      expect(conv.isMatchAcceptedBy('user-1'), isTrue);
      expect(conv.isMatchAcceptedBy('user-2'), isFalse);
      expect(conv.isMatchAccepted, isFalse);
      expect(conv.isMatchClosed, isFalse);
    });

    test('reconoce match mutuamente aceptado', () {
      final conv = Conversation.fromJson({
        'id': 'conv-3',
        'type': 'DIRECT',
        'extensions': {
          'isMatch': true,
          'status': 'accepted',
          'acceptedBy': ['user-1', 'user-2'],
        },
      });
      expect(conv.isMatch, isTrue);
      expect(conv.isMatchAccepted, isTrue);
      expect(conv.isMatchClosed, isFalse);
    });

    test('reconoce match cerrado o abandonado', () {
      final conv = Conversation.fromJson({
        'id': 'conv-4',
        'type': 'DIRECT',
        'extensions': {
          'isMatch': true,
          'status': 'closed',
        },
      });
      expect(conv.isMatch, isTrue);
      expect(conv.isMatchAccepted, isFalse);
      expect(conv.isMatchClosed, isTrue);
    });
  });

  group('MatchState - Estado del Matchmaking Controller', () {
    test('soporta conversationId en el estado y en copyWith', () {
      const state = MatchState(
        status: MatchStatus.matched,
        category: 'Anime',
        conversationId: 'conv-555',
      );
      expect(state.conversationId, 'conv-555');
      expect(state.status, MatchStatus.matched);

      final updated = state.copyWith(conversationId: 'conv-666');
      expect(updated.conversationId, 'conv-666');
      expect(updated.category, 'Anime');
    });
  });

  group('MatchDecisionBar - Widget Rendering y Acciones', () {
    testWidgets('no renderiza nada si conversation.isMatch es false', (tester) async {
      final conv = Conversation.fromJson({
        'id': 'conv-1',
        'type': 'DIRECT',
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MatchDecisionBar(
              conversation: conv,
              myUserId: 'user-1',
              onAccept: () {},
              onReject: () {},
              onNext: () {},
            ),
          ),
        ),
      );

      expect(find.byType(MatchDecisionBar), findsOneWidget);
      expect(find.text('Match Aleatorio en Curso'), findsNothing);
    });

    testWidgets('muestra estado pendiente inicial y responde a Aceptar', (tester) async {
      final conv = Conversation.fromJson({
        'id': 'conv-10',
        'type': 'DIRECT',
        'extensions': {
          'isMatch': true,
          'status': 'pending',
          'acceptedBy': <String>[],
        },
      });

      var accepted = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MatchDecisionBar(
              conversation: conv,
              myUserId: 'user-1',
              onAccept: () => accepted = true,
              onReject: () {},
              onNext: () {},
            ),
          ),
        ),
      );

      expect(find.text('Match Aleatorio en Curso'), findsOneWidget);
      expect(find.text('¿Deseas conservar esta conversación?'), findsOneWidget);
      expect(find.text('Aceptar'), findsOneWidget);
      expect(find.text('Siguiente'), findsOneWidget);

      await tester.tap(find.text('Aceptar'));
      await tester.pump();
      expect(accepted, isTrue);
    });

    testWidgets('muestra estado de espera cuando ya acepté pero el compañero no', (tester) async {
      final conv = Conversation.fromJson({
        'id': 'conv-11',
        'type': 'DIRECT',
        'extensions': {
          'isMatch': true,
          'status': 'pending',
          'acceptedBy': ['user-1'],
        },
      });

      var rejected = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MatchDecisionBar(
              conversation: conv,
              myUserId: 'user-1',
              onAccept: () {},
              onReject: () => rejected = true,
              onNext: () {},
            ),
          ),
        ),
      );

      expect(find.text('Esperando a que tu compañero acepte...'), findsOneWidget);
      expect(find.text('Salir'), findsOneWidget);

      await tester.tap(find.text('Salir'));
      await tester.pump();
      expect(rejected, isTrue);
    });

    testWidgets('muestra banner celebratorio cuando el match fue aceptado mutuamente', (tester) async {
      final conv = Conversation.fromJson({
        'id': 'conv-12',
        'type': 'DIRECT',
        'extensions': {
          'isMatch': true,
          'status': 'accepted',
          'acceptedBy': ['user-1', 'user-2'],
        },
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MatchDecisionBar(
              conversation: conv,
              myUserId: 'user-1',
              onAccept: () {},
              onReject: () {},
              onNext: () {},
            ),
          ),
        ),
      );

      expect(find.text('¡Conexión mutua establecida! 🎉'), findsOneWidget);
      expect(find.text('Ahora son amigos permanentes en Kyubi.'), findsOneWidget);
    });

    testWidgets('muestra aviso y acción para buscar otro cuando el match está cerrado', (tester) async {
      final conv = Conversation.fromJson({
        'id': 'conv-13',
        'type': 'DIRECT',
        'extensions': {
          'isMatch': true,
          'status': 'closed',
        },
      });

      var nextCalled = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MatchDecisionBar(
              conversation: conv,
              myUserId: 'user-1',
              onAccept: () {},
              onReject: () {},
              onNext: () => nextCalled = true,
            ),
          ),
        ),
      );

      expect(find.text('Este match aleatorio ha finalizado.'), findsOneWidget);
      expect(find.text('Buscar otro'), findsOneWidget);

      await tester.tap(find.text('Buscar otro'));
      await tester.pump();
      expect(nextCalled, isTrue);
    });
  });
}
