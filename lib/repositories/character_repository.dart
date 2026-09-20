import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_client.dart';
import '../models/character.dart';
import '../services/providers.dart';

final characterRepositoryProvider = Provider<CharacterRepository>(
  (ref) => CharacterRepository(ref.watch(apiClientProvider)),
);

/// Repositorio de Fichas de Personaje / Original Characters (OCs).
class CharacterRepository {
  CharacterRepository(this._client);

  final ApiClient _client;

  Future<List<Character>> getUserCharacters(String userId) async {
    try {
      final json = await _client.getJson('/users/$userId/characters');
      final data = json['data'] ?? json['characters'];
      if (data is List) {
        return data
            .map((item) => Character.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return const [];
    } catch (_) {
      // Fallback local en caso de que el endpoint backend esté en proceso
      return [
        Character(
          id: 'oc-sample-1',
          userId: userId,
          name: 'Kyubi Knight',
          avatarUrl:
              'https://images.unsplash.com/photo-1578632767115-351597cf2477?w=150',
          role: 'Guerrero',
          species: 'Kitsune',
          age: '19',
          gender: 'Masculino',
          alignment: 'Caótico Bueno',
          personality: 'Valiente, leal, algo impulsivo pero con gran honor.',
          background:
              'Entrenado en el santuario de las nueve colas para proteger el equilibrio dimensional.',
          abilities: const [
            'Fuego Fatuo',
            'Corte Espiritual',
            'Teletransporte',
          ],
        ),
      ];
    }
  }

  /// Obtiene las fichas de personaje creadas por el usuario autenticado.
  Future<List<Character>> getMyRoles() async {
    try {
      final json = await _client.getJson('/characters/mine');
      final data = json['data'] ?? json['characters'] ?? json['roles'];
      if (data is List) {
        return data
            .map((item) => Character.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {
      // Fallback a /users/me/characters
    }
    return getUserCharacters('me');
  }

  Future<Character> createCharacter(Map<String, dynamic> body) async {
    final json = await _client.postJson('/characters', data: body);
    final data = json['data'] ?? json;
    return Character.fromJson(data as Map<String, dynamic>);
  }

  Future<Character> updateCharacter(
    String id,
    Map<String, dynamic> body,
  ) async {
    final json = await _client.patchJson('/characters/$id', data: body);
    final data = json['data'] ?? json;
    return Character.fromJson(data as Map<String, dynamic>);
  }

  Future<void> deleteCharacter(String id) async {
    await _client.deleteJson('/characters/$id');
  }
}
