library;

/// Conteo de reacciones normalizado por el backend.
///
/// Cada reacción se almacena con una key estándar (`like`, `fire`, `laugh`, etc.)
/// o en el mapa `extra` para reacciones personalizadas (emojis WebP).
/// La función [emojiToKey] normaliza cualquier emoji, carácter Unicode o ruta
/// WebP a su key estándar correspondiente.

/// Mapa de emoji Unicode → key estándar del backend.
const _emojiToKeyMap = <String, String>{
  '❤️': 'like',
  '🤍': 'like',
  '💕': 'love',
  '🔥': 'fire',
  '😂': 'laugh',
  '✨': 'sparkles',
  '🥺': 'pleading',
  '😮': 'wow',
  '🎉': 'party',
  '😢': 'sad',
  '😡': 'angry',
};

/// Mapa de nombre de archivo WebP → key estándar.
/// Cubre los emojis más usados del picker animado.
const _webpToKeyMap = <String, String>{
  // Smileys
  'happy.webp': 'laugh',
  'sad.webp': 'sad',
  'angry.webp': 'angry',
  'surprised.webp': 'wow',
  'love.webp': 'love',
  'crying.webp': 'sad',
  'laughing.webp': 'laugh',
  'winking.webp': 'laugh',
  'thinking.webp': 'pleading',
  'sleeping.webp': 'pleading',
  'cool.webp': 'sparkles',
  'star-struck.webp': 'sparkles',
  'partying.webp': 'party',
  // Objects / Symbols
  'fire.webp': 'fire',
  'sparkles.webp': 'sparkles',
  'party-popper.webp': 'party',
  'clapping-hands.webp': 'party',
  'thumbs-up.webp': 'like',
  'red-heart.webp': 'like',
  'broken-heart.webp': 'sad',
  'hundred-points.webp': 'fire',
  'on-fire.webp': 'fire',
  'collision.webp': 'fire',
};

/// Normaliza cualquier representación de reacción (emoji Unicode, key
/// estándar, ruta WebP) a la key estándar que el backend espera.
///
/// Ejemplos:
/// - `'❤️'` → `'like'`
/// - `'like'` → `'like'`
/// - `'🔥'` → `'fire'`
/// - `'assets/Emojis/Smileys and emotions/happy.webp'` → `'laugh'`
/// - `'happy.webp'` → `'laugh'`
/// - `'unknown_emoji.webp'` → `'unknown_emoji.webp'` (sin mapeo, va a extra)
String emojiToKey(String value) {
  // 1. Key estándar directa.
  if (const {
    'like',
    'love',
    'fire',
    'laugh',
    'sparkles',
    'pleading',
    'wow',
    'party',
    'sad',
    'angry',
  }.contains(value)) {
    return value;
  }

  // 2. Emoji Unicode → key.
  if (_emojiToKeyMap.containsKey(value)) {
    return _emojiToKeyMap[value]!;
  }

  // 3. Ruta WebP → extraer nombre de archivo y mapear.
  if (value.endsWith('.webp') || value.contains('/')) {
    final fileName = value.split('/').last;
    if (_webpToKeyMap.containsKey(fileName)) {
      return _webpToKeyMap[fileName]!;
    }
    // Sin mapeo conocido: usar el nombre del archivo como key (va a extra).
    return fileName;
  }

  // 4. Sin mapeo: devolver tal cual (irá al mapa extra).
  return value;
}

/// Devuelve el emoji Unicode legible para una key estándar.
/// Se usa para mostrar el chip con el emoji correcto en la UI.
String keyToEmoji(String key) {
  return switch (key) {
    'like' => '❤️',
    'love' => '❤️',
    'fire' => '🔥',
    'laugh' => '😂',
    'sparkles' => '✨',
    'pleading' => '🥺',
    'wow' => '😮',
    'party' => '🎉',
    'sad' => '😢',
    'angry' => '😡',
    _ => key, // Si es un WebP u otro valor, devolver tal cual
  };
}

/// Indica si la key corresponde a un asset WebP (para renderizado).
bool isWebpKey(String key) => key.endsWith('.webp');

/// Conteo de reacciones normalizado por el backend.
class ReactionCounts {
  const ReactionCounts({
    this.like = 0,
    this.love = 0,
    this.fire = 0,
    this.laugh = 0,
    this.sparkles = 0,
    this.pleading = 0,
    this.wow = 0,
    this.party = 0,
    this.sad = 0,
    this.angry = 0,
    this.extra = const {},
  });

  final int like;
  final int love;
  final int fire;
  final int laugh;
  final int sparkles;
  final int pleading;
  final int wow;
  final int party;
  final int sad;
  final int angry;
  final Map<String, int> extra;

  int get total =>
      like +
      love +
      fire +
      laugh +
      sparkles +
      pleading +
      wow +
      party +
      sad +
      angry +
      extra.values.fold(0, (a, b) => a + b);

  int countFor(String keyOrEmoji) {
    final key = emojiToKey(keyOrEmoji);
    switch (key) {
      case 'like':
      case 'love':
      case '❤️':
        return love > 0 ? love : like;
      case 'fire':
      case '🔥':
        return fire;
      case 'laugh':
      case '😂':
        return laugh;
      case 'sparkles':
      case '✨':
        return sparkles;
      case 'pleading':
      case '🥺':
        return pleading;
      case 'wow':
      case '😮':
        return wow;
      case 'party':
      case '🎉':
        return party;
      case 'sad':
      case '😢':
        return sad;
      case 'angry':
      case '😡':
        return angry;
      default:
        return extra[key] ?? 0;
    }
  }

  /// Retorna lista de pares (emoji, key, count) para las reacciones con al menos 1 voto.
  List<({String emoji, String key, int count})> get activeList {
    final list = <({String emoji, String key, int count})>[];
    final loveCount = love > 0 ? love : like;
    if (loveCount > 0) list.add((emoji: '❤️', key: 'like', count: loveCount));
    if (fire > 0) list.add((emoji: '🔥', key: 'fire', count: fire));
    if (laugh > 0) list.add((emoji: '😂', key: 'laugh', count: laugh));
    if (sparkles > 0) {
      list.add((emoji: '✨', key: 'sparkles', count: sparkles));
    }
    if (pleading > 0) {
      list.add((emoji: '🥺', key: 'pleading', count: pleading));
    }
    if (wow > 0) list.add((emoji: '😮', key: 'wow', count: wow));
    if (party > 0) list.add((emoji: '🎉', key: 'party', count: party));
    if (sad > 0) list.add((emoji: '😢', key: 'sad', count: sad));
    if (angry > 0) list.add((emoji: '😡', key: 'angry', count: angry));
    for (final e in extra.entries) {
      if (e.value > 0) {
        // extra keys pueden ser WebP paths o keys personalizadas.
        // Renderizar como WebP si termina en .webp, si no usar keyToEmoji.
        final emoji = isWebpKey(e.key) ? e.key : keyToEmoji(e.key);
        list.add((emoji: emoji, key: e.key, count: e.value));
      }
    }
    return list;
  }

  factory ReactionCounts.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ReactionCounts();
    int toNum(dynamic v) => (v as num?)?.toInt() ?? 0;
    final extra = <String, int>{};
    for (final entry in json.entries) {
      if (!const [
        'like',
        'love',
        'fire',
        'laugh',
        'sparkles',
        'pleading',
        'wow',
        'party',
        'sad',
        'angry',
      ].contains(entry.key)) {
        if (entry.value is num && (entry.value as num) > 0) {
          extra[entry.key] = (entry.value as num).toInt();
        }
      }
    }
    return ReactionCounts(
      like: toNum(json['like']),
      love: toNum(json['love']),
      fire: toNum(json['fire']),
      laugh: toNum(json['laugh']),
      sparkles: toNum(json['sparkles']),
      pleading: toNum(json['pleading']),
      wow: toNum(json['wow']),
      party: toNum(json['party']),
      sad: toNum(json['sad']),
      angry: toNum(json['angry']),
      extra: extra,
    );
  }

  ReactionCounts copyWith({
    int? like,
    int? love,
    int? fire,
    int? laugh,
    int? sparkles,
    int? pleading,
    int? wow,
    int? party,
    int? sad,
    int? angry,
    Map<String, int>? extra,
  }) {
    return ReactionCounts(
      like: like ?? this.like,
      love: love ?? this.love,
      fire: fire ?? this.fire,
      laugh: laugh ?? this.laugh,
      sparkles: sparkles ?? this.sparkles,
      pleading: pleading ?? this.pleading,
      wow: wow ?? this.wow,
      party: party ?? this.party,
      sad: sad ?? this.sad,
      angry: angry ?? this.angry,
      extra: extra ?? this.extra,
    );
  }

  ReactionCounts increment(String type, [int delta = 1]) {
    final key = emojiToKey(type);
    switch (key) {
      case 'like':
      case 'love':
      case '❤️':
        return copyWith(like: (like + delta).clamp(0, 999999));
      case 'fire':
      case '🔥':
        return copyWith(fire: (fire + delta).clamp(0, 999999));
      case 'laugh':
      case '😂':
        return copyWith(laugh: (laugh + delta).clamp(0, 999999));
      case 'sparkles':
      case '✨':
        return copyWith(sparkles: (sparkles + delta).clamp(0, 999999));
      case 'pleading':
      case '🥺':
        return copyWith(pleading: (pleading + delta).clamp(0, 999999));
      case 'wow':
      case '😮':
        return copyWith(wow: (wow + delta).clamp(0, 999999));
      case 'party':
      case '🎉':
        return copyWith(party: (party + delta).clamp(0, 999999));
      case 'sad':
      case '😢':
        return copyWith(sad: (sad + delta).clamp(0, 999999));
      case 'angry':
      case '😡':
        return copyWith(angry: (angry + delta).clamp(0, 999999));
      default:
        final newExtra = Map<String, int>.from(extra);
        final current = newExtra[key] ?? 0;
        final updated = (current + delta).clamp(0, 999999);
        if (updated <= 0) {
          newExtra.remove(key);
        } else {
          newExtra[key] = updated;
        }
        return copyWith(extra: newExtra);
    }
  }

  Map<String, dynamic> toJson() => {
    'like': like,
    'love': love,
    'fire': fire,
    'laugh': laugh,
    'sparkles': sparkles,
    'pleading': pleading,
    'wow': wow,
    'party': party,
    'sad': sad,
    'angry': angry,
    ...extra,
  };
}

/// Estadísticas de un post.
class PostStats {
  const PostStats({
    this.likes = 0,
    this.comments = 0,
    this.views = 0,
    this.shares = 0,
  });

  final int likes;
  final int comments;
  final int views;
  final int shares;

  factory PostStats.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const PostStats();
    int toNum(dynamic v) => (v as num?)?.toInt() ?? 0;
    return PostStats(
      likes: toNum(json['likes']),
      comments: toNum(json['comments']),
      views: toNum(json['views']),
      shares: toNum(json['shares']),
    );
  }

  Map<String, dynamic> toJson() => {
    'likes': likes,
    'comments': comments,
    'views': views,
    'shares': shares,
  };
}

/// Avisos de contenido del post.
class PostWarnings {
  const PostWarnings({
    this.violence = false,
    this.adult = false,
    this.dark = false,
    this.spoiler = false,
  });

  final bool violence;
  final bool adult;
  final bool dark;
  final bool spoiler;

  bool get hasAny => violence || adult || dark || spoiler;

  factory PostWarnings.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const PostWarnings();
    return PostWarnings(
      violence: json['violence'] as bool? ?? false,
      adult: json['adult'] as bool? ?? false,
      dark: json['dark'] as bool? ?? false,
      spoiler: json['spoiler'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'violence': violence,
    'adult': adult,
    'dark': dark,
    'spoiler': spoiler,
  };
}

/// Reacción registrada por un usuario en un post.
class ReactionUser {
  const ReactionUser({
    required this.type,
    required this.id,
    required this.username,
    required this.displayName,
    this.avatarUrl,
  });

  final String type;
  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;

  factory ReactionUser.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>? ?? const {};
    return ReactionUser(
      type: json['type'] as String? ?? 'like',
      id: user['id'] as String? ?? '',
      username: user['username'] as String? ?? '',
      displayName: user['displayName'] as String? ?? '',
      avatarUrl: user['avatarUrl'] as String?,
    );
  }
}

/// Respuesta de `GET /posts/[id]/reactions`.
class ReactionList {
  const ReactionList({
    required this.counts,
    required this.total,
    this.myReaction,
    this.reactions = const [],
  });

  final ReactionCounts counts;
  final int total;
  final String? myReaction;
  final List<ReactionUser> reactions;

  factory ReactionList.fromJson(Map<String, dynamic> json) {
    final list = json['reactions'];
    return ReactionList(
      counts: ReactionCounts.fromJson(json['counts'] as Map<String, dynamic>?),
      total: (json['total'] as num?)?.toInt() ?? 0,
      myReaction: json['myReaction'] as String?,
      reactions: list is List
          ? list
                .whereType<Map<String, dynamic>>()
                .map(ReactionUser.fromJson)
                .toList()
          : const [],
    );
  }
}
