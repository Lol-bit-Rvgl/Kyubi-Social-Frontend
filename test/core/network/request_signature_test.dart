import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kyubi/core/network/request_signature.dart';

void main() {
  group('RequestSignature', () {
    final fallbackSecret = 'kyubi-hjtrfs-client-sign-v1';

    tearDown(() {
      // Restaurar el hook a "usar kDebugMode real" entre tests.
      RequestSignature.debugForTest = null;
    });

    test('sign produce el HMAC SHA-256 esperado con timestamp fijo', () {
      final ts = DateTime.utc(2024, 1, 2, 3, 4, 5);
      final expectedTs = ts.millisecondsSinceEpoch.toString();
      // body == null -> digest vacío.
      final payload = 'GET\n/posts/feed\n';
      final hmac = Hmac(sha256, utf8.encode(fallbackSecret));
      final expectedDigest =
          hmac.convert(utf8.encode('$payload\n$expectedTs')).toString();

      final signature = RequestSignature.sign(
        method: 'get',
        path: '/posts/feed',
        timestamp: ts,
      );

      expect(signature, 'HJTRFS $expectedTs.$expectedDigest');
    });

    test('sign distingue el método (normalizado a mayúsculas)', () {
      final ts = DateTime.utc(2024, 1, 2);
      final a = RequestSignature.sign(
        method: 'post',
        path: '/x',
        timestamp: ts,
      );
      final b = RequestSignature.sign(
        method: 'get',
        path: '/x',
        timestamp: ts,
      );
      expect(a, isNot(equals(b)));
    });

    test('secretOrNull devuelve el fallback de debug cuando no hay env', () {
      RequestSignature.debugForTest = true;
      expect(RequestSignature.secretOrNull, equals(fallbackSecret));
    });

    test('secretOrNull es null cuando el secreto está ausente en modo release', () {
      RequestSignature.debugForTest = false;
      expect(RequestSignature.secretOrNull, isNull);
    });
  });
}