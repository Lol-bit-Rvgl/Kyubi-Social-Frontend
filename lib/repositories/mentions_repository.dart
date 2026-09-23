import '../core/config/app_config.dart';
import '../core/network/api_client.dart';
import '../models/mention_item.dart';

/// Repositorio de menciones pendientes (@Mentions).
class MentionsRepository {
  MentionsRepository(this._api);

  final ApiClient _api;

  /// Obtiene las menciones del usuario autenticado.
  /// Por defecto (`all: false`), retorna únicamente las menciones pendientes (no leídas).
  Future<List<MentionItem>> getMentions({
    bool all = false,
    int page = 1,
    int limit = 30,
  }) async {
    final json = await _api.getJson(
      AppConfig.usersMeMentions,
      query: {
        'all': all,
        'page': page,
        'limit': limit,
      },
    );
    final raw = json['data'];
    if (raw is List) {
      return raw
          .whereType<Map<String, dynamic>>()
          .map(MentionItem.fromJson)
          .toList();
    }
    return const [];
  }

  /// Marca una mención puntual como leída.
  Future<void> markRead(String mentionId) async {
    await _api.patchJson(
      AppConfig.usersMeMentions,
      data: {'id': mentionId},
    );
  }

  /// Marca todas las menciones del usuario como leídas.
  Future<void> markAllRead() async {
    await _api.patchJson(
      AppConfig.usersMeMentions,
      data: {'all': true},
    );
  }
}
