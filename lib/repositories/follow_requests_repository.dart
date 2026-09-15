import '../core/config/app_config.dart';
import '../core/network/api_client.dart';
import '../models/user.dart';

/// Resultado paginado de solicitudes de seguimiento entrantes.
class FollowRequestPage {
  const FollowRequestPage({required this.items, this.nextCursor});

  final List<FollowRequestItem> items;
  final String? nextCursor;

  factory FollowRequestPage.fromJson(Map<String, dynamic> json) =>
      FollowRequestPage(
        items: (json['items'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(FollowRequestItem.fromJson)
            .toList(),
        nextCursor: json['nextCursor'] as String?,
      );
}

/// Solicitudes de seguimiento pendientes (follow con aprobación).
class FollowRequestsRepository {
  FollowRequestsRepository(this._api);

  final ApiClient _api;

  Future<FollowRequestPage> getFollowRequests({
    String? cursor,
    int limit = 20,
  }) async {
    final json = await _api.getJson(
      AppConfig.followRequestsBase,
      query: <String, dynamic>{'cursor': ?cursor, 'limit': limit},
    );
    return FollowRequestPage.fromJson(json);
  }

  /// Acepta o rechaza una solicitud entrante.
  /// Devuelve el nuevo recuento de seguidores del usuario (si el backend lo envía).
  Future<int?> respond(String requestId, {required bool accept}) async {
    final json = await _api.postJson(
      AppConfig.followRequestRespond(requestId),
      data: {'action': accept ? 'accept' : 'reject'},
    );
    return (json['followersCount'] as num?)?.toInt();
  }
}
