import '../core/config/app_config.dart';
import '../core/network/api_client.dart';
import '../models/notification_item.dart';

/// Centro de notificaciones (contrato real GET|POST /notifications).
class NotificationRepository {
  NotificationRepository(this._api);

  final ApiClient _api;

  Future<NotificationPage> getNotifications({
    int page = 1,
    int limit = 20,
  }) async {
    final json = await _api.getJson(
      AppConfig.notificationsBase,
      query: {'page': page, 'limit': limit},
    );
    return NotificationPage.fromJson(json);
  }

  /// Marca todas las notificaciones del usuario como leídas.
  Future<void> markAllRead() async {
    await _api.postJson(AppConfig.notificationsBase);
  }

  /// Marca una notificación como leída.
  Future<void> markRead(String id) async {
    await _api.postJson(AppConfig.notificationDetail(id));
  }
}
