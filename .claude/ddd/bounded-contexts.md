# Bounded Contexts — ZYNC

> Mapa de los contextos del dominio de ZYNC con sus fronteras,
> responsabilidades y relaciones entre sí.
> Cada feature post-MVP debe declarar a qué Bounded Context pertenece.

---

## Mapa de Contextos

```
┌──────────────────────┐   ┌──────────────────────┐   ┌──────────────────────┐
│   Circle Management  │   │  Messaging / Status   │   │   Safety / SOS       │
│                      │   │                       │   │                      │
│  Circle              │   │  Status               │   │  SOSEvent            │
│  Member              │   │  StatusType           │   │  Location            │
│  Circle Owner        │   │  PredefinedEmoji      │   │                      │
│  JoinRequest         │   │  CustomEmoji          │   │                      │
│  InvitationCode      │   │  CircleStatus         │   │                      │
│  QuickAction         │   │  Zone                 │   │                      │
│                      │   │  ZoneEvent            │   │                      │
└──────────┬───────────┘   └──────────┬────────────┘   └──────────┬───────────┘
           │                          │                            │
           │  MemberJoinedCircle      │  StatusSent                │  SOSActivated
           │  MemberLeftCircle        │  StatusAutoUpdated         │
           │  CircleDeleted           │  ZoneEntered / ZoneExited  │
           └──────────────────────────┴────────────────────────────┘
                              Domain Events (Firestore streams / FCM)

┌──────────────────────┐
│   Configuration      │
│                      │
│  QuickAction config  │
│  CustomEmoji mgmt    │
│  Zone setup          │
└──────────────────────┘
   Depende de: Circle Management + Messaging
```

---

## Circle Management

**Responsabilidad:** Gestión del ciclo de vida de Circles y Members.

**Entidades:** Circle, Member, Circle Owner, JoinRequest, InvitationCode

**Casos de uso implementados (MVP):**
- Crear un Circle
- Generar InvitationCode
- Enviar JoinRequest con código
- Circle Owner aprueba JoinRequest
- JoinRequest expira a las 48h (lazy expiration)
- Member elimina su cuenta → removido del Circle
- Circle Owner elimina su cuenta → Circle eliminado + todos los Members desvinculados
- Filosofía "estás o no estás": no existe salir del Circle sin eliminar cuenta

**Colecciones Firebase:**
- `circles` — datos del Circle, memberStatus, memberIds
- `users` — datos del Member, circleId, pendingCircleId
- `circles/{id}/joinRequests/{uid}` — JoinRequests con estado y timestamp

**Emite eventos:** `MemberJoinedCircle`, `MemberLeftCircle`, `CircleDeleted`, `JoinRequestExpired`

**Depende de:** ninguno (es el contexto base)

**Archivos principales:**
- `lib/services/circle_service.dart`
- `lib/features/circle/presentation/widgets/in_circle_view.dart`
- `lib/features/circle/presentation/widgets/no_circle_view.dart`
- `lib/features/circle/presentation/widgets/join_circle_view.dart`
- `lib/features/circle/presentation/widgets/create_circle_view.dart`
- `lib/providers/circle_provider.dart`

---

## Messaging / Status

**Responsabilidad:** Envío y visualización de Status entre Members de un Circle.
Incluye actualizaciones automáticas de Status por ZoneEvents (geofencing).

**Entidades:** Status, StatusType, PredefinedEmoji, CustomEmoji, CircleStatus, Zone, ZoneEvent

**Casos de uso implementados (MVP):**
- Member envía Status manual desde el modal
- Status por defecto al unirse: `fine` (Todo bien)
- CircleStatus muestra último Status de cada Member con timestamp relativo
- Indicadores: ✋ Manual, 🤖 Auto-actualizado, ❓ Ubicación desconocida
- Zone detecta entrada/salida por GPS → actualiza Status automáticamente
- Entrada a Zone predefinida: emoji del tipo (🏠🏫🎓💼)
- Salida de Zone: Status cambia a `driving` 🚗 (En camino)
- Debounce de 2 minutos entre ZoneEvents para evitar duplicados
- Simulador de debug de geofencing disponible en ZonesPage (ícono 🐛)

**Colecciones Firebase:**
- `users/{uid}.memberStatus` — Status actual del Member
- `circles/{id}/memberStatus/{uid}` — Status en el contexto del Circle
- `predefinedEmojis` — catálogo central
- `circles/{id}/customEmojis` — emojis del Circle
- `circles/{id}/zones/{id}` — Zones configuradas
- `circles/{id}/zone_events/{id}` — historial de ZoneEvents

**Emite eventos:** `StatusSent`, `StatusAutoUpdated`, `ZoneEntered`, `ZoneExited`

**Depende de:** Circle Management (saber si el Member pertenece al Circle)

**Archivos principales:**
- `lib/core/services/status_service.dart`
- `lib/core/services/emoji_service.dart`
- `lib/core/services/emoji_management_service.dart`
- `lib/features/geofencing/services/geofencing_service.dart`
- `lib/features/geofencing/services/zone_service.dart`
- `lib/features/geofencing/services/zone_event_service.dart`
- `lib/core/widgets/emoji_modal.dart`
- `lib/widgets/status_selector_overlay.dart`
- `lib/widgets/notification_status_selector.dart`

---

## Safety / SOS

**Responsabilidad:** Gestión de la función crítica de SOS con ubicación GPS.

**Entidades:** SOSEvent, Location

**Casos de uso definidos (post-MVP / parcialmente implementados):**
- Member activa SOS con Location GPS obligatoria
- Todos los Members del Circle reciben alerta de máxima prioridad
- Member puede ver Location del Member en SOS
- Member desactiva SOS

**Colecciones Firebase:**
- `circles/{id}/sos_events` — pendiente de definir estructura final

**Emite eventos:** `SOSActivated`

**Depende de:** Circle Management (lista de Members a alertar),
Messaging (canal de notificación push FCM)

**Restricción crítica:** Las notificaciones de SOS no deben ser bloqueadas
por el estado de la app (foreground / background / killed).
Tienen prioridad máxima sobre cualquier otra notificación.

**Archivos principales:**
- `lib/widgets/sos_gps_test_widget.dart` (implementación parcial MVP)
- `lib/core/services/gps_service.dart`

---

## Configuration

**Responsabilidad:** Preferencias y configuraciones del Member dentro de su Circle.

**Entidades:** QuickAction config, CustomEmoji management, Zone setup

**Casos de uso implementados (MVP):**
- Member configura hasta 4 QuickActions (accesos rápidos nativos)
- Circle Owner crea y elimina CustomEmojis del Circle
- Circle Owner crea, edita y elimina Zones del Circle
- Gestión de permisos de Location (requerido para geofencing y SOS)

**Colecciones Firebase:**
- `circles/{id}/customEmojis`
- `circles/{id}/zones/{id}`
- SharedPreferences local — configuración de QuickActions

**Depende de:** Circle Management + Messaging

**Archivos principales:**
- `lib/features/settings/presentation/pages/settings_page.dart`
- `lib/features/settings/presentation/pages/emoji_management_page.dart`
- `lib/features/geofencing/presentation/pages/zones_page.dart`
- `lib/core/services/quick_actions_preferences_service.dart`
- `lib/quick_actions/quick_actions_service.dart`

---

## Reglas de interacción entre contextos

1. Los contextos se comunican **solo a través de Domain Events** y Firestore streams.
   Nunca acceden directamente a los datos internos del otro contexto.
2. **Safety / SOS tiene prioridad máxima** de notificación sobre Messaging.
3. Un Member pertenece a **un solo Circle** simultáneamente (restricción MVP).
4. **Circle Management es el contexto base**: los demás dependen de él.
5. Configuration **no emite Domain Events** — sus cambios son persistidos
   localmente (SharedPreferences) o en Firestore (CustomEmojis, Zones).
6. Los ZoneEvents en Messaging **no requieren acción del Member** —
   son disparados automáticamente por el GeofencingService.
