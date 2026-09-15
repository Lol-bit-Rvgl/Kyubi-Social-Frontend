# Kyubi

**Plataforma social de la comunidad y para la comunidad, desarrollada por Nodo Apps.**

Una aplicación móvil social construida con Flutter (Dart) que ofrece interactividad en tiempo real, salas de roleplay, de cine, chat de voz inmersivo y comunidades con identidad propia.

---

# Características

- **Sala de Roleplay** — Stage en vivo para representar personajes con roles, con moderación presente en todo momento.
- **Chat en vivo** — Mensajería con multimedia, emojis animados, y reacciones animadas.
- **Voz en vivo** — Comunicación de voz en tiempo real con **LiveKit**.
- **Comunidades** — Espacios temáticos con publicaciones, comentarios y seguidores.
- **Perfiles personalizados** — Avatares, biografía, colores de tema y roles visibles.
- **Autenticación** — Google Sign-In y recuperación de contraseña vía deep linking (`kyubi.app/reset-password`).
- **Notificaciones** — Push notifications (Firebase) y locales.
- **Multimedia** — Galería integrada, grabación de audio/vídeo, reproductor de YouTube.
- **Animaciones** — Glassmorphism, Lottie, confetti y transiciones fluidas (créditos a https://github.com/rabbidcoding).

## Stack

| Capas | Tecnologías |
|-------|------------|
| **Lenguaje** | Dart (Flutter SDK ^3.12.2) |
| **UI** | Flutter + Material Design 3 |
| **State Management** | Riverpod (`flutter_riverpod ^2.6.1`) |
| **Routing** | `go_router ^17.5.0` |
| **HTTP** | `dio ^5.11.0` |
| **WebSocket** | `socket_io_client ^3.1.1`, `web_socket_channel ^3.0.3` |
| **Storage** | `flutter_secure_storage ^10.3.1`, `shared_preferences ^2.5.5` |
| **Imágenes** | `cached_network_image ^3.4.1`, `image_picker ^1.2.3` |
| **Audio/Video** | `audioplayers ^6.0.0`, `just_audio ^0.10.6`, `video_player ^2.14.0`, `record ^7.1.1`, `youtube_player_iframe ^6.0.2`, `livekit_client ^2.11.0` |
| **Notificaciones** | Firebase (`firebase_core`, `firebase_messaging`, `firebase_crashlytics`), `flutter_local_notifications ^22.3.0` |
| **Auth social** | `google_sign_in ^6.2.2` |
| **UI extras** | `flutter_animate ^4.5.2`, `lottie ^3.1.2`, `confetti ^0.7.0`, `emoji_picker_flutter ^3.0.0`, `mesh_gradient ^1.3.8`, `google_fonts ^6.2.1`, `photo_view ^0.15.0`, `share_plus ^10.0.0` |
| **Permisos** | `permission_handler ^11.3.1`, `wakelock_plus ^1.5.2`, `gal ^2.3.1` |
| **Serialización** | `freezed_annotation ^3.1.0`, `json_annotation ^4.9.0` (build_runner, freezed, json_serializable) |
| **Cifrado** | `crypto ^3.0.6` |

---

## Estructura del proyecto

```
lib/
├── main.dart                # Punto de entrada
├── app.dart                 # MaterialApp + provider scope
├── routing/                 # Rutas (go_router)
├── models/                  # Entidades: User, Room, Post, ChatMessage, etc.
├── core/                    # Config, constantes, network, storage, theme, utils, widgets
├── features/                # Features: auth, feed, profile, messages, salas, roles, circles, wall
├── repositories/            # Repositorios (capa de datos / API)
└── services/                # Servicios de infraestructura (auth controller, sockets, voice)
```

### Plataformas soportadas

- Android (API 21+)
- iOS
- Web (Flutter Web)
---

## Identidad del cliente

El cliente genera y persiste valores únicos para identificación y sesiones:

| Clave | Descripción | Almacenamiento |
|-------|-------------|----------------|
| `kyubi_device_id` | Identificador único del dispositivo | Secure Storage |
| `kyubi_client_uuid` | UUID persistente de instalación | Secure Storage |
| `kyubi_session_id` | ID de sesión (se regenera al login) | Secure Storage |

Estos valores se envían como metadatos en cada petición HTTP para identificar el cliente.

---

## Tema visual

- **Paleta oscura**: `#0A0A0B` (splash), fondos `#13101E` / `#181424`
- **Acentos teal/cyan**: `#00E5FF`, `#0E3838`
- **Estilo**: Glassmorphism con capas fluidas y gradientes mesh
- **Logo**: `assets/icons/kyubi_logo.jpg` / `assets/icon/app_icon.png`
- Kyubi Mantiene una paleta y estilos dirigidos a la fantasía y el metaverso que nos absorbe cuando entramos en el internet.
---

## Assets

```
assets/
├── animations/       # Animaciones Lottie / custom
├── backgrounds/      # Fondos de pantalla
├── banners/          # Banners promocionales
├── icons/            # Iconos (incluye kyubi_logo.jpg)
├── icon/             # Icono de la app (app_icon.png)
├── images/
│   ├── empty_states/ # Vistas vacías
│   ├── onboarding/   # Imágenes de onboarding
│   ├── splash/       # Splash screen
│   ├── avatars/      # Avatares
│   ├── profile/      # Imágenes de perfil
│   └── store/        # Imágenes de tienda
├── stickers/         # Stickers del chat
└── Emojis/           # Paquete de emojis por categorías
    ├── Smileys and emotions/
    ├── Travel and places/
    ├── Objects/
    ├── People/
    ├── Food and drink/
    ├── Animals and nature/
    ├── Flags/
    └── Activities and events/
```

---

## Tests

El proyecto incluye tests de widget y unitarios en:

```
test/
├── widget_test.dart
├── core/
│   ├── network/
│   │   ├── api_client_test.dart
│   │   └── request_signature_test.dart
│   └── widgets/
│       ├── app_drawer_test.dart
│       └── user_preview_card_test.dart
├── features/
│   ├── auth/
│   │   ├── auth_error_handling_test.dart
│   │   ├── google_sign_in_test.dart
│   │   └── reset_password_flow_test.dart
│   ├── feed/
│   │   └── liquid_glass_layout_test.dart
│   ├── matchmaking/
│   │   └── matchmaking_flow_test.dart
│   ├── messages/
│   │   └── messages_empty_states_test.dart
│   ├── profile/
│   │   ├── hex_color_picker_test.dart
│   │   └── theme_settings_test.dart
│   ├── salas/
│   │   ├── bloque3_verification_test.dart
│   │   ├── chat_identity_selector_test.dart
│   │   ├── critical_bug_fixes_test.dart
│   │   ├── room_invite_friends_test.dart
│   │   └── room_stage_roles_test.dart
│   └── services/
│       └── base_socket_test.dart
```

---

## Configuración

- **minSdk Android**: 21
- **Icono launcher**: `assets/icons/kyubi_logo.jpg` (Android + iOS)
- **Splash**: color `#0A0A0B`, icono `assets/icon/app_icon.png`
- **Web**: deshabilitado en `flutter_native_splash` (solo mobile nativo)

### Permisos por plataforma

- **Android**: INTERNET, ACCESS_NETWORK_STATE, RECORD_AUDIO, MODIFY_AUDIO_SETTINGS, BLUETOOTH, BLUETOOTH_CONNECT, POST_NOTIFICATIONS, FOREGROUND_SERVICE, FOREGROUND_SERVICE_MICROPHONE, FOREGROUND_SERVICE_PHONE_CALL, WAKE_LOCK, READ_MEDIA_IMAGES, READ_EXTERNAL_STORAGE (hasta API 32).
- **iOS**: NSMicrophoneUsageDescription para notas de voz; soporte multi-escena desactivado; orientaciones portrait/landscape.
- **Windows**: Runner nativo Win32 con Flutter engine incrustada.

---

## Desarrollado por

**Nodo Apps** (Desarrollador principal: https://github.com/Lol-bit-Rvgl)

---

## Licencia

Proyecto privado de Nodo Apps (`publish_to: 'none'` en pubspec.yaml).

---

> **Kyubi Community** — Conecta, crea y vive experiencias sociales únicas en un espacio diseñado para la comunidad, por la comunidad.



