# Máquina de estados (ZYNC) — Estado mostrado en Círculo

## 1. Objetivo

Definir el comportamiento y las transiciones de estado que se muestran en el **Círculo** para un Usuario, considerando:

- Estados/emoji seleccionados manualmente.
- Estados/emoji provenientes de **Geofencing** (Zonas configuradas).
- Restricciones (no permitir seleccionar Zonas manualmente).
- Indicadores visuales adicionales (`✋ Manual`, `❓ Ubicación desconocida`).
- Reglas de **timestamp**.

---

## 2. Glosario

- **Estado (principal)**: el valor que define el **emoji** + **nombre del estado** mostrado en el Círculo.
  - Ejemplos: `📚 Estudiando`, `🚶 En camino`, `🏫 Universidad`.
- **Zona**: estado especial asociado a una Zona configurada (Casa/Colegio/Universidad/Trabajo/Personalizada). La Zona se determina por Geofencing.
- **Estado no-zona**: cualquier estado/emoji que no corresponde a una Zona.
- **Indicadores (badges/flags)**: líneas informativas adicionales debajo del estado.
  - `✋ Manual`
  - `❓ Ubicación desconocida`

---

## 3. Vistas del Círculo (layout lógico)

Para cualquier estado, el Círculo puede mostrar:

1. **Línea 1**: `emoji + nombre del usuario`
2. **Línea 2**: `texto del estado principal`
3. **Línea 3**: `timestamp`
4. **Línea 4 (opcional)**: `✋ Manual`
5. **Línea 5 (opcional)**: `❓ Ubicación desconocida`

Ejemplo:

- `📚 Mauricio`
- `Estudiando`
- `Hace 15 min`
- `✋ Manual`
- `❓ Ubicación desconocida`

---

## 4. Configuración base

### 4.1 Sin Zonas configuradas (comportamiento default)

- No existe lógica de Geofencing para setear estados de Zona.
- El Usuario puede seleccionar cualquier estado/emoji (incluyendo `En camino`).
- El Círculo muestra siempre:
  - estado principal
  - timestamp
- No aplica restricción de “zonas manuales” (porque no existen zonas configuradas como tales).

### 4.2 Con Zonas configuradas y Geofencing activo

- Geofencing puede actualizar el estado principal automáticamente ante eventos de **entrada/salida**.
- El Usuario puede seleccionar manualmente estados **no-zona** (incluyendo `En camino`).
- El Usuario **NO** puede seleccionar estados de **Zona** manualmente.

---

## 5. Eventos

- **E1: UserSelectNonZone(state)**
  - El Usuario selecciona un estado/emoji que NO corresponde a una Zona.

- **E2: UserSelectZone(zoneState)**
  - El Usuario intenta seleccionar un estado que corresponde a una Zona (Casa/Colegio/Universidad/Trabajo/Personalizada).

- **E3: GeoEnterZone(zoneState)**
  - Geofencing detecta ingreso a una Zona configurada.

- **E4: GeoExitZone**
  - Geofencing detecta salida de una Zona configurada.

- **E5: LocationStatusChanged**
  - Cambia la condición de ubicación (por ejemplo: GPS/permiso falla o se recupera, o se determina que está fuera de zonas).

---

## 6. Estados principales

### 6.1 Estados principales “Zona”

- `Casa`
- `Colegio`
- `Universidad`
- `Trabajo`
- `Personalizada` (si existe)

> Nota: la app puede representarlos con emoji específico por Zona.

### 6.2 Estado principal “En camino”

- Funciona como estado default para **salidas** de cualquier Zona.
- También puede ser usado manualmente como estado individual.

### 6.3 Otros estados principales (no-zona)

- Cualquier estado/emoji del catálogo que no sea Zona.

---

## 7. Indicadores (badges/flags)

### 7.1 `✋ Manual`

Se muestra cuando el **último cambio de estado principal** fue realizado manualmente por el Usuario, seleccionando un estado **no-zona**.

- Se activa con `E1: UserSelectNonZone(state)`.
- Se desactiva cuando el estado principal cambia por Geofencing (`E3` o `E4`).

### 7.2 `❓ Ubicación desconocida`

Caso borde. Se muestra cuando existe al menos una de estas condiciones:

- El Usuario está **fuera de Zonas configuradas**.
- Hay **fallo de GPS/permiso** (ubicación no disponible / imprecisa).

> Recomendación de implementación: aunque el texto sea uno, modelar internamente dos flags (`outOfZones` y `locationUnavailable`) para no perder precisión.

---

## 8. Reglas de transición (máquina de estados)

### 8.1 Reglas con Geofencing (si hay Zonas configuradas y Geofencing activo)

#### Regla G1 — Entrada a Zona
- Evento: `E3: GeoEnterZone(zoneState)`
- Acción:
  - Estado principal := `zoneState`
  - `✋ Manual` := OFF
  - Actualiza timestamp

#### Regla G2 — Salida de Zona
- Evento: `E4: GeoExitZone`
- Acción:
  - Estado principal := `En camino`
  - `✋ Manual` := OFF
  - Actualiza timestamp

### 8.2 Reglas Manuales

#### Regla M1 — Usuario selecciona estado no-zona
- Evento: `E1: UserSelectNonZone(state)`
- Acción:
  - Estado principal := `state`
  - `✋ Manual` := ON
  - Actualiza timestamp

#### Regla M2 — Usuario intenta seleccionar una Zona (NO permitido)
- Evento: `E2: UserSelectZone(zoneState)`
- Acción:
  - Estado principal := sin cambios
  - Mostrar aviso notorio (ver sección 9)
  - No actualiza timestamp (no hubo cambio de estado)

> Esta regla aplica para cualquier intento de cambiar una Zona por otra Zona, o seleccionar una Zona desde el selector en general.

### 8.3 Reglas de `❓ Ubicación desconocida`

#### Regla U1 — Mostrar/ocultar `Ubicación desconocida`
- Evento: `E5: LocationStatusChanged`
- Acción:
  - Actualizar la visibilidad del indicador `❓ Ubicación desconocida` según condiciones definidas en 7.2.

**Timestamp**:
- Si el indicador aparece o desaparece, **se actualiza timestamp** (se considera cambio visible relevante).

---

## 9. UX del bloqueo (Zonas no seleccionables manualmente)

Cuando el usuario intente seleccionar una Zona manualmente (`E2`):

- Debe mostrarse un **modal evidente**.
- Diseño sugerido:
  - Fondo (overlay) **gris claro**.
  - Texto **negro** para alto contraste.
  - Título: `Acción no permitida`
  - Mensaje: `No puedes seleccionar zonas manualmente. El estado de zonas se actualiza automáticamente por geofencing.`
  - Botón: `Entendido`

Adicional:
- En el selector, las opciones de Zona pueden estar **deshabilitadas** y, al tocarlas, igualmente abrir el modal.

---

## 10. Timestamp

El timestamp es la “huella” de cualquier actualización visible del estado mostrado en el Círculo.

Se actualiza cuando:

- Cambia el **estado principal** (manual o geofence).
- Cambia la visibilidad de un indicador (`✋ Manual`, `❓ Ubicación desconocida`).

### 10.1 Formato del timestamp

- `Justo Ahora` -> momento < 59 s (o < 1 min)
- `Hace X min` -> momento < 59 min
- `Hace Y h` -> momento < 24 h
- `Hace Z d` -> si la actualización es >= 1 día

---

## 11. Consideración mínima para Zonas solapadas

Para mantener el comportamiento determinista, si múltiples Zonas coinciden al mismo tiempo:

- Gana la Zona de **menor radio** (más específica).
- En caso de empate:
  - Gana la Zona creada primero (o la de mayor prioridad si existe ese atributo).

---

## 12. Ejemplos esperados

### 12.1 Default (sin zonas)
- Usuario selecciona `📚 Estudiando`:
  - Estado: `Estudiando`
  - Timestamp actualizado

### 12.2 Con zonas: entra a Universidad
- Evento `GeoEnterZone(Universidad)`:
  - Estado: `Universidad`
  - `✋ Manual` OFF
  - Timestamp actualizado

### 12.3 Con zonas: usuario cambia a no-zona dentro de Universidad
- Evento `UserSelectNonZone(Estudiando)`:
  - Estado: `Estudiando`
  - `✋ Manual` ON
  - Timestamp actualizado

### 12.4 Con zonas: sale de Universidad
- Evento `GeoExitZone`:
  - Estado: `En camino`
  - `✋ Manual` OFF
  - Timestamp actualizado

### 12.5 Con zonas: intenta seleccionar “Casa” manualmente
- Evento `UserSelectZone(Casa)`:
  - Estado no cambia
  - Modal evidente
  - Timestamp no cambia

---

## 13. Checklist de pruebas (manual) — Validación de Máquina de Estados (Círculo)

> Objetivo: validar comportamiento de estados/emoji en el Círculo según esta máquina de estados, incluyendo Geofencing, bloqueo de Zonas manuales, `✋ Manual`, `❓ Ubicación desconocida` y formato de timestamp.

### 0) Preparación / Preconditions

- **P0.1**: Tener 2 escenarios disponibles:
  - **Escenario A (SIN Zonas)**: círculo sin documentos en `circles/{circleId}/zones/*`.
  - **Escenario B (CON Zonas)**: círculo con al menos 1 documento en `circles/{circleId}/zones/*`.
- **P0.2**: Usuario autenticado y dentro del círculo.
- **P0.3 (para Geofencing)**:
  - Permisos de ubicación concedidos.
  - Ubicación del dispositivo activa.
  - (Opcional) Ubicación simulada si se usa emulador.

---

## 1) Escenario A — SIN Zonas configuradas (comportamiento default)

### Prueba A1 — Selección manual de cualquier estado (incluye `home/school/work/university` si existen en catálogo)

- **Pasos**
  - Abrir el Círculo.
  - Tocar tu usuario para abrir el selector de estado.
  - Seleccionar varios estados (ej. `📚 studying`, `🚗 driving`, y también `🏠 home`, `🏫 school`, `💼 work`, `🎓 university` si aparecen).
- **Esperado**
  - **NO** aparece modal de bloqueo.
  - El estado cambia y se refleja en el Círculo.
  - **NO** se muestra `✋ Manual` (no se está sobre-escribiendo geofencing; no existen Zonas configuradas).
  - El timestamp se actualiza y usa el formato definido (ver sección 5).

### Prueba A2 — “En camino” manual

- **Pasos**
  - En el selector, elegir `🚗 En camino` (`driving`).
- **Esperado**
  - Estado principal: `🚗` + `En camino`.
  - **NO** `✋ Manual`.
  - Timestamp actualizado.

---

## 2) Escenario B — CON Zonas configuradas + Geofencing activo

### Prueba B1 — Bloqueo de selección manual de Zonas (regla 3.3)

- **Pasos**
  - Abrir el selector de estado.
  - Intentar seleccionar `🏠 home`, `🏫 school`, `💼 work`, `🎓 university`.
- **Esperado**
  - El estado principal **NO** cambia.
  - Aparece un **modal notorio**:
    - Fondo/overlay gris claro
    - Texto negro
    - Título `Acción no permitida`
    - Mensaje de “No puedes seleccionar zonas manualmente…”
    - Botón `Entendido`
  - Timestamp **NO** cambia (no hubo cambio de estado).

### Prueba B2 — Selección manual de un estado NO-Zona

- **Pasos**
  - Abrir el selector.
  - Elegir un estado NO-Zona (ej. `📚 Estudiando`, `🔴 Ocupado`, etc.).
- **Esperado**
  - El estado cambia y se refleja en el Círculo.
  - **NO** se muestra `✋ Manual` (porque `✋ Manual` es exclusivo para sobre-escritura de estados automáticos de Zona).
  - Timestamp actualizado.

### Prueba B3 — “En camino” manual (permitido)

- **Pasos**
  - Abrir el selector.
  - Elegir `🚗 En camino` manualmente.
- **Esperado**
  - Estado: `🚗 En camino`.
  - **NO** `✋ Manual`.
  - Timestamp actualizado.

---

## 3) Geofencing — Entrada a Zona (G1)

### Prueba G1 — Auto update al entrar a Zona configurada

- **Pasos**
  - En Escenario B, ubicarse fuera de una zona configurada.
  - Entrar físicamente (o simular) dentro del radio de una zona.
  - Esperar a que el evento se refleje.
- **Esperado**
  - El estado cambia automáticamente a la Zona:
    - Emoji: el emoji de zona (ej. `🏠/🏫/🎓/💼` o `📍` si es custom)
    - Texto: nombre de zona (`zoneName`)
  - **NO** `✋ Manual`.
  - Timestamp actualizado.

---

## 4) Geofencing — Salida de Zona (G2)

### Prueba G2 — Auto “En camino” al salir de cualquier Zona

- **Pasos**
  - Estar dentro de una zona configurada (estado debe reflejar esa zona).
  - Salir físicamente (o simular) fuera del radio.
- **Esperado**
  - Estado cambia automáticamente a `🚗 En camino`.
  - **NO** `✋ Manual`.
  - Timestamp actualizado.

---

## 5) Casos excepcionales (Manual override de un estado automático)

> Regla clave: `✋ Manual` **solo aparece** cuando el usuario **sobre-escribe** un estado **automático** (geofencing).

### Prueba E1 (caso 3.1) — Manual override dentro de la zona (sin salir)

- **Pasos**
  - En Escenario B, entrar a una zona (debe ponerse automático por geofencing).
  - Sin salir de la zona, seleccionar manualmente un estado **NO-Zona** (ej. `📚 Estudiando`).
- **Esperado**
  - Estado cambia al estado manual seleccionado.
  - Se muestra `✋ Manual`.
  - **NO** debe mostrarse `❓ Ubicación desconocida` (porque el usuario no ha salido de la zona).
  - Timestamp actualizado.

### Prueba E2 (caso 3.2) — Manual override + salida posterior

- **Pasos**
  - Repetir Prueba E1 hasta quedar en estado manual con `✋ Manual`.
  - Luego salir de la zona configurada (evento de salida).
- **Esperado**
  - El sistema fuerza estado automático `🚗 En camino` por salida de zona.
  - `✋ Manual` **se apaga** (porque el estado vuelve a ser automático).
  - Timestamp actualizado.

---

## 6) Timestamp (formato)

### Prueba T1 — Formato del timestamp

- **Pasos**
  - Provocar un cambio de estado (manual o automático) y mirar el timestamp.
  - Repetir después de esperar diferentes lapsos.
- **Esperado**
  - `< 60 s`: `Justo Ahora`
  - `< 60 min`: `Hace X min`
  - `< 24 h`: `Hace Y h`
  - `>= 1 día`: `Hace Z d`

---

## 7) No-regresión (sanity checks)

### Prueba NR1 — Estado SOS sigue funcionando

- **Pasos**
  - Seleccionar `🆘 SOS`.
- **Esperado**
  - No se rompe el flujo existente.
  - (Si aplica en tu app) conserva el comportamiento de GPS/historial según lo ya implementado.

### Prueba NR2 — Render de miembros (otros usuarios)

- **Pasos**
  - Ver el Círculo con varios miembros y cambios de estado.
- **Esperado**
  - No hay crashes.
  - Emojis/labels/timestamps se siguen mostrando para todos.
