import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:kyubi/services/base_socket.dart';

String createMockJwt({required int expSecondsFromNow}) {
  final header = base64Url
      .encode(utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'})))
      .replaceAll('=', '');
  final exp = (DateTime.now().millisecondsSinceEpoch ~/ 1000) + expSecondsFromNow;
  final payload = base64Url
      .encode(utf8.encode(jsonEncode({'sub': 'test-user', 'exp': exp})))
      .replaceAll('=', '');
  final signature = base64Url.encode(utf8.encode('signature')).replaceAll('=', '');
  return '$header.$payload.$signature';
}

class TestSocketEvent {
  TestSocketEvent(this.name);
  final String name;
}

class MockSocketService extends BaseSocket<TestSocketEvent> {
  MockSocketService() : super(serviceName: 'test_socket');

  @override
  void registerCustomEvents(io.Socket socket) {}
}

void main() {
  group('BaseSocket - Validación de JWT y Ciclo de Vida', () {
    test('isTokenExpired detecta tokens válidos y con vigencia suficiente', () {
      final validToken = createMockJwt(expSecondsFromNow: 3600); // 1 hora en el futuro
      expect(BaseSocket.isTokenExpired(validToken), isFalse);
    });

    test('isTokenExpired detecta tokens ya expirados', () {
      final expiredToken = createMockJwt(expSecondsFromNow: -10); // 10s en el pasado
      expect(BaseSocket.isTokenExpired(expiredToken), isTrue);
    });

    test('isTokenExpired detecta tokens dentro del margen preventivo de 30s', () {
      final expiringSoonToken = createMockJwt(expSecondsFromNow: 15); // Expira en 15s
      expect(BaseSocket.isTokenExpired(expiringSoonToken), isTrue);
    });

    test('isTokenExpired retorna true ante tokens corruptos o malformados', () {
      expect(BaseSocket.isTokenExpired('not.a.jwt'), isTrue);
      expect(BaseSocket.isTokenExpired(''), isTrue);
      expect(BaseSocket.isTokenExpired('header.invalid_base64.sig'), isTrue);
    });

    test('Estado inicial es disconnected y responde a ciclo de vida', () {
      final service = MockSocketService();
      addTearDown(service.dispose);

      expect(service.state, SocketState.disconnected);
      expect(service.isConnected, isFalse);
      expect(service.isConnecting, isFalse);
    });
  });
}
