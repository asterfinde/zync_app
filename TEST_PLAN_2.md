# TEST_PLAN_2.md — Plan de Pruebas ZYNC (v2)

> Fuente de la verdad activa desde 2026-04-14.
> Reorganizado 2026-04-16: dos grandes grupos — Modo Normal y Modo Silencioso.
> `TEST_PLAN.md` conservado solo como registro histórico.

---

## Leyenda

| Símbolo | Significado |
|:-------:|-------------|
| 👁 | Solo manual |
| ✅ | Validado en dispositivo |
| 🕔 | Pendiente de prueba |
| ❌ | Falla — bloqueante |
| ⚠️ | Comportamiento inesperado / observación |

**Device ID:** `R58W315389R` (Samsung SM-A145M — Android 15)

---

## Protocolo de pruebas en dispositivo

**Antes de cada sesión:**
1. PowerShell como Administrador: `adb kill-server; adb start-server`
2. `flutter run -d R58W315389R`
3. Si aparece `DDS shut down too early` → abrir la app manualmente en el dispositivo
4. Verificar que el timestamp `v HH:MM:SS` en la pantalla de login se actualiza — confirma build correcto

**Durante:**
- Un flujo completo a la vez
- Si falla → fix → `flutter run` → re-probar ese caso antes de continuar
- No avanzar si hay un ❌ sin resolver en el flujo actual

**Cuando los cambios no se reflejan:**

| Situación | Acción |
|-----------|--------|
| Cambio solo de UI | `r` en terminal |
| Cambio en lógica de widget | `R` en terminal |
| Cambio en servicios o providers | `Ctrl+C` → `flutter run -d R58W315389R` |
| Nada funciona | `Ctrl+C` → `flutter clean` → `flutter run -d R58W315389R` |

---

# SECCIÓN 1 — MODO NORMAL

> App en primer plano. Usuario toca pantalla Flutter.
> Sin BN. Sin proceso en background.
>
> Los emojis seleccionados del modal correspondiente son los que se graban durectamente en Firebase. **No hay emojis temporales!**
---

## MN1 — Auth y Cuenta

| ID | Caso | Pasos | Resultado esperado | Estado |
|:--:|:-----|:------|:-------------------|:------:|
| MN1.01 | Registro válido | Llenar nickname + email + pass → Crear cuenta | Usuario creado en Firebase Auth y Firestore | ✅ |
| MN1.02 | Registro bloqueado — passes no coinciden | Llenar form, passes distintos | Botón "Crear Cuenta" deshabilitado | ✅ |
| MN1.03 | Registro bloqueado — email duplicado | Registrar email ya existente | "Este correo ya tiene cuenta. Inicia sesión." | ✅ |
| MN1.04 | Login válido | Credenciales correctas | Pantalla Círculo visible | ✅ |
| MN1.05 | Login bloqueado — email no existe | Email no registrado | "Correo o contraseña incorrectos…" | ✅ |
| MN1.06 | Login bloqueado — pass incorrecto | Pass equivocado | "La contraseña es incorrecta…" | ✅ |
| MN1.07 | Recuperación de pass | Email válido → solicitar reset | Email de recuperación enviado | ✅ |
| MN1.08 | Logout | Ajustes → Cerrar sesión | Redirige a Login | ✅ |
| MN1.09 | Eliminar cuenta — sin círculo | Ajustes → Eliminar cuenta | Cuenta eliminada. Login visible | ✅ |
| MN1.10 | Eliminar cuenta — miembro común | Ajustes → Eliminar cuenta | Solo ese usuario removido. Círculo intacto | ✅ |
| MN1.11 | Eliminar cuenta — sesión no reciente | Intentar eliminar → app pide pass | Pass correcto: elimina. Pass incorrecto: SnackBar rojo, cuenta intacta | ✅ |
| MN1.12 | Eliminar cuenta — creador del círculo | Ajustes → Eliminar cuenta | Círculo eliminado. Miembros ven "Sin círculo" | ✅ |

---

## MN2 — Círculos

| ID | Caso | Pasos | Resultado esperado | Estado |
|:--:|:-----|:------|:-------------------|:------:|
| MN2.01 | Crear círculo | Tap "Crear Círculo" → nombre → confirmar | Círculo en Firestore, código de invitación generado | ✅ |
| MN2.02 | Código de invitación visible | Ver pantalla del círculo | Código único visible y copiable | ✅ |
| MN2.03 | Estado inicial al unirse | Unirse a círculo → ver pantalla | Muestra 🙂 "Todo bien" | ✅ |
| MN2.04 | Cambiar estado | Abrir modal → seleccionar emoji | Estado actualizado en Firestore. Visible para miembros | ✅ |
| MN2.05 | Sin opción "Salir del Círculo" | Revisar Settings y todas las pantallas | No existe opción de salir sin eliminar cuenta | ✅ |
| MN2.06 | Solicitud pendiente | B ingresa código de A | B ve pantalla de espera | ✅ |
| MN2.07 | Creador aprueba solicitud | A aprueba solicitud de B | B pasa automáticamente a InCircleView | ✅ |
| MN2.08 | Solicitud expira 48h | Esperar 48h sin respuesta | Solicitud desaparece. B puede reintentar | ✅ |
| MN2.09 | Reenviar código tras expiración | B envía código nuevamente | Nueva solicitud creada | ✅ |

---

## MN3 — Estados y Emojis

| ID | Caso | Pasos | Resultado esperado | Estado |
|:--:|:-----|:------|:-------------------|:------:|
| MN3.01 | Estado default al unirse | Unirse a círculo | Emoji 🙂 "Todo bien" asignado | ✅ |
| MN3.02 | Cambio visible a miembros | Cambiar emoji → verificar en otro dispositivo | Actualización visible sin demora | ✅ |
| MN3.03 | Formato sin zonas | Ver pantalla Círculo, sin zonas configuradas | emoji · nickname · estado · timestamp relativo | ✅ |
| MN3.04 | Zona activa — entrar | Entrar a zona geográfica configurada | Estado actualizado con emoji de zona | ✅ |
| MN3.05 | Zona activa — salir | Salir de zona geográfica | Estado cambia a 🙂 "Bien" | 🕔 |
| MN3.06 | Override manual dentro de zona | Dentro de zona → seleccionar emoji distinto | Badge ✋ "Manual" junto al estado | ✅ |
| MN3.07 | Cambio manual fuera de zona | Fuera de zona → seleccionar emoji | Badge ❓ "Ubicación desconocida" | ✅ |
| MN3.08 | Botones zona inhabilitados en modal | Crear Zona → Modal Círculo con zona activa → tap botón zona | Botones 🏠🏫🏢🏥 atenuados. Tap: "Acción no permitida". Estado sin cambio | ✅ |
| MN3.09 | Emoji preservado tras logout + re-login | Setear emoji → logout → login | Emoji = valor previo al logout | ✅ |

---

## MN4 — Modal del Círculo (sin Modo Silencio)

| ID | Caso | Pasos | Resultado esperado | Estado |
|:--:|:-----|:------|:-------------------|:------:|
| MN4.01 | Tap "Reunión" | Abrir modal → tap Reunión | Estado "Reunión" en Pantalla Círculo | ✅ |
| MN4.02 | Tap "Universidad" | Abrir modal → tap Universidad | Estado "Universidad" en Pantalla Círculo | ✅  |
| MN4.03 | Tap "Bien" | Abrir modal → tap Bien | Estado 🙂 "Bien" en Pantalla Círculo | ✅ |
| MN4.04 | Los 16 emojis | Probar cada emoji del modal | Emoji correspondiente en Pantalla Círculo | ✅ |
| MN4.05 | SOS se abre en < 1s | Abrir modal → mantener SOS < 1s | El funcionamiento del botón "SOS" debe de ser igual al del modal de la BN, abriéndose en < 1s | ✅  |
| MN4.06 | Emoji desde modal → sin efectos en BN | Seleccionar emoji en modal Círculo | Estado actualizado. Sin ícóno "i" en BN | ✅ |
| MN4.07 | SOS desde modal → sin efectos en BN | Hold SOS 1s en modal Círculo | Flujo SOS completo. Sin efectos en BN | ✅ |
| MN4.08 | Ciclos abrir/cerrar → sin ícóno "i" involuntario | Abrir app → cerrar → abrir (3 ciclos, sin Modo Silencio) | Sin ícóno "i" en BN. Sin regresiones |✅ |
| MN4.09 | Aparecen los 17 emojis/estados en modal del Círculo | Abrir app → pantalla Círculo → abrir modal  | Se muestran correctamente los 17 emojis/estados |✅ |


## MN5 — Apertura y Sesión

| ID | Caso | Pasos | Resultado esperado | Estado |
|:--:|:-----|:------|:-------------------|:------:|
| MN5.01 | Primera apertura sin cuenta | Instalar app → abrir | Pantalla registro visible. Sin crash | ✅ |
| MN5.02 | Registro → NoCircleView | Registro exitoso | Tarjetas "Crear" y "Unirse" visibles | ✅ |
| MN5.03 | Apertura sin sesión activa | Abrir app sin estar logueado | Login visible. Pantalla Círculo no aparece | ✅ |
| MN5.04 | Login → Pantalla Círculo | Login exitoso | Pantalla Círculo con último emoji del usuario | ✅ |
| MN5.05 | Cerrar sin logout → reabrir → sesión activa | Forzar cierre → reabrir | Pantalla Círculo directa. Login no aparece |✅ |
| MN5.06 | Emoji preservado tras cierre sin logout | Setear emoji ≠ "Bien" → cerrar sin logout → reabrir | Emoji = valor seteado. No muestra 🙂 "Todo bien" |✅ |

---

## MN6 — UI/UX

| ID | Caso | Pasos | Resultado esperado | Estado |
|:--:|:-----|:------|:-------------------|:------:|
| MN6.01 | Rotar con modal abierto | Abrir modal → rotar pantalla | Sin overflow en landscape | ✅ |
| MN6.02 | Foco automático en "Crear Círculo" | Tap "Crear Círculo" | Campo de nombre con foco de entrada | ✅ |
| MN6.03 | Foco al alternar login ↔ registro | Cambiar entre modos | Foco en primer campo al cambiar | ✅ |
| MN6.04 | Tarjetas NoCircleView sin demora | Llegar a NoCircleView | "Crear" y "Unirse" aparecen simultáneamente | ✅ |
| MN6.05 | Look & feel: modal BN ≈ modal Círculo | El modal de aviso para NO poder seleccioanr una zona preconfigurada debe de ser igual | Mismo fondo negro, borde menta, botón "Entendido" en menta |✅  |
| MN6.06 | Foco inmediato para el nombre del Círculo | Login/Registro → Crear Círculo → Ingresar nombre del Círculo | El foco tarda uno segundos en posicionarse sobre el textbox que recibirá el nombre del Círculo, cuando esto debiera ser inmediato | ✅ |
| MN6.07 | Eliminar SnackBar de éxito luego de la creación del Círculo | Login/Registro → Crear Círculo → Ingresar nombre del Círculo | No es necesario mostrar el SnackBar correspondiente puesto que la pantalla de arribo es la del Círculo creado, incluyendo su nombre | ✅ |
---

## MN7 — Permisos de Notificación

| ID | Caso | Pasos | Resultado esperado | Estado |
|:--:|:-----|:------|:-------------------|:------:|
| MN7.01 | Permisos denegados → SnackBar naranja | Denegar permisos → tap "Modo Silencio" | SnackBar naranja con botón "Habilitar" → Ajustes del sistema |🕔 |
| MN7.02 | Re-habilitar → activar Modo Silencio | Tap "Habilitar" → Ajustes → activar → volver → tap "Modo Silencio" | Flujo normal de activación |🕔 |
| MN7.03 | Desactivar notifs con Modo Silencio activo | Ajustes sistema → desactivar notifs ZYNC | Ícono desaparece. SnackBar informativo al volver. Modo Silencio inactivo |🕔 |

---


# SECCIÓN 2 — MODO SILENCIOSO

> App cerrada o en background. Proceso vivo. Ícono "i" en BN.
> Usuario interactúa vía notificación. Sin pantallas Flutter visibles (salvo MS2).

---

## MS1 — Activación: app cierra, ícóno aparece

> Tap "Modo Silencio" → `finishAndRemoveTask()` → proceso sigue vivo → ícóno "i" aparece en BN.

| ID | Caso | Pasos | Resultado esperado | Estado |
|:--:|:-----|:------|:-------------------|:------:|
| MS1.01 | App desaparece de recientes | Tap "Modo Silencio" | App no en lista de recientes | ✅ |
| MS1.02 | Ícono "i" aparece en BN | Tap "Modo Silencio" → esperar | Ícono "i" en BN en ≤3s | ✅ |
| MS1.03 | Proceso sigue vivo | Después de MS1.01: `adb shell ps \| grep zync` | Proceso `com.datainfers.zync` listado | ✅ |
| MS1.04 | KeepAliveService activo | Después de MS1.01: `adb shell dumpsys activity services \| grep zync` | Servicio activo | ✅ |
| MS1.05 | Ícono no parpadea al cierre | Observar BN durante tap "Modo Silencio" | Ícono no desaparece momentáneamente ni se reinicia | ✅ |
| MS1.06 | Segundo tap idempotente | Activar → reabrir app → tap "Modo Silencio" de nuevo | App cierra. Ícono "i" permanece sin duplicarse | ✅ |
| MS1.07 | Notificación persiste 30s | Después de MS1.01 → esperar 30s | Ícono "i" no parpadea ni desaparece | ✅ |
| MS1.08 | Primer tap funciona en cold start | Forzar cierre → reabrir → tap "Modo Silencio" inmediato sin esperar | App cierra. Ícono "i" aparece. Sin falso negativo | ⚠️ funciona pero demora es mayor o igual a 8s, optimizar|
| MS1.09 | Permisos de batería en primera activación | Primera vez → tap "Modo Silencio" → dialog batería → aceptar | App cierra correctamente. Ícono "i" aparece | ⚠️ funciona pero el aviso de batería permanece a pesar de haberle dado "Aceptar" Probable comportamiento del SO Android en Samsung. Si no se muestra este aviso, afecta en algo?|

---

## MS2 — Proceso vivo: minimizar y maximizar

> Modo Silencio activo. App en primer plano (maximizada).
> Regla fundamental: ícóno "i" **permanece siempre** hasta logout.

| ID | Caso | Pasos | Resultado esperado | Estado |
|:--:|:-----|:------|:-------------------|:------:|
| MS2.01 | Activar → minimizar | Activar Modo Silencio → minimizar | Ícono "i" en BN | ✅ |
| MS2.02 | Tap BN → emoji → volver | Activar → minimizar → tap "i" → seleccionar emoji → volver | Ícono "i" permanece | ✅ |
| MS2.03 | Minimizar/maximizar rápido (<3s) | Min → max en <3s | Ícono "i" permanece | ✅ |
| MS2.04 | Minimizar/maximizar lento (>3s) | Min → max en >3s | Ícono "i" permanece | ✅ |
| MS2.05 | Maximizar → modal Flutter → emoji | App visible + Modo Silencio activo → abrir modal → seleccionar emoji | Ícono "i" permanece | ✅ |
| MS2.06 | Modal Flutter → emoji → min/max | Seleccionar emoji en modal → minimizar → maximizar | Ícono "i" permanece | ✅ |
| MS2.07 | BN → SOS hold 1s → maximizar | Tap "i" → hold SOS 1s → maximizar app | Ícono "i" permanece | ✅ |
| MS2.08 | Ciclo activar → min → max → activar de nuevo | Activar → minimizar → maximizar → activar (x2) | Ícono "i" sin duplicar. Comportamiento consistente | ✅ |
| MS2.09 | No mostrar aviso: "Toca para cambiar tu estado"  | Activar Modo Silencio → minimizar | El Ícono "i" ya aparece en BN, lo cual hace redundante mostrar el aviso mencionado, salvo cuando el usuario desliza la Barra de Notificaciones para ver todos los avisos. El aviso genera ruido en la UI | ✅ |
| MS2.10 | No guardar estado "No Molestar" justo antes del cierre de la app en MS | Activar Modo Silencio → minimizar | Este comportamiento esta errado- La fuente de la verdad aquí es: prevalece el estado/emoji que seleccionó el usuario o lo que el geofencing determino si que hubiese alguna Zona preconfigurada. NO HAY ESTADOS TEMPORALES!| ✅ |
| MS2.11 | Se necesita que aparezca el mensaje "Toca para cambiar tu estado"  | Activar Modo Silencio → minimizar → mostrar mensaje al deslizar BN  | El Ícono "i" ya aparece en BN, lo cual hace redundante mostrar el aviso mencionado, salvo cuando el usuario desliza la Barra de Notificaciones para ver todos los avisos. El aviso genera ruido en la UI | ✅ |
| MS2.12 | Se necesita que aparezca el mensaje "Toca para cambiar tu estado" en MS  | Activar Modo Silencio → minimizar → mostrar mensaje SOLAMENTE al deslizar BN  | Solo se necesita que aparezca el mensaje al deslizar BN, no que se muestre el aviso tal y como se especificó en MS02.9 | 🕔 |
---

## MS3 — Interacción desde BN con app cerrada

> App no visible. No en recientes. Solo proceso + notificación activos.

| ID | Caso | Pasos | Resultado esperado | Estado |
|:--:|:-----|:------|:-------------------|:------:|
| MS3.01 | Tap "i" → abre modal nativo | App cerrada → tap ícóno "i" | Modal nativo abre. `MainActivity` no se relanza | ✅ |
| MS3.02 | Cerrar modal sin seleccionar → ícóno permanece | Desde MS3.01 → cerrar modal | Ícono "i" visible. App sigue cerrada | ✅|
| MS3.03 | Seleccionar emoji → Firestore actualizado | Desde MS3.01 → tap cualquier emoji | Estado en Firestore actualizado | ✅ |
| MS3.04 | Seleccionar emoji → ícóno permanece | Completar MS3.03 | Ícono "i" visible después de seleccionar | ✅ |
| MS3.05 | SOS hold 1s desde modal BN | App cerrada → modal BN → mantener SOS 1s | Estado SOS seteado. Modal cierra. Ícono "i" permanece |✅ |
| MS3.06 | Ciclo completo x2 | Activar → emoji desde BN → reabrir → activar (x2) | Comportamiento consistente en ambos ciclos | ✅ |

---

## MS4 — Persistencia de notificación

> KeepAliveService re-llama `startForeground()` cada 5s. Resistencia a OEM (Samsung, Xiaomi, Huawei).

| ID | Caso | Pasos | Resultado esperado | Estado |
|:--:|:-----|:------|:-------------------|:------:|
| MS4.01 | Swipe sobre ícóno "i" — no descarta | Con Modo Silencio activo → deslizar notificación | Notificación permanece visible | ✅ |
| MS4.02 | "Borrar todo" → ícóno reaparece | Con Modo Silencio activo → BN → "Borrar todo" → esperar ≤10s | Ícono "i" reaparece automáticamente | ✅ |
| MS4.03 | Proceso sobrevive a "Borrar todo" | Después de MS4.02: `adb shell ps \| grep zync` | Proceso `com.datainfers.zync` listado | ✅ |
| MS4.04 | Notificación reaparece sin abrir app | Después de MS4.02 → NO abrir app → solo esperar | Ícono "i" vuelve solo |✅ |
| MS4.05 | Logcat muestra ticks periódicos | Con Modo Silencio activo → observar logcat 15s | `🔄 [KEEP-ALIVE] startForeground re-afirmado` cada ~5s | ✅|

---

## MS5 — Reabrir app: desactivar Modo Silencio

> Tap ícóno ZYNC en launcher con Modo Silencio activo → app abre, servicio termina limpiamente.

| ID | Caso | Pasos | Resultado esperado | Estado |
|:--:|:-----|:------|:-------------------|:------:|
| MS5.01 | Ícono "i" desaparece al abrir | Modo Silencio activo → tap ícóno ZYNC en launcher | Ícono "i" desaparece en ≤4s | ✅  |
| MS5.02 | App aterriza en Pantalla Círculo — no en Login | Mismos pasos de MS5.01 | Pantalla Círculo directa. Login no aparece | ✅ |
| MS5.03 | Emoji del usuario preservado al reabrir | Setear emoji → activar Modo Silencio → abrir app | Emoji = valor seteado antes del cierre. Sin 🔕 "No molestar" residual | ✅ |
| MS5.04 | Emoji desde BN preservado al reabrir | Seleccionar emoji desde BN → abrir app desde launcher | Pantalla Círculo muestra emoji seleccionado en BN | ✅ |
| MS5.05 | Sin Modo Silencio → apertura normal | Cerrar app normalmente → reabrir | Sin ícóno "i". Comportamiento sin efectos secundarios | ✅ |
| MS5.06 | BN no descartable (swipe / "Borrar") | Con Modo Silencio activo → swipe o "Borrar" sobre notificación | Notificación persiste sin efectos secundarios | ✅ |
| MS5.07 | Emoji preservado: setear → activar → reabrir | Setear "Reunión" → activar Modo Silencio → abrir app | Emoji = "Reunión". No muestra 🙂 "Todo bien" | ✅|
| MS5.08 | Estado actualizable tras reabrir | Modo Silencio activo → abrir app → seleccionar nuevo emoji | Estado cambia correctamente desde 🔕 "No molestar" |✅ |

---

## MS6 — Estado visible a miembros del círculo

> **Requiere dos teléfonos** en el mismo círculo. Verifica que cualquier cambio de estado/emoji —sin importar el emoji elegido ni desde dónde se hizo el cambio— se refleja en tiempo real para los demás miembros.

| ID | Caso | Pasos | Resultado esperado | Estado |
|:--:|:-----|:------|:-------------------|:------:|
| MS6.01 | Cambio de estado desde la app → visible en tiempo real para otros miembros | **Teléfono A:** abre la app → selecciona cualquier emoji/estado. **Teléfono B:** observa la pantalla del Círculo sin hacer nada | El Teléfono B muestra el nuevo emoji y nombre del estado del usuario A en menos de 5 segundos, sin necesidad de refrescar | 🕔|
| MS6.02 | Cambio de estado desde el modal BN (app en segundo plano) → visible en tiempo real para otros miembros | **Teléfono A:** cierra la app → desliza la barra de notificaciones → toca el ícono "i" → selecciona cualquier emoji. **Teléfono B:** observa la pantalla del Círculo | El Teléfono B muestra el nuevo emoji del usuario A en menos de 5 segundos | 🕔|
| MS6.03 | Si se elige un estado/emoji estando la app en MS, la actualización no se lleva a cabo y aparece el estado "Casa" con un emoji que es un alfiler con la cabeza de color rojo  | Modo Silencio activo → modal BN → elegir emoji permitido | El emoji no es el elegido en el modal de la BN, sino "Casa" con el emoji de alfiler rojo  | ❌|

---

## MS7 — Zona bloqueada desde el modal de la barra de notificaciones

> **Prerequisito:** tener al menos una Zona configurada en el Círculo (ej: Casa 🏠). Confirmar con quien configuró las zonas cuál está activa.

| ID | Caso | Pasos | Resultado esperado | Estado |
|:--:|:-----|:------|:-------------------|:------:|
| MS7.01 | Tocar emoji de Zona desde el modal → aparece aviso de bloqueo | 1. Abre la app y verifica que carga tu Círculo normalmente (esto es importante). 2. Activa Modo Silencio → cierra la app. 3. Desliza la barra de notificaciones → toca el ícono "i". 4. En el modal que abre, toca el emoji de la Zona configurada (ej: 🏠 Casa) | Aparece un mensaje dentro del modal que dice "Acción no permitida". El estado NO cambia | ✅ |
| MS7.02 | Tocar emoji de Zona sin haber abierto la app → aviso al reabrir | 1. Ve a Ajustes del teléfono → Aplicaciones → ZYNC → Almacenamiento → **Limpiar caché** (solo caché, no datos). 2. Sin abrir la app: desliza la barra de notificaciones → toca el ícono "i". 3. En el modal, toca el emoji de la Zona configurada (ej: 🏠 Casa). 4. Abre la app desde el ícono en la pantalla de inicio | Al abrir la app aparece un aviso que dice "Esa zona se actualiza automáticamente…". El estado NO cambió a la Zona | ✅ |

---

## MS8 — Cerrar sesión con Modo Silencio activo

> Verifica que al hacer logout el ícono "i" de la barra de notificaciones desaparece y no vuelve a aparecer solo.

| ID | Caso | Pasos | Resultado esperado | Estado |
|:--:|:-----|:------|:-------------------|:------:|
| MS8.01 | Cerrar sesión con la app abierta | 1. Activa Modo Silencio (verifica que el ícono "i" aparece en la barra de notificaciones). 2. Abre la app. 3. Ve a Ajustes → Cerrar sesión | El ícono "i" desaparece de la barra de notificaciones. La app muestra la pantalla de Login | ✅ |
| MS8.02 | Cerrar sesión con la app cerrada | 1. Activa Modo Silencio → cierra la app (el ícono "i" debe seguir visible). 2. Vuelve a abrir la app desde el ícono en pantalla de inicio. 3. Ve a Ajustes → Cerrar sesión | El ícono "i" desaparece de la barra de notificaciones | ✅ |
| MS8.03 | La notificación no reaparece después del logout | Completa MS8.01 o MS8.02 → espera 30 segundos sin hacer nada → desliza la barra de notificaciones | El ícono "i" **no** vuelve a aparecer. La barra de notificaciones no muestra ninguna notificación de ZYNC | ✅|
