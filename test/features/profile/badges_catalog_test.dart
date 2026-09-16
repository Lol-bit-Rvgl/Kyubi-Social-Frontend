import 'package:flutter_test/flutter_test.dart';
import 'package:kyubi/models/badge.dart';

void main() {
  group('BadgeCatalog canónico', () {
    test('contiene las 5 insignias base con IDs únicos', () {
      expect(BadgeCatalog.allBadges, hasLength(5));
      final ids = BadgeCatalog.allBadges.map((b) => b.id).toList();
      expect(ids.toSet(), hasLength(5));
      expect(
        ids,
        ['pionero', 'racha', 'maestro_rol', 'creador_visual', 'guardian_social'],
      );
    });

    test('todas tienen título, descripción e icono no vacíos', () {
      for (final badge in BadgeCatalog.allBadges) {
        expect(badge.title, isNotEmpty);
        expect(badge.description, isNotEmpty);
        expect(badge.icon, isNotEmpty);
      }
    });

    test('la insignia VIP dinámica mantiene su ID estable', () {
      expect(BadgeCatalog.vip.id, 'vip');
      expect(BadgeCatalog.vip.title, 'Rango VIP');
    });
  });
}
