import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyubi/core/errors/api_exception.dart';
import 'package:kyubi/services/auth_controller.dart';

void main() {
  group('Auth Error Handling & Message Extraction', () {
    test('extracts specific message from DioException response data', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/auth/register'),
        response: Response(
          requestOptions: RequestOptions(path: '/auth/register'),
          statusCode: 400,
          data: {
            'error': 'validation_error',
            'message': 'La contraseña debe tener al menos 8 caracteres',
          },
        ),
        type: DioExceptionType.badResponse,
      );

      final message = AuthController.extractErrorMessage(dioException);
      expect(message, 'La contraseña debe tener al menos 8 caracteres');
    });

    test('returns friendly message for 400 bad request without custom message', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/auth/register'),
        response: Response(
          requestOptions: RequestOptions(path: '/auth/register'),
          statusCode: 400,
          data: null,
        ),
        type: DioExceptionType.badResponse,
      );

      final message = AuthController.extractErrorMessage(dioException);
      expect(
        message,
        'Los datos proporcionados no son válidos. Por favor verifícalos.',
      );
    });

    test('returns friendly message for 401 unauthorized credentials', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/auth/login'),
        response: Response(
          requestOptions: RequestOptions(path: '/auth/login'),
          statusCode: 401,
          data: null,
        ),
        type: DioExceptionType.badResponse,
      );

      final message = AuthController.extractErrorMessage(dioException);
      expect(
        message,
        'Credenciales incorrectas. Verifica tu correo y contraseña.',
      );
    });

    test('returns friendly message for 409 conflict (user/email in use)', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/auth/register'),
        response: Response(
          requestOptions: RequestOptions(path: '/auth/register'),
          statusCode: 409,
          data: null,
        ),
        type: DioExceptionType.badResponse,
      );

      final message = AuthController.extractErrorMessage(dioException);
      expect(
        message,
        'El correo electrónico o nombre de usuario ya está registrado.',
      );
    });

    test('sanitizes raw DioException strings that leak into error handlers', () {
      const rawError =
          'DioException [bad response]: The request returned an invalid status code of 400.';

      final message = AuthController.extractErrorMessage(rawError);
      expect(message, 'Ocurrió un error al procesar tu solicitud.');
      expect(message.contains('DioException'), isFalse);
      expect(message.contains('[bad response]'), isFalse);
    });

    test('extracts message cleanly from ApiException', () {
      const apiEx401 = ApiException(
        message: 'Invalid credentials',
        statusCode: 401,
      );
      expect(
        AuthController.extractErrorMessage(apiEx401),
        'Credenciales incorrectas. Verifica tu correo y contraseña.',
      );

      const apiEx409 = ApiException(
        message: 'Conflict',
        statusCode: 409,
      );
      expect(
        AuthController.extractErrorMessage(apiEx409),
        'El correo electrónico o nombre de usuario ya está registrado.',
      );

      const apiExCustom = ApiException(
        message: 'Servicio temporalmente no disponible',
        statusCode: 503,
      );
      expect(
        AuthController.extractErrorMessage(apiExCustom),
        'Servicio temporalmente no disponible',
      );
    });
  });
}
