import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Permite refrescar la navegación cuando cambia la sesión.
class RouterRefreshListenable extends ChangeNotifier {
  void notifySessionChanged() => notifyListeners();
}

/// Guarda la instancia del refresh listenable a nivel global de la app.
final routerRefreshProvider = Provider<RouterRefreshListenable>(
  (ref) => RouterRefreshListenable(),
);
