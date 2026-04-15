# TEST_PLAN_2.md — Plan de Pruebas ZYNC (v2)

> Fuente de la verdad activa desde 2026-04-14.
> Reemplaza `TEST_PLAN.md` como documento de referencia para pruebas en dispositivo.
> `TEST_PLAN.md` se conserva únicamente como registro histórico.

---

## Leyenda

| Símbolo | Significado |
|:-------:|-------------|
| 👁 | Solo manual |
| ✅ | Validado en dispositivo |
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

---

# SECCIÓN 1 — REGRESIÓN

> Tests ya validados en dispositivo físico.
> Si falla cualquiera de estos casos, es una **regresión bloqueante** que debe resolverse antes de continuar.

---

## R1 — Auth y Cuenta

| ID | Caso de prueba | Resultado esperado | Estado |
|:--:|:--------------|:-------------------|:------:|
| R1.01 | Registro exitoso — nickname + email + contraseña coinciden | Usuario creado en Firebase Auth y Firestore | ✅ |
| R1.02 | Registro fallido — contraseñas no coinciden | Botón "Crear Cuenta" deshabilitado | ✅ |
| R1.03 | Registro fallido — email ya registrado | Mensaje "Este correo ya tiene una cuenta registrada. Inicia sesión." | ✅ |
| R1.04 | Login exitoso — credenciales válidas | Acceso a pantalla del Círculo | ✅ |
| R1.05 | Login fallido — correo no encontrado | Mensaje "Correo o contraseña incorrectos…" | ✅ |
| R1.06 | Login fallido — contraseña incorrecta | Mensaje "La contraseña es incorrecta…" | ✅ |
| R1.07 | Recuperación de contraseña — correo válido registrado | Email de recuperación enviado | ✅ |
| R1.08 | Cierre de sesión | Redirige a pantalla de login | ✅ |
| R1.09 | Eliminación de cuenta — usuario sin círculo | Cuenta eliminada. Redirige al login | ✅ |
| R1.10 | Eliminación de cuenta — usuario es miembro común | Solo ese usuario removido. Círculo y demás miembros intactos | ✅ |
| R1.11 | Eliminación de cuenta — sesión no reciente | App solicita contraseña, re-autentica y elimina. Contraseña incorrecta: SnackBar rojo, cuenta intacta | ✅ |
| R1.12 | Eliminación de cuenta — usuario es creador del círculo | Círculo eliminado de Firestore. Todos los ex-miembros ven "Aún no estás en un círculo" | ✅ |

---

## R2 — Círculos

| ID | Caso de prueba | Resultado esperado | Estado |
|:--:|:--------------|:-------------------|:------:|
| R2.01 | Creación de un círculo | Círculo creado en Firestore, código de invitación generado | ✅ |
| R2.02 | Código de invitación generado y visible | Código único visible para compartir | ✅ |
| R2.03 | Estado/emoji inicial al unirse a un círculo | Muestra "🙂 Todo bien" como estado por defecto | ✅ |
| R2.04 | Cambiar de estado/emoji | Estado actualizado en Firestore y visible para los miembros | ✅ |
| R2.05 | La UI no ofrece "Salir del Círculo" sin eliminar cuenta | No existe opción de salir sin eliminar cuenta en Settings ni en ninguna pantalla | ✅ |
| R2.06 | Solicitud de ingreso — solicitante queda en estado pendiente | B ingresa código y ve pantalla de espera | ✅ |
| R2.07 | Creador aprueba solicitud | B pasa automáticamente a InCircleView | ✅ |
| R2.08 | Solicitud expira (48h sin respuesta) | Solicitud desaparece; solicitante ve NoCircleView y puede reintentar | ✅ |
| R2.09 | Solicitante puede reenviar código tras expiración | Nueva solicitud creada sobre la anterior | ✅ |

---

## R3 — Emojis y Estados

| ID | Caso de prueba | Resultado esperado | Estado |
|:--:|:--------------|:-------------------|:------:|
| R3.01 | Estado default al unirse a un círculo | Emoji "🙂 Todo bien" asignado automáticamente | ✅ |
| R3.02 | Cambio de estado desde modal del Círculo | Actualización visible para todos los miembros sin demora | ✅ |
| R3.03 | Sin zonas — formato de estado en pantalla Círculo | Muestra: emoji · nickname · estado · timestamp relativo ("Justo ahora", "Hace X min") | ✅ |
| R3.04 | Con zonas activas — usuario entra a una zona | Estado actualizado automáticamente con emoji de la zona | ✅ |
| R3.05 | Con zonas activas — usuario sale de una zona | Estado cambia a "🚗 En camino" automáticamente | ✅ |
| R3.06 | Dentro de zona, cambio manual a estado no-zona | Muestra badge ✋ Manual junto al estado | ✅ |
| R3.07 | Fuera de zona, cambio manual de estado | No muestra ✋ Manual — muestra ❓ Ubicación desconocida | ✅ |
| R3.08 | Botones de zona inhabilitados en modal del Círculo | Botones 🏠🏫🏢🏥 atenuados. Si se tocan: modal "Acción no permitida". Estado no cambia | ✅ |

---

## R4 — Modo Silencio — Proceso Vivo (PRIMER TRAMO)

> Regla fundamental: mientras el proceso esté vivo, el ícono "i" **permanece siempre** hasta logout.

| ID | Caso de prueba | Resultado esperado | Estado |
|:--:|:--------------|:-------------------|:------:|
| R4.01 | Activar Modo Silencio → minimizar | Ícono "i" aparece en Barra de Notificaciones | ✅ |
| R4.02 | Tap notificación → seleccionar emoji → volver | Ícono "i" permanece visible | ✅ |
| R4.03 | Minimizar/maximizar rápido (<3s) | Ícono "i" permanece visible | ✅ |
| R4.04 | Minimizar/maximizar lento (>3s) | Ícono "i" permanece visible | ✅ |
| R4.05 | Maximizar → modal Flutter → seleccionar emoji | Ícono "i" permanece visible | ✅ |
| R4.06 | Logout con Modo Silencio activo | Ícono "i" desaparece correctamente | ✅ |
| R4.07 | Notificación → SOS (hold 1s) → maximizar | Ícono "i" permanece visible | ✅ |
| R4.08 | Modal Flutter → emoji → minimizar/maximizar | Ícono "i" permanece visible | ✅ |
| R4.09 | Activar → minimizar → maximizar → activar nuevamente | Ícono "i" permanece (sin duplicar) | ✅ |

---

## R5 — Modo Silencio — Activación y App Cerrada (SEGUNDO TRAMO)

| ID | Caso de prueba | Resultado esperado | Estado |
|:--:|:--------------|:-------------------|:------:|
| R5.01 | `finishAndRemoveTask()` destruye Activity | App no aparece en lista de recientes | ✅ |
| R5.02 | Proceso sobrevive tras destruir Activity | `adb shell ps \| grep zync` → proceso sigue listado | ✅ |
| R5.03 | `KeepAliveService` sigue corriendo | `adb shell dumpsys activity services \| grep zync` → servicio activo | ✅ |
| R5.04 | Notificación "i" permanece tras cierre | Ícono "i" visible sin parpadeo después del cierre | ✅ |
| R5.05 | `EmojiDialogActivity` abre desde BN sin `MainActivity` | Modal nativo abre correctamente | ✅ |
| R5.06 | Tap "Modo Silencio" → app desaparece de recientes | App no aparece en la lista de apps recientes | ✅ |
| R5.07 | Tap "Modo Silencio" → ícono "i" aparece en BN | Ícono "i" aparece dentro de ~3s | ✅ |
| R5.08 | Proceso sigue vivo tras cierre | `adb shell ps \| grep zync` → proceso listado | ✅ |
| R5.09 | Notificación persiste tras cierre durante 30s | Ícono "i" no parpadea ni desaparece | ✅ |
| R5.10 | Segundo tap (idempotencia) → también cierra | App desaparece de recientes. Ícono "i" permanece sin duplicarse | ✅ |
| R5.11 | Notificación no parpadea durante el cierre | No desaparece momentáneamente ni se reinicia en el momento del tap | ✅ |
| R5.12 | Logout → ícono "i" desaparece | Ícono "i" desaparece. Redirige a Login | ✅ |
| R5.13 | Seleccionar emoji desde modal Círculo (sin Modo Silencio) | Estado actualizado. Sin efectos en BN | ✅ |
| R5.14 | SOS desde pantalla del Círculo (sin Modo Silencio) | Flujo SOS completo sin regresiones | ✅ |
| R5.15 | PT.1–PT.6 del PRIMER TRAMO siguen pasando | Todos ✅. Ícono permanece durante proceso vivo | ✅ |

---

## R6 — App Open — Flujos base

| ID | Caso de prueba | Resultado esperado | Estado |
|:--:|:--------------|:-------------------|:------:|
| R6.01 | Primera apertura — sin cuenta | Pantalla de registro visible. Sin crash | ✅ |
| R6.02 | Registro exitoso → redirige a NoCircleView | Tarjetas "Crear Círculo" y "Unirse a un Círculo" visibles | ✅ |
| R6.03 | App abre sin sesión activa → pantalla de Login | Login visible. Pantalla Círculo no aparece | ✅ |
| R6.04 | Login exitoso → aterriza en Pantalla Círculo | Círculo visible con el último emoji del usuario | ✅ |

---

## R7 — Interacción modal del Círculo (sin Modo Silencio)

| ID | Caso de prueba | Resultado esperado | Estado |
|:--:|:--------------|:-------------------|:------:|
| R7.01 | Tap "Reunión" en modal del Círculo | Emoji/estado "Reunión" aparece en pantalla del Círculo | ✅ |
| R7.02 | Tap "Universidad" en modal del Círculo | Emoji/estado "Universidad" aparece en pantalla del Círculo | ✅ |
| R7.03 | Tap "Bien" en modal del Círculo | Emoji/estado "🙂 Bien" aparece en pantalla del Círculo | ✅ |
| R7.04 | Tap "SOS" en modal del Círculo | Estado SOS se setea. Permiso GPS solicitado. Opción de ver posición en Maps | ✅ |
| R7.05 | Cualquiera de los 16 emojis desde modal del Círculo | Emoji correspondiente aparece en la pantalla del Círculo | ✅ |

---

## R8 — UI/UX

| ID | Caso de prueba | Resultado esperado | Estado |
|:--:|:--------------|:-------------------|:------:|
| R8.01 | Girar pantalla con modal abierto — no hay overflow | Distribución de elementos se mantiene en landscape | ✅ |
| R8.02 | Pantalla "Crear Círculo" — foco automático en textbox | Foco aparece de inmediato en el campo de nombre, sin tocar pantalla | ✅ |
| R8.03 | Cambiar de Login a Registro — foco en primer campo | Foco se posiciona automáticamente al cambiar de modo | ✅ |
| R8.04 | Tarjeta "Unirse a un Círculo" aparece casi simultáneamente con "Crear Círculo" | Ambas tarjetas visibles sin demora perceptible | ✅ |

---

# SECCIÓN 2 — NUEVOS

> Tests pendientes de primera validación en dispositivo físico.
> Todos corresponden a cambios implementados en PRs #99–#103.

---

## N1 — Reabrir app con Modo Silencio activo (PR #100)

> **Cambio:** `onCreate()` en `MainActivity` detecta `isSilentModeActive == true` y desactiva el servicio + notificación + flag antes de que la UI cargue.

| ID | Caso de prueba | Pasos | Resultado esperado | Estado |
|:--:|:--------------|:------|:-------------------|:------:|
| N1.01 | Ícono "i" desaparece al abrir desde launcher | (A) Activar Modo Silencio → (B) Tocar ícono ZYNC en launcher | Ícono "i" desaparece de BN en ≤2s | ⚠️ tarda ≥8s |
| N1.02 | App aterriza en Pantalla Círculo — no en Login≥8s CRÍTICO!! | Mismos pasos de N1.01 | Pantalla Círculo directa. Login no aparece | ✅ |
| N1.03 | Sesión y datos preservados al reabrir | Mismos pasos de N1.01 → verificar nombre de usuario, emoji actual, miembros | Todos los datos coinciden con el estado previo al cierre | ❌ Justo antes de cerrarse la app, esta adopta el emoji "NO Molestar", cuando debería mostrar el que elegió el usuario antes del cierre o el estado que tenía por geofencing |
| N1.04 | Emoji actualizado desde BN se refleja al reabrir | (A) Seleccionar emoji desde BN → (B) Abrir app desde launcher | El emoji seleccionado en BN es el que aparece en Pantalla Círculo |✅ |
| N1.05 | Abrir app sin Modo Silencio activo → sin efectos | Cerrar app normalmente → reabrir desde launcher | No aparece ícono "i". Comportamiento normal sin efectos secundarios | ✅ |
| N1.06 | La BN es persistente, sea que se cierre manualmente con el botón "Borrar" del dispositivo o se haga un swipe sobre el mensaje de aviso de la BN | Cerrar la BN con el botón "Borrar"/swipe desde Android |  Persiste exitosamente el ícono "i", sin efectos secundarios | ✅ |
---

## N2 — Último estado preservado al reabrir (PR #101)

> **Cambio:** `clearOfflineStatus()` eliminado. El `statusType` en Firestore ya no se resetea a `fine`. El último estado persiste.

| ID | Caso de prueba | Pasos | Resultado esperado | Estado |
|:--:|:--------------|:------|:-------------------|:------:|
| N2.01 | Sesión activa → aterriza directo en Círculo sin Login | (A) Estar logueado → (B) Forzar cierre de app sin logout → (C) Reabrir | Pantalla Círculo directa. Login no aparece | |
| N2.02 | Emoji ≠ "Bien" se preserva al reabrir (cerrar sin logout) | (A) Setear "Reunión" → (B) Cerrar app sin logout → (C) Reabrir | Emoji = "Reunión". No muestra 🙂 "Todo bien" | |
| N2.03 | Emoji se preserva tras logout + re-login | (A) Setear emoji → (B) Logout → (C) Login → ver Círculo | Emoji = valor anterior al logout | |
| N2.04 | Emoji se preserva al desactivar Modo Silencio (abrir app) | (A) Setear "Reunión" → (B) Activar Modo Silencio → (C) Abrir app | Emoji = "Reunión". No muestra 🙂 "Todo bien" | |
| N2.05 | Emoji se preserva: cerrar app sin logout → reabrir | (A) Setear emoji → (B) Cerrar sin logout → (C) Reabrir | Emoji = valor anterior | |

---

## N3 — `do_not_disturb` al activar Modo Silencio (PR #101)

> **Cambio:** Al activar Modo Silencio, `SilentFunctionalityCoordinator` escribe `do_not_disturb` en Firestore antes de llamar al nativo. Los miembros del círculo ven "🔕 No molestar" mientras el Modo Silencio está activo.

| ID | Caso de prueba | Pasos | Resultado esperado | Estado |
|:--:|:--------------|:------|:-------------------|:------:|
| N3.01 | Activar Modo Silencio → miembros ven 🔕 No molestar | (A) Activar Modo Silencio → (B) Verificar pantalla de otro miembro del círculo | Emoji = 🔕 y estado = "No molestar" para el usuario que activó | |
| N3.02 | Badge "💤 Desconectado" ya no aparece para ningún miembro | (A) Cualquier acción que antes mostraba "Desconectado" | Ningún miembro del círculo muestra el badge "💤 Desconectado" | |
| N3.03 | Al reabrir app (desactivar Modo Silencio) → estado actualizable | (A) Modo Silencio activo → (B) Reabrir app → (C) Seleccionar nuevo emoji | Estado cambia correctamente desde "🔕 No molestar" al nuevo emoji | |

---

## N4 — Race condition cold start — primer tap funciona (PR #101)

> **Cambio:** `activateSilentMode()` re-verifica el círculo desde Firebase si `_userHasCircle == false` al momento del tap, en lugar de cancelar silenciosamente.

| ID | Caso de prueba | Pasos | Resultado esperado | Estado |
|:--:|:--------------|:------|:-------------------|:------:|
| N4.01 | Cold start + tap inmediato en "Modo Silencio" | (A) Forzar cierre de app → (B) Reabrir → (C) Tocar "Modo Silencio" inmediatamente sin esperar | App se cierra. Ícono "i" aparece. El primer tap funciona | |

---

## N5 — Persistencia de notificación — Handler periódico (PR #102)

> **Cambio:** `KeepAliveService` re-llama `startForeground()` cada 5s. Resistencia a OEM (Samsung "Borrar todo", Xiaomi, Huawei).

| ID | Caso de prueba | Pasos | Resultado esperado | Estado |
|:--:|:--------------|:------|:-------------------|:------:|
| N5.01 | Swipe sobre ícono "i" — no se descarta | Con Modo Silencio activo → deslizar notificación | Notificación permanece visible | |
| N5.02 | "Borrar todo" → notificación reaparece | Con Modo Silencio activo → abrir BN → "Borrar todo" → esperar ≤10s | Ícono "i" reaparece automáticamente | |
| N5.03 | "Borrar todo" en Samsung → notificación reaparece | Mismo flujo de N5.02 en Samsung | Ícono "i" reaparece. `KeepAliveService` sigue activo | |
| N5.04 | Proceso sigue vivo después de "Borrar todo" | Después de N5.02: `adb shell ps \| grep zync` | Proceso `com.datainfers.zync` sigue listado | |
| N5.05 | Notificación reaparece sin abrir app | Después de N5.02 → NO abrir app → solo esperar | Ícono "i" vuelve solo | |
| N5.06 | Logcat muestra ticks periódicos | Con Modo Silencio activo → observar logcat 15s | Aparece `🔄 [KEEP-ALIVE] startForeground re-afirmado` cada ~5s | |
| N5.07 | Logout → handler se cancela | Modo Silencio activo → Ajustes → Cerrar Sesión | Notificación desaparece y no reaparece. Sin ticks en logcat | |

---

## N6 — Interacción desde BN con app cerrada (PRs #99–#100)

| ID | Caso de prueba | Pasos | Resultado esperado | Estado |
|:--:|:--------------|:------|:-------------------|:------:|
| N6.01 | Tap notificación → abre modal nativo | Con app cerrada → tocar ícono "i" en BN | Modal nativo abre correctamente. No relanza `MainActivity` | |
| N6.02 | Seleccionar emoji desde BN → Firestore actualizado | Desde N6.01 → seleccionar cualquier emoji | Estado actualizado en Firebase. Pantalla Círculo refleja el cambio al reabrir | |
| N6.03 | Cerrar modal sin seleccionar → ícono "i" permanece | Desde N6.01 → cerrar modal sin seleccionar | Ícono "i" sigue visible. App sigue cerrada (no en recientes) | |
| N6.04 | Seleccionar emoji → ícono "i" permanece | Completar N6.02 | Ícono "i" sigue visible después de seleccionar el emoji | |
| N6.05 | SOS hold 1s desde modal BN | Con Modo Silencio activo → abrir modal BN → mantener SOS 1s | Estado SOS seteado. Modal cierra. Ícono "i" permanece | |
| N6.06 | SOS hold 1s desde modal Círculo (sin Modo Silencio) | Sin Modo Silencio → abrir modal Círculo → hold SOS 1s | Estado SOS seteado. Modal cierra correctamente | |
| N6.07 | Ciclo completo: activar → emoji desde BN → reabrir → activar | Repetir ciclo 2 veces | Comportamiento consistente en ambos ciclos. Sin efectos secundarios | |
| N6.08 | Múltiples ciclos abrir/cerrar sin Modo Silencio | Abrir → cerrar → abrir → cerrar (3 ciclos) sin activar Modo Silencio | Sin aparición involuntaria de ícono "i". Sin regresiones | |

---

## N7 — Zona bloqueada desde modal nativo con cache vacío (PR #103)

> **Cambio:** `_updateStatusFromNative()` muestra un SnackBar cuando `StatusService` retorna `zone_manual_selection_not_allowed`. Cubre el caso donde `configuredZoneTypes` está vacío en `EmojiDialogActivity`.

| ID | Caso de prueba | Pasos | Resultado esperado | Estado |
|:--:|:--------------|:------|:-------------------|:------:|
| N7.01 | Zona bloqueada con cache poblado → dialog en modal | Con zona geográfica configurada y cache actualizado → abrir modal BN → tocar emoji de zona | Dialog "Acción no permitida" aparece dentro del modal nativo | |
| N7.02 | Zona bloqueada → SnackBar en app | Escenario de cache vacío → seleccionar emoji de zona desde modal BN → abrir app | SnackBar "Esa zona se actualiza automáticamente por geofencing…" visible al reabrir | |

---

## N8 — Pendientes menores

| ID | Caso de prueba | Pasos | Resultado esperado | Estado |
|:--:|:--------------|:------|:-------------------|:------:|
| N8.01 | Permiso de notificaciones denegado → SnackBar naranja | Tap "Modo Silencio" con permiso denegado | SnackBar con botón "Habilitar" que lleva a Ajustes del sistema | |
| N8.02 | Re-habilitar notificaciones desde Ajustes → activar Modo Silencio | Tap "Habilitar" en SnackBar → Ajustes → activar → volver → tap "Modo Silencio" | Flujo normal de activación | |
| N8.03 | Usuario desactiva notificaciones del sistema con Modo Silencio activo | Ajustes del sistema → desactivar notificaciones de ZYNC | Ícono desaparece. Al volver a app: SnackBar informativo. Modo Silencio inactivo | |
| N8.04 | Look & feel ventanas de aviso — modal BN ≈ modal Círculo | Activar zona en ambos modales → comparar visualmente | Mismo fondo negro, borde menta, botón "Entendido" en menta | |
| N8.05 | Permisos de batería pendientes durante primera activación | Primer uso → tap "Modo Silencio" → dialog batería → aceptar | App se cierra correctamente después del dialog. Ícono "i" aparece | |
