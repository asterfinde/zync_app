# WORK_PLAN_JOIN_APPROVAL.md — Plan de Trabajo: Aprobación del Creador para Ingreso al Círculo

> Documento técnico que describe el modelo de datos, la lógica y los cambios de UI
> necesarios para implementar el flujo de aprobación del creador.
> Decisión tomada: 2026-03-22
> Opción elegida: **A — Rechazado permanente de ese círculo** (puede crear o unirse a otro)

---

## Contexto y decisión

Sin este cambio, cualquier usuario que ingrese un código de invitación válido entra
automáticamente al círculo. Esto contradice la filosofía de círculo íntimo de ZYNC.

Con la aprobación del creador:
- El usuario que ingresa el código queda en estado **pendiente**.
- El creador del círculo recibe la solicitud, ve el nickname y email del solicitante,
  y decide aceptar o rechazar.
- Si acepta → el usuario ingresa al círculo.
- Si rechaza → el usuario no puede volver a solicitar ingreso a ese mismo círculo.
  Puede crear su propio círculo o usar el código de otro.

---

## Modelo de datos

### Nueva sub-colección: `circles/{circleId}/joinRequests/{userId}`

| Campo | Tipo | Descripción |
|---|---|---|
| `nickname` | String | Copiado del doc del solicitante al momento de la solicitud |
| `email` | String | Copiado del doc del solicitante al momento de la solicitud |
| `requestedAt` | Timestamp | Momento en que se envió la solicitud |
| `status` | String | `"pending"` · `"approved"` · `"rejected"` |

**Por qué se desnormalizan nickname y email:** El creador necesita leer esos datos
para tomar la decisión, pero según las reglas de Firestore actuales no puede leer el
documento de `users/{userId}` de alguien que todavía no es miembro de su círculo.
Al almacenarlos en el joinRequest (que pertenece a `circles/{circleId}/`), el creador
puede leerlos con los permisos ya existentes.

**Reglas de Firestore:** No requieren cambios. La regla existente
`match /circles/{circleId}/{document=**}` ya cubre esta sub-colección.

### Campo nuevo en `users/{userId}`

| Campo | Tipo | Descripción |
|---|---|---|
| `pendingCircleId` | String? | ID del círculo donde hay una solicitud pendiente. `null` si no hay ninguna. |

Este campo permite a la app saber en qué estado está el usuario sin necesidad de
hacer consultas adicionales a Firestore.

### Campo nuevo en `circles/{circleId}` (ya planificado en WORK_PLAN_CIRCLE_RULES.md)

| Campo | Tipo | Descripción |
|---|---|---|
| `creatorId` | String | UID del creador del círculo. Necesario para saber a quién notificar y a quién mostrar las solicitudes. |

---

## Estados posibles del usuario

El `HomePage` actualmente maneja dos estados (tiene círculo / no tiene círculo).
Pasa a manejar tres:

| Estado | Condición en Firestore | Vista que se muestra |
|---|---|---|
| En un círculo | `users/{uid}.circleId` existe | `InCircleView` (existente) |
| Solicitud pendiente | `users/{uid}.pendingCircleId` existe | `PendingRequestView` (nueva) |
| Sin círculo | Ninguno de los anteriores | `NoCircleView` (existente) |

---

## Flujo completo

### Lado del solicitante (Usuario B)

```
B ingresa código en JoinCircleView
        ↓
requestToJoinCircle(code) — nuevo método en CircleService
  1. Valida código → encuentra el círculo
  2. ¿B ya es miembro? → error "Ya eres miembro de este círculo"
  3. ¿B ya tiene pendingCircleId? → error "Ya tienes una solicitud pendiente"
  4. ¿Existe joinRequest con status "rejected" para B en este círculo?
     → error "Tu solicitud fue rechazada anteriormente por este círculo"
  5. Batch de Firestore:
     - Crea circles/{circleId}/joinRequests/{uid} con status "pending"
     - Actualiza users/{uid} { pendingCircleId: circleId }
        ↓
B ve PendingRequestView: "Tu solicitud fue enviada. Esperando que el creador la apruebe."
        ↓
Stream de users/{uid} escucha cambios en pendingCircleId y circleId
  → Si circleId aparece → stream lo detecta → transición automática a InCircleView ✅
  → Si pendingCircleId desaparece sin circleId → transición a NoCircleView con mensaje de rechazo
```

### Lado del creador (Usuario A)

```
A tiene el app abierta → InCircleView escucha sub-colección joinRequests
        ↓
Aparece nueva solicitud pendiente → se muestra sección/badge en InCircleView
        ↓
A toca la solicitud → ve tarjeta con:
  · Nickname del solicitante
  · Email del solicitante
  · Hace cuánto tiempo envió la solicitud
  · Botones [Rechazar] [Aceptar]
        ↓
    A acepta → approveJoinRequest(requestingUserId)
      Batch de Firestore:
        - joinRequests/{userId}.status = "approved"
        - circles/{circleId}.members += [userId]
        - circles/{circleId}.memberStatus.{userId} = { statusType: "fine", ... }
        - users/{userId}.circleId = circleId
        - users/{userId}.pendingCircleId = FieldValue.delete()
      → B automáticamente ve InCircleView gracias al stream

    A rechaza → rejectJoinRequest(requestingUserId)
      Batch de Firestore:
        - joinRequests/{userId}.status = "rejected"
        - users/{userId}.pendingCircleId = FieldValue.delete()
      → B automáticamente ve NoCircleView con mensaje de rechazo
```

---

## Notificaciones al creador

**Situación actual:** La app usa `flutter_local_notifications` únicamente.
Las notificaciones locales solo funcionan cuando la app está abierta o en background
reciente. No hay FCM (Firebase Cloud Messaging) instalado.

**Implicación práctica:**
- Si el creador tiene la app abierta o en background → el stream de Firestore actualiza
  `InCircleView` en tiempo real y el creador ve la solicitud inmediatamente.
- Si el creador tiene la app completamente cerrada → no recibirá notificación hasta
  que abra la app.

**Recomendación para MVP:** Aceptar esta limitación y documentarla. El flujo funciona
correctamente; solo la notificación push cuando la app está cerrada no existe todavía.
Agregar FCM es trabajo para v1.1. No requiere aprobación de dependencias ahora.

---

## Archivos impactados

| Archivo | Tipo de cambio | Detalle |
|---|---|---|
| `lib/services/circle_service.dart` | Modificación | Agregar `requestToJoinCircle()`, `approveJoinRequest()`, `rejectJoinRequest()`. Modificar `getUserCircleStream()` para emitir tri-estado. |
| `lib/features/circle/presentation/pages/home_page.dart` | Modificación | Lógica de tri-estado: InCircleView / PendingRequestView / NoCircleView. |
| `lib/features/circle/presentation/widgets/join_circle_view.dart` | Modificación | Llamar a `requestToJoinCircle()` en lugar de `joinCircle()`. |
| `lib/features/circle/presentation/widgets/in_circle_view.dart` | Modificación | Agregar sección de solicitudes pendientes visible solo para el creador. |
| `lib/features/circle/presentation/widgets/pending_request_view.dart` | **NUEVO** | Pantalla de espera para el solicitante mientras su solicitud está pendiente. |

**Archivos que NO se tocan:**
- `NoCircleView` — el flujo de "crear o unirse" no cambia.
- `CreateCircleView` — la creación de círculo no cambia.
- Reglas de Firestore — los permisos ya cubren la nueva sub-colección.

---

## Orden de ejecución recomendado

| Paso | Tarea | Dependencias |
|---|---|---|
| 1 | Agregar `requestToJoinCircle()` en `CircleService` | Ninguna |
| 2 | Agregar `approveJoinRequest()` y `rejectJoinRequest()` en `CircleService` | Paso 1 |
| 3 | Modificar `getUserCircleStream()` para emitir tri-estado | Pasos 1 y 2 |
| 4 | Crear `PendingRequestView` | Paso 3 |
| 5 | Modificar `HomePage` para manejar tri-estado | Pasos 3 y 4 |
| 6 | Modificar `JoinCircleView` para llamar a `requestToJoinCircle()` | Paso 1 |
| 7 | Modificar `InCircleView` para mostrar solicitudes pendientes al creador | Paso 2 |

Los pasos 1–3 son backend puro. Los pasos 4–7 son UI y dependen del backend.
Ejecutar en ese orden evita implementar UI sobre lógica incompleta.

---

## Interacción con WORK_PLAN_CIRCLE_RULES.md

Este plan **depende** de que Brecha 2 de `WORK_PLAN_CIRCLE_RULES.md` esté implementada
primero, específicamente el campo `creatorId` en el modelo `Circle`. Sin ese campo:
- `InCircleView` no puede saber si el usuario actual es el creador para mostrarle
  las solicitudes pendientes.
- `approveJoinRequest()` y `rejectJoinRequest()` no pueden validar que quien aprueba
  o rechaza es efectivamente el creador.

**Orden recomendado entre los dos planes:**
1. Primero: Brecha 1 + Brecha 2 de `WORK_PLAN_CIRCLE_RULES.md`
2. Luego: este plan (`WORK_PLAN_JOIN_APPROVAL.md`)

---

## Tests nuevos requeridos (para agregar a TEST_PLAN.md)

| ID | Tipo | Caso de prueba | Resultado esperado |
|---|---|---|---|
| T2.10 | 👁 Manual | Solicitud de ingreso — solicitante queda en estado pendiente | B ingresa código, ve pantalla de espera. En Firestore: `joinRequests/{uid}` con status "pending", `users/{uid}.pendingCircleId` seteado. |
| T2.11 | 👁 Manual | Creador aprueba solicitud | A ve la solicitud en InCircleView y aprueba. B pasa automáticamente a InCircleView. En Firestore: `joinRequests/{uid}.status = "approved"`, `users/{uid}.circleId` seteado. |
| T2.12 | 👁 Manual | Creador rechaza solicitud | A rechaza. B regresa a NoCircleView con mensaje. En Firestore: `joinRequests/{uid}.status = "rejected"`, `pendingCircleId` eliminado. |
| T2.13 | 👁 Manual | Solicitante rechazado intenta unirse de nuevo al mismo círculo | App muestra error "Tu solicitud fue rechazada anteriormente". No se crea nueva solicitud. |
| T2.14 | 👁 Manual | Solicitante rechazado crea su propio círculo | Después del rechazo, B puede crear un círculo nuevo sin restricción. |
| T2.15 | 👁 Manual | No se puede enviar segunda solicitud mientras hay una pendiente | Con `pendingCircleId` activo, el botón de unirse queda bloqueado o muestra error. |
