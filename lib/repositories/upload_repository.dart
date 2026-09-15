import 'dart:typed_data';

import '../core/config/app_config.dart';
import '../core/errors/api_exception.dart';
import '../core/network/api_client.dart';

/// Subida de archivos multimedia al backend.
class UploadRepository {
  UploadRepository(this._api);

  final ApiClient _api;

  /// Sube un archivo y devuelve la URL pública.
  Future<String> uploadFile(
    String kind, {
    required Uint8List bytes,
    required String filename,
    String? contentType,
    void Function(int sent, int total)? onProgress,
  }) async {
    final json = await _api.uploadFile(
      AppConfig.upload(kind),
      bytes: bytes,
      filename: filename,
      contentType: contentType,
      onProgress: onProgress,
    );
    final url = json['url'] as String?;
    if (url == null || url.isEmpty) {
      throw const ApiException(message: 'El servidor no devolvió una URL');
    }
    return url;
  }
}
