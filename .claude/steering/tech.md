# Tech Stack — ZYNC

## Stack Principal

| Componente | Tecnología | Versión |
|---|---|---|
| Framework UI | Flutter | 3.38.2 |
| Lenguaje | Dart | 3.10.0 |
| State Management | Flutter Riverpod | ^2.5.1 |
| Inyección de dependencias | get_it | ^7.7.0 |
| Auth | Firebase Authentication | ^5.3.1 |
| Base de datos | Cloud Firestore | ^5.2.0 |
| Storage | Firebase Storage | (incluido en firebase_core) |
| AI | Anthropic Claude Sonnet API | claude-sonnet-4-6 |
| Push Notifications | Firebase Cloud Messaging (FCM) | vía firebase_core |
| GPS / Geolocation | geolocator | ^14.0.2 |
| Mapas | google_maps_flutter | ^2.10.0 |
| Geocoding | geocoding | ^3.0.0 |
| Foreground Service | flutter_foreground_task | ^9.1.0 |
| Notificaciones locales | flutter_local_notifications | ^17.2.2 |
| Home Widget | home_widget | ^0.6.0 |
| App Badge | app_badge_plus | ^1.1.6 |
| Permisos | permission_handler | ^12.0.1 |
| Preferencias locales | shared_preferences | ^2.2.3 |
| Conectividad | connectivity_plus | ^6.1.5 |
| Emoji picker | emoji_picker_flutter | ^3.0.0 |
| Fuentes | google_fonts | ^6.3.1 |
| Fechas | intl | ^0.19.0 |
| Programación funcional | dartz | ^0.10.1 |

## Plataformas objetivo

| Plataforma | Estado | Versión mínima |
|---|---|---|
| Android | Activa | API 21 (Android 5.0) |
| iOS | Roadmap | A definir |

## App ID
`com.datainfers.zync`

## Permisos Android declarados

| Permiso | Propósito |
|---|---|
| `INTERNET` | Firebase, FCM, API Claude |
| `FOREGROUND_SERVICE` | KeepAlive + notificación de estado |
| `FOREGROUND_SERVICE_LOCATION` | Geofencing en foreground |
| `FOREGROUND_SERVICE_SPECIAL_USE` | QuickActions desde notificación |
| `POST_NOTIFICATIONS` | Notificaciones push FCM y locales |
| `WAKE_LOCK` | Mantener proceso vivo (patrón WhatsApp) |
| `ACCESS_FINE_LOCATION` | GPS preciso para ZoneEvents y SOS |
| `ACCESS_COARSE_LOCATION` | GPS aproximado |
| `ACCESS_BACKGROUND_LOCATION` | Geofencing cuando app está en background |

## Activities nativas (Android)

| Activity | Propósito |
|---|---|
| `MainActivity` | Actividad principal Flutter |
| `QuickStatusDialogActivity` | Modal de status desde notificación |
| `StatusModalActivity` | Modal de status alternativo |
| `EmojiDialogActivity` | Selector de emoji instantáneo con cache |
| `QuickActionActivity` | Procesa QuickActions sin mostrar UI |

## Servicios nativos (Android)

| Servicio | Propósito |
|---|---|
| `ForegroundService` (flutter_foreground_task) | Mantiene GPS activo en background |
| `KeepAliveService` | Mantiene proceso vivo (patrón WhatsApp/Telegram) |

## Colecciones Firestore existentes

| Colección | Contenido |
|---|---|
| `circles` | Circle data, memberStatus, memberIds, joinRequests, customEmojis, zones, zone_events |
| `users` | Member data, circleId, pendingCircleId, nickname |
| `predefinedEmojis` | Catálogo central de PredefinedEmojis (solo lectura para usuarios) |

## Quick Actions — Implementación nativa
Las QuickActions usan implementación 100% nativa via `NativeShortcutManager.kt`.
El paquete `quick_actions` de pub.dev está deshabilitado.

## Restricciones técnicas
- No agregar dependencias sin aprobación explícita del desarrollador.
- No migrar de Riverpod sin decisión explícita.
- No crear colecciones Firestore nuevas sin aprobación.
- No modificar Security Rules sin aprobación.
- Toda lectura/escritura a Firestore va en `services/`. Nunca en widgets.
- No usar `print()` — usar `debugPrint()` o `log()`.

## Decisiones técnicas heredadas del MVP

| Fecha | Decisión |
|---|---|
| 2026-03-16 | `auth_final_page.dart` es el único archivo activo de auth |
| 2026-03-17 | Solo el creador puede eliminar el Circle (via eliminación de cuenta) |
| 2026-03-17 | MVP: un único Circle por usuario |
| 2026-03-27 | Filosofía "estás o no estás" — sin salir del Circle sin eliminar cuenta |
| — | Se descartó Clean Architecture — estructura por features |
| — | Se descartó Patrol para testing — se usa flutter_test estándar |

## Testing

| Tipo | Framework | Ubicación |
|---|---|---|
| Unitarios | flutter_test | `test/` |
| Integración | integration_test (SDK oficial) | `integration_test/` |

Device ID de pruebas: `R58W315389R` (SM A145M — Android 15)
