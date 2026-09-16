import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyubi/models/room.dart';
import 'package:kyubi/models/character.dart';

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

  group('Badge de Actividad Dinámico en Salas (Cine, Roleplay, Voz, Texto)', () {
    (IconData, Color) resolveBadge(Room room) {
      if (room.isScreening) {
        return (Icons.movie_creation_rounded, const Color(0xFFFF3366));
      }
      if (room.isRoleplay) {
        return (Icons.theater_comedy_rounded, const Color(0xFFFFD600));
      }
      if (room.isVoice) {
        return (Icons.mic_rounded, const Color(0xFF00E5FF));
      }
      return (Icons.chat_bubble_rounded, const Color(0xFF8E8EA0));
    }

    test('asigna badge carmesí de cine a salas con video o screening activo', () {
      final room = Room.fromJson({
        'id': 'r-cinema',
        'name': 'Cinema Kyubi',
        'host': {'id': 'h1', 'username': 'host'},
        'cinemaVideoId': 'dQw4w9WgXcQ',
      });
      final (icon, color) = resolveBadge(room);
      expect(icon, Icons.movie_creation_rounded);
      expect(color, const Color(0xFFFF3366));
    });

    test('asigna badge dorado de teatro a salas con stage o roleplay activo', () {
      final room = Room.fromJson({
        'id': 'r-rp',
        'name': 'Reino Medieval',
        'host': {'id': 'h1', 'username': 'host'},
        'currentMode': 'roleplay',
      });
      final (icon, color) = resolveBadge(room);
      expect(icon, Icons.theater_comedy_rounded);
      expect(color, const Color(0xFFFFD600));
    });

    test('asigna badge cyan de micrófono a salas con voz activa', () {
      final room = Room.fromJson({
        'id': 'r-voice',
        'name': 'Podcast Nocturno',
        'host': {'id': 'h1', 'username': 'host'},
        'currentMode': 'voice',
      });
      final (icon, color) = resolveBadge(room);
      expect(icon, Icons.mic_rounded);
      expect(color, const Color(0xFF00E5FF));
    });

    test('asigna badge neutral de chat a salas estándar o en reposo', () {
      final room = Room.fromJson({
        'id': 'r-chat',
        'name': 'Charla General',
        'host': {'id': 'h1', 'username': 'host'},
        'currentMode': 'standard',
      });
      final (icon, color) = resolveBadge(room);
      expect(icon, Icons.chat_bubble_rounded);
      expect(color, const Color(0xFF8E8EA0));
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
