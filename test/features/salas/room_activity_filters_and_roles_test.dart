import 'package:flutter_test/flutter_test.dart';
import 'package:kyubi/models/room.dart';
import 'package:kyubi/models/character.dart';
import 'package:kyubi/models/role_character.dart';

void main() {
  group('Filtros de Actividad en Salas (matchesCategory)', () {
    test('Roleplay: detecta sala por currentMode roleplay', () {
      final room = Room.fromJson({
        'id': 'r1',
        'name': 'Taberna del Dragón',
        'host': {'id': 'h1', 'username': 'host'},
        'currentMode': 'roleplay',
        'participantCount': 4,
      });
      expect(room.isRoleplay, isTrue);
      expect(room.isVoice, isFalse);
      expect(room.isScreening, isFalse);
      expect(room.matchesCategory('Roleplay'), isTrue);
      expect(room.matchesCategory('Voice Chat'), isFalse);
      expect(room.matchesCategory('Screening Room'), isFalse);
    });

    test('Roleplay: detecta sala por stageRoles', () {
      final room = Room.fromJson({
        'id': 'r2',
        'name': 'Mundo Fantasía',
        'host': {'id': 'h1', 'username': 'host'},
        'stageRoles': [
          {'id': 'slot-1', 'name': 'Mago Arcana'},
        ],
        'participantCount': 2,
      });
      expect(room.isRoleplay, isTrue);
      expect(room.matchesCategory('Roleplay'), isTrue);
    });

    test('Screening Room: detecta sala por cinemaVideoId', () {
      final room = Room.fromJson({
        'id': 'r3',
        'name': 'Cine Club Anime',
        'host': {'id': 'h1', 'username': 'host'},
        'cinemaVideoId': 'dQw4w9WgXcQ',
        'participantCount': 8,
      });
      expect(room.isScreening, isTrue);
      expect(room.matchesCategory('Screening Room'), isTrue);
      expect(room.matchesCategory('Cine'), isTrue);
    });

    test('Voice Chat: detecta sala por modo radio/voice o tags', () {
      final room = Room.fromJson({
        'id': 'r4',
        'name': 'Charla Tranquila',
        'host': {'id': 'h1', 'username': 'host'},
        'currentMode': 'voice',
        'participantCount': 5,
      });
      expect(room.isVoice, isTrue);
      expect(room.matchesCategory('Voice Chat'), isTrue);
      expect(room.matchesCategory('Voz'), isTrue);
    });

    test('Tags: detecta sala por tags custom', () {
      final room = Room.fromJson({
        'id': 'r5',
        'name': 'Noche de Juegos',
        'host': {'id': 'h1', 'username': 'host'},
        'tags': ['gaming', 'party'],
        'participantCount': 3,
      });
      expect(room.matchesCategory('gaming'), isTrue);
      expect(room.matchesCategory('party'), isTrue);
      expect(room.matchesCategory('roleplay'), isFalse);
    });
  });

  group('Biblioteca de Roles: Character.toRoleCharacter', () {
    test('convierte Character a RoleCharacter correctamente', () {
      final char = Character(
        id: 'c1',
        userId: 'u1',
        name: 'Kaelen Swift',
        role: 'Asesino de las Sombras',
        avatarUrl: 'https://example.com/kaelen.png',
        bio: 'Misterioso pícaro de las sombras.',
      );

      final role = char.toRoleCharacter(currentUserId: 'u1', currentUsername: 'kaelen');
      expect(role.id, 'c1');
      expect(role.name, 'Kaelen Swift');
      expect(role.tagline, 'Asesino de las Sombras');
      expect(role.avatarUrl, 'https://example.com/kaelen.png');
      expect(role.isTaken, isTrue);
      expect(role.takenByUserId, 'u1');
      expect(role.takenByUsername, 'kaelen');
    });
  });
}
