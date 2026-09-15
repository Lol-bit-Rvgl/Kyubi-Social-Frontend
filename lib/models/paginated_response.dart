/// Respuesta paginada estándar basada en tokens de cursor.
///
/// El backend entrega la lista de elementos bajo una clave configurable
/// (`posts`, `chats`, `circles`, `comments`, ...) o las claves genéricas
/// `items`/`data`/`results`, junto con un token `next_page_token`
/// (o `nextPageToken`/`nextCursor`) para la siguiente página.
class PaginatedResponse<T> {
  const PaginatedResponse({
    required this.items,
    this.nextPageToken,
    this.total = 0,
    this.hasMore = false,
  });

  final List<T> items;
  final String? nextPageToken;
  final int total;
  final bool hasMore;

  /// Parsea una respuesta paginada.
  ///
  /// [parseItem] convierte cada mapa del array en un elemento tipado.
  /// [itemKey] permite indicar la clave que contiene el array
  /// (p. ej. `'posts'`, `'chats'`, `'circles'`).
  factory PaginatedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) parseItem, {
    String? itemKey,
  }) {
    dynamic raw;
    if (itemKey != null) raw = json[itemKey];
    raw ??= json['items'] ?? json['data'] ?? json['results'];

    final items = raw is List
        ? raw.whereType<Map<String, dynamic>>().map(parseItem).toList()
        : <T>[];

    final token =
        json['nextPageToken'] ?? json['next_page_token'] ?? json['nextCursor'];

    return PaginatedResponse<T>(
      items: items,
      nextPageToken: token is String && token.isNotEmpty ? token : null,
      total: (json['total'] as num?)?.toInt() ?? 0,
      hasMore: json['hasMore'] as bool? ?? token is String,
    );
  }

  bool get hasNextPage => nextPageToken != null && nextPageToken!.isNotEmpty;
}
