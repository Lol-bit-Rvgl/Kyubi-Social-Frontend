import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyubi/services/voice/voice_room_controller.dart';

void main() {
  group('Bloque 3 - Verificación de Estabilidad y Telemetría', () {
    test('Selector voiceRoomProvider.select((s) => s.isConnected) no emite cambios ante actualizaciones de audio', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      int connectionChangeCount = 0;
      container.listen(
        voiceRoomProvider.select((s) => s.isConnected),
        (previous, next) {
          connectionChangeCount++;
        },
      );

      final notifier = container.read(voiceRoomProvider.notifier);

      // Simular cambio de estado donde isConnected no cambia pero otros campos sí
      notifier.setRemoteMuted('user-1', muted: true);
      expect(connectionChangeCount, 0,
          reason: 'Modificaciones de mute o audio no deben disparar el selector de conexión');
    });

    test('Manejadores globales de error despachan de forma segura sin excepciones', () {
      expect(() {
        final details = FlutterErrorDetails(
          exception: Exception('Simulated test crash'),
          stack: StackTrace.current,
        );
        FlutterError.onError?.call(details);
      }, returnsNormally);

      expect(() {
        final error = Exception('Simulated async crash');
        PlatformDispatcher.instance.onError?.call(error, StackTrace.current);
      }, returnsNormally);
    });
  });
}
