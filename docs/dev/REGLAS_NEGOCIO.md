# Estados / Emojis — ZYNC App (Vista de Producto)

> Documento orientado a producto: describe el comportamiento visible en el Círculo para el usuario.
> Para la especificación técnica formal (máquina de estados, transiciones, Firestore schema), ver:
> `docs/dev/maquina-estados.md`
>
> **Última revisión:** 2026-04-14
> **Estado:** Actualizado para reflejar lo implementado hasta el momento.

---

## 0. Principio rector — No hay estados temporales

**El estado de un usuario persiste tal como fue establecido, sin resets automáticos.**

La fuente de la verdad es siempre el último estado registrado, ya sea:
- el que el usuario seleccionó manualmente, o
- el que el Geofencing determinó al entrar/salir de una Zona.

**No existe ningún mecanismo que expire, limpie o reemplace un estado por el paso del tiempo, por cerrar la app, por hacer logout o por reabrir la sesión.** El estado cambia únicamente cuando:

1. El usuario selecciona uno nuevo manualmente.
2. El Geofencing detecta una entrada o salida de Zona.
3. El usuario activa Modo Silencio (escribe `do_not_disturb` explícitamente).

Cualquier comportamiento que resetee el estado a `fine` u otro valor por defecto es un **bug**, no una feature.

---

## 1. Comportamiento base

### 1.1 Sin Zonas configuradas (comportamiento default)

Cuando el usuario no tiene Zonas de Geofencing configuradas:

- Puede seleccionar cualquier estado/emoji libremente (incluyendo "En camino").
- El Círculo muestra siempre:
  - Línea 1: `emoji + nickname` (ej: 📚 Mauricio)
  - Línea 2: nombre del estado (ej: Estudiando)
  - Línea 3: timestamp relativo (ej: Justo Ahora / Hace 15 min / Hace 2 h / Hace 1 d)
- **No aparecen** los indicadores ✋ Manual ni ❓ Ubicación desconocida.

### 1.2 Con Zonas configuradas + Geofencing activo

Cuando el usuario tiene Zonas configuradas (Casa, Colegio, Universidad, Trabajo, Personalizada):

- **Geofencing controla automáticamente** el estado al entrar/salir de una Zona.
- El usuario **NO puede seleccionar Zonas manualmente** — ver sección 3.
- El usuario **sí puede** seleccionar manualmente cualquier estado que no sea Zona (incluyendo "En camino").

---

## 2. Indicadores visuales (badges)

Además del estado principal y el timestamp, el Círculo puede mostrar indicadores informativos:

### 2.1 ✋ Manual

**Se muestra cuando:** el usuario sobreescribe deliberadamente un estado que el Geofencing puso automáticamente al detectar una Zona (entrada a Zona).

**Solo aplica cuando:** el usuario estaba físicamente EN la Zona (estado auto-detectado activo) y eligió otro estado distinto.

**No se muestra cuando:**
- El usuario no tiene Zonas configuradas.
- El usuario cambió de un estado manual a otro estado manual.
- El usuario cambió desde el estado automático "En camino" (salida de Zona).

**Se desactiva cuando:** el Geofencing detecta cualquier evento (entrada o salida de Zona).

> **Nota de implementación:** ✋ Manual es exclusivo del estado interno `MANUAL_EN_ZONA`.
> Ver `maquina-estados.md` §4.3.

### 2.2 ❓ Ubicación desconocida

**Se muestra cuando** al menos una de estas condiciones se cumple:

- El usuario está fuera de todas las Zonas configuradas.
- El GPS o permiso de ubicación está fallando / no disponible.

**Condición en el código:** aparece si el estado anterior fue automático (Geofencing) Y el usuario ya salió de la Zona Y el nuevo estado elegido no es `fine` (Todo bien).

> **Nota:** este badge puede coexistir con ✋ Manual en escenarios muy específicos, pero la regla
> predominante es que ✋ Manual requiere que el usuario siga DENTRO de la Zona, lo cual es
> incompatible con "fuera de zonas" (condición para ❓). En la práctica aparecen en contextos mutuamente excluyentes.

---

## 3. Casos de uso principales

### 3.1 Selección manual dentro de una Zona activa

El Geofencing detectó que el usuario está en Casa. Sin salir de ahí, el usuario cambia su estado a "Estudiando":

```
📚 Mauricio
Estudiando
Hace 15 min
✋ Manual
```

**❓ Ubicación desconocida NO aparece** — el usuario físicamente sigue en la Zona conocida.

### 3.2 Selección manual después de salir de una Zona

El Geofencing detectó que el usuario salió de Casa → estado automático "En camino". Luego el usuario elige "Estudiando" manualmente:

```
📚 Mauricio
Estudiando
Hace 15 min
❓ Ubicación desconocida
```

**✋ Manual NO aparece** — el usuario no está sobreescribiendo una Zona activa; está eligiendo un estado desde "En camino".

> **Corrección respecto a borrador anterior:** el borrador mostraba ambos indicadores (✋ Manual +
> ❓ Ubicación desconocida) en este escenario. El comportamiento correcto (validado en Prueba B3
> y T3.30.2 del TEST_PLAN) es que ✋ Manual **solo aplica sobre estados automáticos de Zona**,
> no sobre "En camino". Solo aparece ❓ Ubicación desconocida.

### 3.3 Cambio de Zona por otra Zona — NO PERMITIDO

El usuario intenta seleccionar manualmente una Zona (ej: "Casa") cuando tiene Zonas configuradas:

- El estado NO cambia.
- Aparece un **modal evidente** con fondo gris claro, texto negro:
  - Título: `Acción no permitida`
  - Mensaje: "No puedes seleccionar zonas manualmente. El estado de zonas se actualiza automáticamente por geofencing."
  - Botón: `Entendido`
- El timestamp NO cambia.

### 3.4 "En camino" — doble uso

"En camino" puede usarse de dos formas:

1. **Automático:** Geofencing detecta salida de cualquier Zona → estado pasa a "En camino" automáticamente.
2. **Manual:** si no hay Zonas configuradas, el usuario puede elegir "En camino" como cualquier otro estado. No aparece ✋ Manual.

---

## 4. Timestamp

El timestamp es la "huella" de cualquier cambio visible en el estado del Círculo. Se actualiza ante:

- Cambio de estado principal (manual o automático por Geofencing).
- Cambio en la visibilidad de un indicador (✋ Manual, ❓ Ubicación desconocida).

### Formato

| Condición | Formato |
|-----------|---------|
| Momento < 60 segundos | `Justo Ahora` |
| Momento < 60 minutos | `Hace X min` |
| Momento < 24 horas | `Hace Y h` |
| Momento ≥ 1 día | `Hace Z d` |

---

## 5. Reglas de Geofencing

- **Entrada a Zona:** estado principal → emoji/nombre de la Zona. Timestamp actualizado. ✋ Manual desactivado.
- **Salida de Zona:** estado principal → 🙂 "Bien" (`fine`). Timestamp actualizado. ✋ Manual desactivado.
- **GPS siempre gana:** cualquier evento de Geofencing (entrada/salida) sobrescribe cualquier estado manual sin excepción.
- **Zonas solapadas:** si múltiples Zonas coinciden, gana la de menor radio. En empate: la creada primero. *(Implementado PR #54)*

---

## 6. Estado al iniciar sesión / reabrir la app

Al reabrir la app (sesión existente, sin logout previo):

- La app lee el último emoji/estado del usuario desde Firebase.
- **No se resetea** el estado a "Todo bien (fine)".
- Si el usuario hizo logout deliberado, el estado previo al logout se restaura al re-login.

> **Estado actual (2026-04-14):** este comportamiento tiene un bug activo. Ver Deuda Técnica §1.

---

## Deuda Técnica

### DT-1 — `clearOfflineStatus()` resetea el emoji al re-login 🔴 ALTA

**Descripción:** Al reabrir la app o hacer login, `StatusService.clearOfflineStatus()` en
`lib/core/services/status_service.dart:290` sobreescribe el `statusType` con `'fine'`
(hardcodeado), en lugar de solo eliminar el flag `loggedOut`.

**Consecuencias visibles:**
- El usuario que tenía "Universidad" ve "Todo bien" al reabrir la app.
- El usuario que tenía "Reunión" ve "Todo bien" tras un re-login.
- Afecta también la reapertura desde Modo Silencio activo.

**Fix pendiente:** eliminar la línea `'memberStatus.${user.uid}.statusType': 'fine'` de `clearOfflineStatus()`. El `statusType` existente en Firestore ya es correcto — no hay que tocarlo.

**Rama propuesta:** `fix/silent-disconnected-on-restart`

---

### DT-2 — Estado "Desconectado" debe ser reemplazado por "No Molestar" 🔴 ALTA

**Descripción:** El estado `💤 Desconectado` se muestra en el Círculo cuando el campo `loggedOut: true`
está presente en Firestore. Este estado no es un `StatusType` real — es un estado derivado hardcodeado
en `in_circle_view.dart:1402` y `:435`.

**Decisión tomada:** eliminar "Desconectado" y usar el `StatusType` existente `do_not_disturb`
(`🔕 No molestar`) cuando el usuario activa Modo Silencio.

**Código a eliminar:**
- Campo `loggedOut` en Firestore
- `StatusService.setOfflineStatus()`
- `StatusService.clearOfflineStatus()` (reemplazar por "restaurar último estado")
- Renderizado `'💤 Desconectado'` en `in_circle_view.dart`

**Rama propuesta:** `fix/silent-disconnected-on-restart` (junto con DT-1)

---

### DT-3 — `locationUnknown` excluye el estado `fine` sin justificación en la spec 🟡 MEDIA

**Descripción:** En `status_service.dart:156`, la condición para activar `locationUnknown` excluye
explícitamente el estado `fine`:

```dart
final locationUnknown =
    (previousWasAutoUpdated || previousManualOverride) && !wasInZone && newStatus.id != 'fine';
```

Esto significa que si el usuario está fuera de todas las Zonas y selecciona "Todo bien", **no** verá
❓ Ubicación desconocida. La spec formal (`maquina-estados.md`) no documenta esta excepción.

**Estado:** comportamiento puede ser intencional (no alarmar con badge si el usuario vuelve al estado neutro). Confirmar con el desarrollador si esta excepción debe quedar o eliminarse.

---

### DT-4 — `✋ Manual` en el selector: Zonas deshabilitadas visualmente con opacidad 🟢 BAJA

**Descripción:** en modo con Zonas configuradas, los botones de Zona en el selector aparecen con
opacidad reducida (atenuados) y al tocarse muestran el modal de bloqueo. El comportamiento es correcto
pero la opacidad visual puede no ser suficientemente evidente en todos los temas.

**Estado:** verificado manualmente (Prueba B1, T3.30.3). No es bloqueante para MVP.

---

### DT-5 — Spec informal vs. spec formal: discrepancia de badges 🟢 BAJA (RESUELTA en código)

**Descripción:** el borrador original de este documento (`estados-circulos.md` v0) mostraba tanto
✋ Manual como ❓ Ubicación desconocida en el escenario "salida de Zona + cambio manual". La
especificación formal (`maquina-estados.md`, Corrección 2026-03-30) y el código implementado son
consistentes entre sí: solo ❓ Ubicación desconocida aparece en ese caso.

**Estado:** resuelto en implementación. Documentado aquí para referencia futura.

---

## 7. Jerarquía de estados por configuración de Zonas

### 7.1 Sin Zonas configuradas — selección manual libre

El usuario puede seleccionar cualquier estado del grid sin restricción:

| Fila | Estados | IDs |
|------|---------|-----|
| **1 — Disponibilidad** | 🙂 Bien · 🔴 Ocupado · 🟡 Ausente · 🔕 No molestar | `fine`, `busy`, `away`, `do_not_disturb` |
| **2 — Ubicación** | 🏠 Casa · 🏫 Colegio · 🎓 Universidad · 🏢 Trabajo | `home`, `school`, `university`, `work` |
| **3 — Actividad** | 🏥 Consulta · 📅 Reunión · 📚 Estudiando · 🍽️ Comiendo | `medical`, `meeting`, `studying`, `eating` |
| **4 — Transporte** | 💪 Ejercicio · 🚗 En camino · 🚶 Caminando · 🚌 Transporte | `exercising`, `driving`, `walking`, `public_transport` |
| **Custom** | Emojis del círculo (sin límite) | dinámico |
| **SOS** | 🆘 SOS — botón separado, press-hold 1s | `sos` |

### 7.2 Con Zonas predefinidas configuradas — estados de ubicación bloqueados

Los estados cuyo `id` coincide con el tipo de zona configurada aparecen **dimmed (35% opacity)** y son **no seleccionables manualmente**.

| Zona configurada | Estado bloqueado | Comportamiento automático |
|-----------------|-----------------|--------------------------|
| `home` → 🏠 | `home` bloqueado | Entrada: `fine` 🙂 · Salida: `fine` 🙂 |
| `school` → 🏫 | `school` bloqueado | Entrada: `studying` 📚 · Salida: `fine` 🙂 |
| `university` → 🎓 | `university` bloqueado | Entrada: `studying` 📚 · Salida: `fine` 🙂 |
| `work` → 💼 | `work` bloqueado | Entrada: `busy` 🔴 · Salida: `fine` 🙂 |

> Zonas `custom` (📍) no bloquean ningún estado. En entrada asignan `fine` con emoji `📍`.

El tap sobre un estado bloqueado muestra el modal **"Acción no permitida"** explicando que ese estado lo maneja el geofencing automáticamente.

> **Bug conocido:** `ZoneType.work` usa emoji 💼 pero `StatusType` con `id: 'work'` muestra 🏢. Hay mismatch entre `zone.type.emoji` y el `StatusType` correspondiente.

---

## 8. Reglas para cambio manual de estado

### 8.1 Bloqueo por zona configurada

Si el `status.id` es `home`, `school`, `work` o `university` **Y** ese tipo de zona está configurada en el círculo → **bloqueado**. Muestra modal "Acción no permitida". No escribe nada en Firestore.

Si la zona de ese tipo **no está configurada** → selección libre, sin bloqueo.

### 8.2 Flags calculados al escribir en Firestore

| Flag | Cuándo es `true` |
|------|-----------------|
| `autoUpdated` | Siempre `false` en cambio manual |
| `manualOverride` | `true` si el usuario **sigue dentro de una zona** (`zoneId != null`) Y el estado anterior era `autoUpdated` o `manualOverride` |
| `locationUnknown` | `true` si el estado anterior era auto/manual Y el usuario **ya salió de la zona** (`zoneId == null`) Y el nuevo estado **no es `fine`** |

### 8.3 Preservación de campos de zona

El código conserva los valores anteriores de zona si el usuario sigue dentro:

```
customEmoji  = wasInZone ? previousZoneEmoji : null
zoneName     = wasInZone ? previousZoneName  : null
zoneId       = wasInZone ? previousZoneId    : null
```

Si ya salió de la zona → todos esos campos quedan `null`.

### 8.4 Caso especial: SOS

Antes de escribir en Firestore, obtiene coordenadas GPS via `GPSService.getCurrentLocation()`. Las coordenadas se escriben tanto en `memberStatus` como en `statusEvents` (historial).

### 8.5 Side effects post-escritura

- Escribe en batch: `memberStatus.{uid}` + nuevo doc en `statusEvents`
- Si había zona previa → guarda `lastKnownZone` + `lastKnownZoneTime`
- Notificación persistente: **no se actualiza** (comportamiento silencioso, Point 15)
- Feedback al usuario: solo haptic (sin SnackBar, sin toast)
- Modal se cierra automáticamente 300ms después del éxito

### 8.6 Flujo de decisión

```
Usuario toca estado
       ↓
¿Es zona bloqueada configurada?
  SÍ → Modal "no permitido" → fin
  NO ↓
¿Es SOS?
  SÍ → obtener GPS → continuar
  NO ↓
Leer estado actual de Firestore
Calcular manualOverride / locationUnknown
Escribir batch (memberStatus + historial)
Haptic → cerrar modal (300ms)
```
