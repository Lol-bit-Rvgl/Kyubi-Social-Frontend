import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kyubi/core/errors/api_exception.dart';
import 'package:kyubi/core/network/api_client.dart';

void main() {
  group('mapDioException', () {
    RequestOptions opts() => RequestOptions(
          method: 'GET',
          path: '/x',
          baseUrl: 'http://localhost:3000',
        );

    test('timeout de conexión se mapea a ApiExceptionType.timeout', () {
      final exc = DioException(
        requestOptions: opts(),
        type: DioExceptionType.connectionTimeout,
      );
      final mapped = mapDioException(exc);
      expect(mapped, isA<ApiException>());
      expect(mapped.type, ApiExceptionType.timeout);
    });

    test('receiveTimeout se mapea a timeout', () {
      final exc = DioException(
        requestOptions: opts(),
        type: DioExceptionType.receiveTimeout,
      );
      expect(mapDioException(exc).type, ApiExceptionType.timeout);
    });

    test('connectionError se mapea a connectivity', () {
      final exc = DioException(
        requestOptions: opts(),
        type: DioExceptionType.connectionError,
      );
      expect(mapDioException(exc).type, ApiExceptionType.connectivity);
    });

    test('pasa ApiException sin modificar (no la re-mapea)', () {
      final original = ApiException(
        message: 'custom',
        statusCode: 404,
        type: ApiExceptionType.notFound,
      );
      expect(identical(mapDioException(original), original), isTrue);
    });

    test('objeto no-DioException devuelve ApiException de fallback', () {
      final mapped = mapDioException(Object());
      expect(mapped, isA<ApiException>());
      expect(mapped.message, 'Error inesperado');
    });
  });
}