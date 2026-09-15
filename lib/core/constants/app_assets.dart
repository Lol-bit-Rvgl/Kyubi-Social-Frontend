/// Catálogo central de assets de Kyubi.
///
/// Cada entrada documenta qué representa el asset, sus dimensiones y su
/// estado dentro de la aplicación. Los assets se encuentran en `assets/assets/`
/// (PNG sin canal alfa, fondo oscuro opaco).
///
/// ## Integrados
/// - [chatsBubbles]: ilustración de burbujas de chat (estado vacío de Mensajes).
/// - [world]: ilustración de mundo/global (exploración y descubrimiento).
/// - [logo]: logotipo oficial (pantallas de login, registro, feed, ajustes y
///   legales, vía [KyubiLogo]).
/// - [groups]: grupos/comunidades (estado vacío y tile de Círculos).
/// - [meetings]: reuniones (estado vacío y tile de Salas).
///
/// ## Identificados, pendientes de función
/// Assets que corresponden a funciones aún inexistentes en el backend y que
/// **no** se fuerzan en la interfaz para no inventar funcionalidades. Quedan
/// preparados y documentados para integrarse cuando la función exista.
class AppAssets {
  AppAssets._();

  // ---------------------------------------------------------------------------
  // Integrados en la interfaz actual.
  // ---------------------------------------------------------------------------

  /// Burbujas de chat (1536×1024) — estado vacío de la bandeja de mensajes.
  static const String chatsBubbles = 'assets/assets/Chats_bubles_icon.png';

  /// Mundo / global (1536×1536) — exploración y descubrimiento de personas.
  static const String world = 'assets/assets/World_icon.png';

  /// Logotipo oficial (assets/icons/kyubi_logo.jpg). Renderizado por [KyubiLogo]
  /// en squircle con resplandor sutil para fondos oscuros.
  static const String logo = 'assets/icons/kyubi_logo.jpg';

  /// Grupos / comunidades (1536×1536) — estado vacío y tile de Círculos.
  static const String groups = 'assets/assets/Groups_icon.png';

  /// Reuniones (1536×1536) — estado vacío y tile de Salas.
  static const String meetings = 'assets/assets/Meetings_icon.png';

  /// Campana de notificación activa (1536×1536).
  ///
  /// Contenido muy oscuro (dorado tenue) que no aporta contraste sobre el
  /// tile oscuro de [AssetFrame]; el estado vacío de Actividad mantiene el
  /// icono Material. Pendiente de un tratamiento de brillo si se integra.
  static const String notificationOn =
      'assets/assets/Notification(ON)_icon.png';

  // ---------------------------------------------------------------------------
  // Variantes de mensajería (integradas a través de [chatsBubbles]).
  // ---------------------------------------------------------------------------

  /// Burbuja de chat simple (1536×1536).
  static const String chat = 'assets/assets/Chats_icon.png';

  /// Burbuja de chat con destello (1536×1536).
  static const String chatAlt = 'assets/assets/Chats2_icon.png';

  /// Botella con mensaje (1536×613) — mensajería a la deriva.
  static const String bottleDrifting = 'assets/assets/Bottle_drifting_icon.png';

  // ---------------------------------------------------------------------------
  // Identificados para funciones futuras (no integrados).
  // ---------------------------------------------------------------------------

  /// Galería (1536×1536) — para una futura galería de contenido.
  static const String gallery = 'assets/assets/Garelly_icon.png';

  /// Modo cine (1536×1536) — para contenido tipo cine/streaming.
  static const String cinemaMode = 'assets/assets/Cinema_mode_icon.png';

  /// Moneda (1536×1536) — para un futuro sistema de recompensas.
  static const String coin = 'assets/assets/Coin_icon.png';

  /// Moneda especial (1536×1536) — variante de moneda/insignia.
  static const String coinSpecial = 'assets/assets/Coin(Z)_icon.png';

  /// Regalo (1536×1536) — para regalos/sorpresas sociales.
  static const String gift = 'assets/assets/Gift_icon.png';

  /// Tienda (1536×1536) — para una futura tienda.
  static const String store = 'assets/assets/Store_icon.png';

  /// Tienda (1536×1406) — variante de tienda.
  static const String storeAlt = 'assets/assets/Store2_icon.png';

  /// Plataforma (1536×1024) — para sección de plataformas o lanzamientos.
  static const String platform = 'assets/assets/Plataform_icon.png';

  /// Piedra/papel/tijera (1536×1536) — para el futuro minijuego.
  static const String rockPaperScissors =
      'assets/assets/Piedra_papel_tijeras_icon.png';

  /// Piedra/papel/tijera (1536×1536) — variante del minijuego.
  static const String rockPaperScissorsAlt =
      'assets/assets/Piedra_papel_tijeras2_icon.png';

  /// Piedra/papel/tijera (1536×1536) — variante del minijuego.
  static const String rockPaperScissorsAlt2 =
      'assets/assets/Piedra_papel_tijeras3_icon.png';

  /// Diamante de la serie JoJo (1536×1536) — coleccionable/función futura.
  static const String crazyDiamond =
      'assets/assets/CrazyDiamond(Z(zi. jojo referencia))_icon.png';

  /// Publicidad / anuncios (1536×1536) — para futura integración publicitaria.
  static const String advertisements = 'assets/assets/Advertisements_icon.png';

  // ---------------------------------------------------------------------------
  // Iconografía de soporte (no usada: los iconos Material mantienen la
  // coherencia del sistema y estos PNG traen fondo opaco).
  // ---------------------------------------------------------------------------

  /// Campana de notificación inactiva (1536×1536).
  static const String notificationOff =
      'assets/assets/Notification(OFF)_icon.png';

  /// Icono de perfil (1536×1536).
  static const String profileIcon = 'assets/assets/Profile_Icon.png';

  /// Icono de búsqueda (1536×1536).
  static const String search = 'assets/assets/Search_icon.png';

  /// Icono de compartir (1536×1536).
  static const String share = 'assets/assets/Share_icon.png';

  /// Icono de atrás / navegación (1536×1536).
  static const String back = 'assets/assets/Back_icon.png';

  /// Puntos suspensivos / menú (1536×1536).
  static const String more = 'assets/assets/TresPuntosSuspencivos_icon.png';

  // ---------------------------------------------------------------------------
  // Ilustraciones de estados vacíos — Fase 1 del rediseño UI/UX.
  // ---------------------------------------------------------------------------

  /// Ilustración 3D del feed vacío — se muestra cuando no hay publicaciones.
  static const String emptyFeed = 'assets/images/empty_states/empty_feed.png';

  /// Ilustración 3D de mensajes vacíos — bandeja sin conversaciones.
  static const String emptyMessages =
      'assets/images/empty_states/empty_messages.png';

  /// Ilustración 3D de búsqueda sin resultados — explorar sin coincidencias.
  static const String emptySearch =
      'assets/images/empty_states/empty_search.png';

  // ---------------------------------------------------------------------------
  // Splash / hero images.
  // ---------------------------------------------------------------------------

  /// Silueta zorro carmesí sobre fondo transparente — hero central del feed.
  static const String kyubiFoxHero = 'assets/images/kyubi_fox_hero.png';

  /// ZorroKyubi metálico rojo sobre fondo oscuro — hero del feed y banner.
  static const String splashMascotRed =
      'assets/images/splash/splash_mascot_red.jpg';

  /// ZorroKyubi metálico blanco sobre fondo oscuro — variante splash.
  static const String splashMascot = 'assets/images/splash/splash_mascot.jpg';

  /// ZorroKyubi metálico rojo variante oscura — variante splash.
  static const String splashMascotDark =
      'assets/images/splash/splash_mascot_dark.jpg';

  // ---------------------------------------------------------------------------
  // Assets audiovisuales e iconografía oficial (Fase 2).
  // ---------------------------------------------------------------------------

  /// Video en bucle del zorro Kyubi para el hero de la pantalla de inicio.
  static const String kyubiFoxLoop = 'assets/animations/kyubi_fox_loop.mp4';

  /// Banner inicial oficial panorámico de bienvenida.
  static const String bannerInicial = 'assets/banners/banner_inicial.jpg';

  /// Icono oficial de Roleplay (máscaras teatrales).
  static const String iconRoleplay = 'assets/icons/roleplay.png';

  /// Icono oficial de Comunidades para el navbar inferior.
  static const String iconComunidades = 'assets/icons/comunidades.png';

  /// Insignia oficial de verificación (roseta azul con estrella).
  static const String iconVerificados = 'assets/icons/verificados.png';

  /// Icono de transmisiones inactivas / salas apagadas.
  static const String iconTransmisionesApagadas =
      'assets/icons/transmisiones_apagadas.png';

  /// Fondos degradados del catálogo Jay Sen.
  static const String jaySen1 = 'assets/backgrounds/jay_sen_1.png';
  static const String jaySen2 = 'assets/backgrounds/jay_sen_2.png';
  static const String jaySen3 = 'assets/backgrounds/jay_sen_3.png';
  static const String jaySen4 = 'assets/backgrounds/jay_sen_4.png';
  static const String jaySen5 = 'assets/backgrounds/jay_sen_5.png';
  static const String jaySen6 = 'assets/backgrounds/jay_sen_6.png';

  // ---------------------------------------------------------------------------
  // Segunda tanda de assets oficiales de diseño (Fase 2B).
  // ---------------------------------------------------------------------------

  /// Icono oficial de Mensajes para la barra inferior.
  static const String iconMensajes = 'assets/icons/mensajes.png';

  /// Icono oficial de Salas para la barra inferior y accesos.
  static const String iconSalas = 'assets/icons/salas.png';

  /// Icono oficial de la dinámica Tirar la Botella.
  static const String iconTirarBotella = 'assets/icons/tirar_botella.png';

  /// Icono oficial de Matching Social / Emparejamiento.
  static const String iconMatching = 'assets/icons/matching.png';

  /// Iconos oficiales para sugerencias y selector de menciones (@).
  static const String iconMencion1 = 'assets/icons/mencion_1.png';
  static const String iconMencion2 = 'assets/icons/mencion_2.png';

  // ---------------------------------------------------------------------------
  // Assets oficiales para Estados Vacíos (Empty States).
  // ---------------------------------------------------------------------------

  /// Asset oficial de Solicitudes de Chat para empty state de invitaciones ("Invites").
  static const String iconSolicitudesChat = 'assets/icons/Solicitudes chat_.jpg';

  /// Asset oficial de Menciones para empty state de menciones pendientes ("@Mentions").
  static const String iconMenciones = 'assets/icons/Opción de menciones 1.jpg';

  /// Asset oficial de Salas para empty state de salas ("Rooms").
  static const String iconSalasVacias = 'assets/icons/Salas_.jpg';

  /// Asset oficial de Mensajes para empty state de mensajes directos y conversaciones ("Private").
  static const String iconMensajesVacios = 'assets/icons/Mensajes_.jpg';

  // Aliases intuitivos para estados vacíos
  static const String solicitudesChat = iconSolicitudesChat;
  static const String emptyStateSolicitudes = iconSolicitudesChat;
  static const String emptyStateMenciones = iconMenciones;
  static const String emptyStateSalas = iconSalasVacias;
  static const String emptyStateMensajes = iconMensajesVacios;
}

/// Catálogo y mapeador oficial de insignias de niveles de amistad y rachas (DMs 1-a-1).
class AppFriendshipIcons {
  AppFriendshipIcons._();

  static const String level1 = 'assets/icons/amistad/piruletas_nivel_1.png';
  static const String level2 = 'assets/icons/amistad/gorro_de_mago_nivel_2.png';
  static const String level3 = 'assets/icons/amistad/caldero_nivel_3.png';
  static const String level4 = 'assets/icons/amistad/llave_de_corazon_nivel_4.png';
  static const String level5 = 'assets/icons/amistad/espada_nivel_5.png';
  static const String level6 = 'assets/icons/amistad/carta_nivel_6.png';
  static const String level7 = 'assets/icons/amistad/rosa_en_burbuja_nivel_7.png';

  // Alias para compatibilidad
  static const String nivel1 = level1;
  static const String nivel2 = level2;
  static const String nivel3 = level3;
  static const String nivel4 = level4;
  static const String nivel5 = level5;
  static const String nivel6 = level6;
  static const String nivel7 = level7;

  /// Determina el asset del icono según los días consecutivos de chat (racha).
  static String? iconForStreakDays(int days) {
    if (days >= 360) return level7; // 1 año
    if (days >= 180) return level6; // 6 meses
    if (days >= 60) return level5; // 2 meses
    if (days >= 30) return level4; // 1 mes
    if (days >= 15) return level3; // 15 días
    if (days >= 3) return level2; // 3 días
    if (days >= 1) return level1; // 1 día
    return null; // Menos de 1 día de racha: sin medalla
  }

  /// Retorna el nivel de racha correspondiente (0 a 7).
  static int levelForStreakDays(int days) {
    if (days >= 360) return 7;
    if (days >= 180) return 6;
    if (days >= 60) return 5;
    if (days >= 30) return 4;
    if (days >= 15) return 3;
    if (days >= 3) return 2;
    if (days >= 1) return 1;
    return 0;
  }

  /// Nombre o título descriptivo de la insignia según el nivel.
  static String titleForLevel(int level) {
    switch (level) {
      case 1:
        return 'Piruletas de Amistad';
      case 2:
        return 'Gorro de Mago';
      case 3:
        return 'Caldero Mágico';
      case 4:
        return 'Llave de Corazón';
      case 5:
        return 'Espada de Vínculo';
      case 6:
        return 'Carta de Lealtad';
      case 7:
        return 'Rosa en Burbuja Eterna';
      default:
        return 'Sin Insignia';
    }
  }

  /// Días requeridos para alcanzar el siguiente nivel.
  static int? daysUntilNextLevel(int currentDays) {
    if (currentDays < 1) return 1 - currentDays;
    if (currentDays < 3) return 3 - currentDays;
    if (currentDays < 15) return 15 - currentDays;
    if (currentDays < 30) return 30 - currentDays;
    if (currentDays < 60) return 60 - currentDays;
    if (currentDays < 180) return 180 - currentDays;
    if (currentDays < 360) return 360 - currentDays;
    return null; // Nivel máximo alcanzado
  }

  /// Retorna el asset correspondiente al nivel de amistad [level] (1 a 7).
  static String? iconForLevel(int? level) {
    if (level == null || level < 1) return null;
    switch (level) {
      case 1:
        return level1;
      case 2:
        return level2;
      case 3:
        return level3;
      case 4:
        return level4;
      case 5:
        return level5;
      case 6:
        return level6;
      default:
        return level7;
    }
  }
}
