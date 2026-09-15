import 'package:flutter/foundation.dart';

import '../core/config/app_config.dart';
import '../core/errors/api_exception.dart';
import '../core/network/api_client.dart';

/// Credenciales del canal de voz LiveKit emitidas por el backend.
class VoiceTokenResult {
  const VoiceTokenResult({
    required this.token,
    required this.url,
    required this.roomName,
  });

  final String token;
  final String url;
  final String roomName;

  factory VoiceTokenResult.fromJson(Map<String, dynamic> json) =>
      VoiceTokenResult(
        token: json['token'] as String? ?? '',
        url: json['url'] as String? ?? '',
        roomName: json['roomName'] as String? ?? '',
      );
}

/// Emisión de tokens de voz (POST /salas/:id/voice/token) para JWT LiveKit.
class VoiceRepository {
  VoiceRepository(this._api);

  final ApiClient _api;

  Future<VoiceTokenResult> roomVoiceToken(String roomId) async {
    final path = AppConfig.salaVoiceToken(roomId);
    debugPrint('[VOICE_REPO] Requesting token for room: $roomId on URL: $path');
    try {
      final json = await _api.postJson(path);
      final result = VoiceTokenResult.fromJson(json);
      debugPrint(
        '[VOICE_REPO] token ok: url=${result.url}, room=${result.roomName}',
      );
      return result;
    } catch (e) {
      if (e is ApiException) {
        debugPrint(
          '[VOICE_REPO] Error response: ${e.statusCode} -> ${e.message}',
        );
      } else {
        debugPrint('[VOICE_REPO] Error: $e');
      }
      rethrow;
    }
  }
}