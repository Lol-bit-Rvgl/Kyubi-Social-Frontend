class AppConstants {
  AppConstants._();

  static const String appName = 'Kyubi';
  static const String appSlogan = 'Comparte, conecta, crea';
  static const String tagline = 'Comparte tu lado oscuro';
  static const String appVersion = '1.0.0';
  static const String companyName = 'Nodo Apps';

  static const String termsUrl = 'https://kyubi.app/terms';
  static const String privacyUrl = 'https://kyubi.app/privacy';

  static const List<String> genderOptions = [
    'No binario',
    'Hombre',
    'Mujer',
    'Prefiero no decir',
    'Otro',
  ];

  static const List<String> interestSuggestions = [
    'Horror Analógico',
    'Roleplay',
    'Programación',
    'Arte Digital',
    'Música',
    'Cine',
    'Videojuegos',
    'Anime',
    'Manga',
    'Fotografía',
    'Escritura Creativa',
    'Ciencia Ficción',
    'Mitología',
    'Conspiraciones',
    'Tecnología',
  ];

  // Paleta calmada (morado/ciruela + azul acero/pizarra + grafito), sin
  // fucsias ni cyanes neón.
  static const Map<String, String> usernameColors = {
    'ciruela': '#A2437F',
    'morado': '#9B59B6',
    'teal': '#5BC8AF',
    'violeta': '#7C5CB7',
    'verde': '#58A98C',
    'cobre': '#C87F5B',
    'acero': '#5B8FD1',
  };

  static const int feedPageSize = 20;
  static const int commentsPageSize = 50;
  static const int roomsPageSize = 20;
  static const int messagesPageSize = 50;
  static const int maxUploadSize = 5 * 1024 * 1024;

  static const List<String> allowedUploadTypes = [
    'image/jpeg',
    'image/png',
    'image/webp',
    'image/gif',
  ];

  static const List<String> reactionKeys = [
    'like',
    'love',
    'laugh',
    'wow',
    'sad',
    'angry',
  ];

  static const Map<String, String> reactionEmojis = {
    'like': '\u2764\uFE0F',
    'love': '\u2764\uFE0F',
    'laugh': '\u{1F602}',
    'wow': '\u{1F62E}',
    'sad': '\u{1F622}',
    'angry': '\u{1F621}',
  };

  static const Map<String, String> feedCategories = {
    'para_ti': 'Para ti',
    'siguiendo': 'Siguiendo',
    'tendencias': 'Tendencias',
  };
}
