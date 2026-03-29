# Ubiquitous Language — ZYNC

> Glosario oficial del dominio. Cada término aquí definido debe usarse
> con exactitud en conversaciones, Gherkin, código y documentación.
> Nunca usar sinónimos. Si un término nuevo emerge, agregarlo aquí
> antes de usarlo en cualquier spec.
>
> Responsabilidad: el desarrollador aprueba cada nuevo término.
> La IA propone, el desarrollador decide.

---

## Términos del Dominio

### Circle
Grupo cerrado de confianza creado por un usuario. Un Circle tiene exactamente
un Circle Owner y uno o más Members. MVP: un usuario pertenece a un solo Circle
simultáneamente.
- No es: "grupo", "equipo", "sala", "chat"
- Sinónimos prohibidos: group, team, room, chat

### Circle Owner
El usuario que creó el Circle. Tiene permisos de administración sobre el Circle
(aprobar solicitudes de ingreso). Al eliminar su cuenta, el Circle entero se elimina.
- No es: "admin", "creador", "dueño"
- Sinónimos prohibidos: admin, creator, owner

### Member
Usuario que pertenece a un Circle. Puede enviar y recibir Status. Al eliminar
su cuenta, solo ese Member es removido; el Circle permanece intacto.
- No es: "usuario", "participante", "contacto"
- Sinónimos prohibidos: user, participant, contact

### Status
Emoji o imagen predefinida que un Member envía a su Circle. Representa su estado
o situación actual. Puede ser manual (elegido por el Member) o automático
(generado por un ZoneEvent).
- No es: "mensaje", "señal", "notificación"
- Sinónimos prohibidos: message, signal, notification

### StatusType
Identificador del tipo de Status. Valores actuales del sistema:
`fine`, `studying`, `busy`, `driving`, y los predefinidos del catálogo.
- No es: "estado", "tipo de emoji"
- Sinónimos prohibidos: state, emojiType

### PredefinedEmoji
Emoji o imagen disponible en el catálogo de ZYNC para ser usado como Status.
Administrado centralmente vía Firestore. No modificable por el usuario.
- No es: "emoji del sistema", "emoji base"
- Sinónimos prohibidos: systemEmoji, baseEmoji

### CustomEmoji
Emoji creado por un Circle Owner para su Circle específico. Vive en
`circles/{id}/customEmojis`. Visible solo para los Members de ese Circle.
- No es: "emoji personalizado", "emoji propio"
- Sinónimos prohibidos: personalEmoji, userEmoji

### JoinRequest
Solicitud enviada por un usuario para ingresar a un Circle usando un
Invitation Code. Tiene estado: `pending` / `approved` / `expired`.
Expira automáticamente a las 48 horas (lazy expiration).
- No es: "solicitud de ingreso", "petición"
- Sinónimos prohibidos: joinPetition, accessRequest

### InvitationCode
Código único generado al crear un Circle. El Circle Owner lo comparte
para que otros usuarios envíen un JoinRequest.
- No es: "código de invitación", "link de acceso"
- Sinónimos prohibidos: inviteCode, accessCode

### SOS
Tipo especial de Status que adjunta la Location GPS actual del Member y genera
una alerta de prioridad máxima para todos los Members del Circle.
La Location siempre es obligatoria en un SOS — no es opcional.
- No es: "alerta", "emergencia" (aunque describe una)
- Sinónimos prohibidos: alert, emergency, panic

### SOSEvent
Domain Event generado cuando un Member activa un SOS.
Contiene: memberId, circleId, timestamp, location (lat/lng).
- Sinónimos prohibidos: sosAlert, emergencyEvent

### Location
Coordenadas GPS (latitud + longitud) adjuntas a un SOSEvent.
- No es: "dirección", "posición", "GPS"
- Sinónimos prohibidos: address, position, coordinates

### Zone
Área geográfica circular configurada en un Circle, definida por coordenadas
y radio en metros. Puede ser predefinida (🏠 home, 🏫 school, 🎓 university,
💼 work) o personalizada (📍 custom). Máximo 10 zonas por Circle.
- No es: "área", "región", "geovalla"
- Sinónimos prohibidos: area, region, geofence

### ZoneEvent
Evento generado cuando un Member entra o sale de una Zone.
Tipo: `entry` (entrada) o `exit` (salida).
Al entrar: Status se actualiza con el emoji de la Zone.
Al salir: Status cambia automáticamente a `driving` (🚗 En camino).
- Sinónimos prohibidos: locationEvent, gpsEvent

### QuickAction
Acceso directo nativo del SO (long press sobre el ícono de la app) que
permite al Member enviar un Status predefinido sin abrir la app.
Cada Member configura hasta 4 QuickActions.
- No es: "acceso rápido", "shortcut"
- Sinónimos prohibidos: shortcut, fastAction

### CircleStatus
Vista agregada del estado actual de todos los Members de un Circle.
Muestra el último Status enviado por cada Member con timestamp relativo.
- Sinónimos prohibidos: circleView, membersStatus

---

## Domain Events

| Evento | Cuándo ocurre | Datos clave |
|--------|---------------|-------------|
| `MemberJoinedCircle` | Circle Owner aprueba un JoinRequest | memberId, circleId |
| `StatusSent` | Un Member envía un Status | memberId, circleId, statusType, timestamp |
| `StatusAutoUpdated` | Un ZoneEvent actualiza el Status | memberId, circleId, zoneId, statusType |
| `SOSActivated` | Un Member activa un SOS | memberId, circleId, location, timestamp |
| `MemberLeftCircle` | Un Member elimina su cuenta | memberId, circleId |
| `CircleDeleted` | Circle Owner elimina su cuenta | circleId, memberIds[] |
| `ZoneEntered` | Member entra a una Zone | memberId, circleId, zoneId |
| `ZoneExited` | Member sale de una Zone | memberId, circleId, zoneId |
| `JoinRequestExpired` | JoinRequest supera 48h sin respuesta | memberId, circleId |

---

## Términos Técnicos Mapeados al Dominio

| Término técnico (Firebase / Código) | Término del dominio |
|--------------------------------------|---------------------|
| `circles` collection | Circle |
| `users` collection | Member / Circle Owner |
| `predefinedEmojis` collection | PredefinedEmoji |
| `circles/{id}/customEmojis` | CustomEmoji |
| `circles/{id}/joinRequests/{uid}` | JoinRequest |
| `circles/{id}/zone_events/{id}` | ZoneEvent |
| `circles/{id}/zones/{id}` | Zone |
| `circleId` field | identificador de Circle |
| `uid` (Firebase Auth) | identificador de Member |
| `memberStatus.{uid}` | Status actual del Member en el Circle |
| `statusType` field | StatusType |
| `autoUpdated: true` | Status generado por ZoneEvent (no manual) |
| `pendingCircleId` field en users | Circle al que el usuario envió un JoinRequest |
