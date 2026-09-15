import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/chat_socket.dart';

/// Estado del buscaparejas aleatorio.
enum MatchStatus { idle, searching, matched, timeout, error }

class MatchState {
  const MatchState({
    this.status = MatchStatus.idle,
    this.category = '',
    this.peer,
    this.conversationId,
    this.error,
  });

  final MatchStatus status;
  final String category;

  /// Perfil público del otro usuario al encontrar match.
  final Map<String, dynamic>? peer;

  /// ID de la conversación creada por el matchmaker.
  final String? conversationId;
  final String? error;

  bool get isSearching => status == MatchStatus.searching;

  MatchState copyWith({
    MatchStatus? status,
    String? category,
    Map<String, dynamic>? peer,
    String? conversationId,
    String? error,
    bool clearPeer = false,
  }) {
    return MatchState(
      status: status ?? this.status,
      category: category ?? this.category,
      peer: clearPeer ? null : peer ?? this.peer,
      conversationId: conversationId ?? this.conversationId,
      error: error ?? this.error,
    );
  }
}

/// Controla el ciclo de vida del matchmaking: emite `match:start`/`match:cancel`
/// por socket y escucha `match:found`/`match:none`. Si el socket no conecta o
/// no hay nadie disponible dentro del timeout, reporta un estado honesto
/// de "sin resultados" (nunca genera perfiles simulados).
class MatchmakingController extends Notifier<MatchState> {
  /// Espera del backend antes de declarar "no encontrado".
  static const _serverTimeout = Duration(seconds: 35);

  StreamSubscription<ChatSocketEvent>? _sub;
  Timer? _timeoutTimer;
  int _requestId = 0;
  bool _disposed = false;

  @override
  MatchState build() {
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      _sub?.cancel();
      _timeoutTimer?.cancel();
      ChatSocketService.instance.stopMatchmaking();
    });
    _sub = ChatSocketService.instance.events.listen(_onEvent);
    return const MatchState();
  }

  /// Inicia (o reinicia) la búsqueda en [category].
  void startSearch(String category) {
    _requestId++;
    final id = _requestId;
    _timeoutTimer?.cancel();
    state = MatchState(status: MatchStatus.searching, category: category);

    final socket = ChatSocketService.instance;
    if (!socket.isConnected) {
      socket
          .connect()
          .then((_) {
            if (_disposed || _requestId != id) return;
            if (socket.isConnected) {
              socket.startMatchmaking(category);
              _timeoutTimer = Timer(
                _serverTimeout,
                () => _onServerTimedOut(id, category),
              );
            } else {
              _onConnectionFailed(id, category);
            }
          })
          .catchError((_) {
            if (_disposed || _requestId != id) return;
            _onConnectionFailed(id, category);
          });
      return;
    }

    socket.joinMatchmaking(category: category);
    _timeoutTimer = Timer(
      _serverTimeout,
      () => _onServerTimedOut(id, category),
    );
  }

  /// Vuelve a buscar en la última categoría usada.
  void retry() {
    final category = state.category.isNotEmpty ? state.category : '🎭 Roleplay';
    startSearch(category);
  }

  /// Cancela la búsqueda y deja el controlador en reposo.
  void cancel() {
    _requestId++;
    _timeoutTimer?.cancel();
    ChatSocketService.instance.leaveMatchmaking();
    state = const MatchState();
  }

  void _onServerTimedOut(int id, String category) {
    if (_disposed || _requestId != id) return;
    state = MatchState(status: MatchStatus.timeout, category: category);
  }

  void _onConnectionFailed(int id, String category) {
    state = MatchState(
      status: MatchStatus.error,
      category: category,
      error: 'No se pudo conectar con el servidor. Revisa tu conexión.',
    );
  }

  void _onEvent(ChatSocketEvent event) {
    switch (event) {
      case ChatMatchFound(:final peer, :final category, :final conversationId):
        if (!state.isSearching || _disposed) return;
        _timeoutTimer?.cancel();
        state = MatchState(
          status: MatchStatus.matched,
          category: category,
          peer: peer,
          conversationId: conversationId.isNotEmpty ? conversationId : null,
        );
      case ChatMatchNone(:final category, :final reason):
        if (!state.isSearching || _disposed) return;
        _timeoutTimer?.cancel();
        state = MatchState(
          status: MatchStatus.timeout,
          category: category,
          error: reason,
        );
      default:
        break;
    }
  }
}

final matchmakingControllerProvider =
    NotifierProvider<MatchmakingController, MatchState>(
      MatchmakingController.new,
    );
