# TEST_PLAN.md — Plan de Pruebas ZYNC

> Documento vivo que registra los flujos de prueba, su estado y observaciones.
> Referenciado desde `CLAUDE.md` sección 7.
> La IA actualiza este archivo al completar cada fase de tests, previa aprobación del desarrollador.

---

## Leyenda

| Símbolo | Significado |
|---------|-------------|
| 🔬 | Test unitario |
| 🔗 | Test de integración |
| 👁 | Solo manual (no automatizable) |
| ✅ | Pasando |
| ⚠️ | Falla conocida / comportamiento inesperado |
| ❌ | Falla bloqueante |

---

## Protocolo de pruebas manuales en dispositivo físico

**Antes de cada sesión de pruebas:**
1. Abrir PowerShell como Administrador
2. `adb kill-server; adb start-server` — reiniciar daemon ADB
3. `flutter run -d R58W315389R` — compilar e instalar
4. Si aparece error `DDS shut down too early` → abrir la app manualmente en el dispositivo
5. Verificar que el timestamp `v HH:MM:SS` en la pantalla de login está actualizándose — confirma que es el build correcto

**Durante las pruebas:**
- Probar un flujo completo a la vez
- Registrar resultado por caso: ✅ pasa / ❌ falla / ⚠️ comportamiento inesperado
- Si falla → fix → `flutter run` nuevo → re-probar ese caso antes de continuar
- No avanzar al siguiente flujo si el anterior tiene un ❌ sin resolver

**Cuando los cambios no se reflejan:**

| Situación | Comando |
|-----------|---------|
| Cambio solo de UI (colores, textos) | `r` en terminal |
| Cambio en lógica de widget | `R` en terminal |
| Cambio en servicios o providers | `Ctrl+C` → `flutter run -d R58W315389R` |
| Nada de lo anterior funciona | `Ctrl+C` → `flutter clean` → `flutter run -d R58W315389R` |

**Device ID del dispositivo de pruebas:** `R58W315389R` (SM A145M — Android 15)

---

## Fase 1 — Registro y Login de Usuarios

| No. | Caso de prueba | Resultado esperado | Tipo | Estado | Observaciones |
|:---:|:---|:---|:---:|:---:|:---|
| 1 | Registro exitoso — nickname + email + contraseña + confirmación coinciden | Usuario creado en Firebase Auth y Firestore | 🔗 | ✅ | Lógica verificada 2026-03-20. Error post-test en infra (AuthNotifier dispose tras delete()) — no afecta funcionalidad. |
| 2 | Registro fallido — contraseñas no coinciden | Botón "Crear Cuenta" deshabilitado | 🔬 | ✅ | Test automatizado pasando 2026-03-20. |
| 3 | Registro fallido — email ya registrado | Mensaje "Este correo ya tiene una cuenta registrada. Inicia sesión." | 🔗 | ✅ | Test pasando 2026-03-23. Fix: retry loop en `_tapToggleModeButton` resuelve bloqueo por `RenderIgnorePointer` transitorio entre tests. |
| 4 | Login exitoso — credenciales válidas | Acceso a la app | 🔗 | ✅ | Lógica verificada 2026-03-20. Error post-test en infra (Firestore stream permission-denied al hacer signOut) — no afecta funcionalidad. |
| 5 | Login fallido — correo no encontrado | Mensaje "Correo o contraseña incorrectos. Verifica que te has registrado e intenta de nuevo" | 👁 | ✅ | Firebase email-enumeration-protection devuelve `invalid-credential` en vez de `user-not-found`. No automatizable sin cambiar config de Firebase. |
| 6 | Login fallido — contraseña incorrecta | Mensaje "La contraseña es incorrecta. Verifica e intenta de nuevo." | 🔗 | ✅ | Test pasando 2026-03-23. |
| 7 | Recuperación de contraseña — correo válido registrado | Email de recuperación enviado | 🔗 | ✅ | Test automatizado pasando 2026-03-20. |
| 8 | Cierre de sesión | Regreso a pantalla de login | 🔗 | ✅ | Lógica verificada 2026-03-20. Error post-test en infra (mismo Firestore stream que T04) — no afecta funcionalidad. |
| 9 | Eliminación de cuenta — usuario sin círculo | Cuenta eliminada de Auth y Firestore. Redirige al login. | 👁 | ✅ | Probado manualmente 2026-03-18. Re-verificar post-implementación de Brecha 2 (bajo riesgo). |
| 10 | Eliminación de cuenta — usuario es **miembro común** del círculo | Solo ese usuario es removido del círculo. El círculo y los demás miembros permanecen intactos. Redirige al login. | 👁 | ✅ | Probado manualmente 2026-03-26 con un solo dispositivo (flujo A crea círculo → B se une → B elimina cuenta → A verifica círculo intacto). Fix requerido: nickname del nuevo miembro aparecía como uid en primera carga (timing Firestore). Resuelto en PR #42. |
| 11 | Eliminación de cuenta — sesión no reciente (requires-recent-login) | App solicita contraseña, re-autentica y elimina. Si contraseña incorrecta: SnackBar rojo, cuenta intacta. | 👁 | ✅ | Flujo: login → cerrar app SIN cerrar sesión → esperar 5-10 min → reabrir → Eliminar Cuenta. |
| 12 | Eliminación de cuenta — usuario es **creador** del círculo | El círculo entero es eliminado de Firestore. Todos los ex-miembros ven "Aún no estás en un círculo". Redirige al login. | 👁 | ✅ | Probado manualmente 2026-03-27. Fix requerido: doble invocación de `deactivateAfterLogout()` desde `auth_provider` + context shadow en `StatefulBuilder` impedían la navegación post-delete. Resuelto en PR #43. |

---

## Fase 2 — Círculos

| No. | Caso de prueba | Resultado esperado | Tipo | Estado | Observaciones |
|:---:|:---|:---|:---:|:---:|:---|
| 1 | Creación de un círculo | Círculo creado en Firestore, código de invitación generado | 🔗 | ✅ | Test automatizado pasando 2026-03-20. |
| 2 | Eliminación de un círculo | Solo el **creador** puede eliminar el círculo. Los miembros solo pueden abandonarlo. Al eliminarse, todos los miembros quedan desvinculados y regresan a "Aún no estás en un círculo". | 👁 | | Test automatizado repropuesto para cubrir T2.7. Verificación manual pendiente (T2.8, T2.9). |
| 3 | Intento de crear más de un círculo | **MVP: un círculo por usuario.** La app bloquea la creación de un segundo círculo. | 👁 | ✅ | Cubierto por diseño de UI: el botón "Crear Círculo" solo existe en `NoCircleView`, que nunca se muestra si el usuario ya pertenece a un círculo. Validación backend de respaldo en `CircleService.createCircle()`. No requiere test manual. Verificado 2026-03-27. |
| 4 | Generación del código de invitación | Código único generado y visible para compartir | 🔗 | ✅ | Test automatizado pasando 2026-03-20. |
| 5 | Estado/emoji inicial al unirse a un círculo | Se muestra "Todo bien" como estado por defecto | 🔗 | ✅ | Test automatizado pasando 2026-03-20. |
| 6 | Cambiar de estado/emoji | Estado actualizado en Firestore y visible para los miembros del círculo | 🔗 | ✅ | Test automatizado pasando 2026-03-20. |
| 7 | La UI no ofrece "Salir del Círculo" sin eliminar cuenta | El usuario dentro de un círculo no encuentra ninguna opción para salir sin eliminar su cuenta (Settings u otra pantalla) | 🔗 | ✅ | Test automatizado pasando 2026-03-23. Verifica ausencia de `btn_leave_circle` en Settings (Brecha 1 implementada). |
| 8 | Eliminar cuenta siendo **creador** — otros miembros activos | Círculo eliminado de Firestore. Todos los ex-miembros ven "Aún no estás en un círculo". | 👁 | | Pendiente. Pasos: (1) Usuario A crea círculo. (2) Usuario B se une. (3) A elimina cuenta. (4) Verificar en Firestore y en la app del Usuario B. |
| 9 | Eliminar cuenta siendo **miembro común** — creador sigue activo | Solo ese miembro es removido. El círculo y los demás miembros siguen sin cambios. | 👁 | | Pendiente. Pasos: (1) A crea círculo. (2) B se une. (3) B elimina cuenta. (4) Verificar que el círculo de A sigue intacto. |
| 10 | Solicitud de ingreso — solicitante queda en estado pendiente | B ingresa código y ve pantalla de espera. En Firestore: `joinRequests/{uid}` con status "pending" y `users/{uid}.pendingCircleId` seteado. | 🔗 | ✅ | Estado inicial verificado por test automatizado 2026-03-23. Flujo completo (aprobación/rechazo) pendiente de prueba manual T2.11–T2.15. |
| 11 | Creador aprueba solicitud | A ve la solicitud en InCircleView y aprueba. B pasa automáticamente a InCircleView. `joinRequests/{uid}.status = "approved"`. | 👁 | | Pendiente. Requiere `WORK_PLAN_JOIN_APPROVAL.md`. |
| 12 | Creador rechaza solicitud | A rechaza. B regresa a NoCircleView. En Firestore: `joinRequests/{uid}.status = "rejected"`, `pendingCircleId` eliminado. | 👁 | | Pendiente. Requiere `WORK_PLAN_JOIN_APPROVAL.md`. |
| 13 | Solicitante rechazado intenta unirse de nuevo al mismo círculo | App muestra error. No se crea nueva solicitud. | 👁 | | Pendiente. Opción A confirmada: rechazo permanente de ese círculo. |
| 14 | Solicitante rechazado puede crear su propio círculo | Después del rechazo, B puede crear un círculo nuevo sin restricción. | 👁 | | Pendiente. Verificar que el rechazo no bloquea otras opciones. |
| 15 | No se puede enviar segunda solicitud con una pendiente activa | Con `pendingCircleId` activo, intentar unirse a otro círculo muestra error. | 👁 | | Pendiente. Evita solicitudes simultáneas. |

---

## Fase 3 — Actualización de Emojis / Estados

| No. | Caso de prueba | Resultado esperado | Tipo | Estado | Observaciones |
|:---:|:---|:---:|:---:|:---:|:---|
| 1 | Estado default al unirse a un círculo | Emoji "Todo bien" asignado automáticamente | 🔗 | ✅ | Cubierto por Fase 2 T05. |
| 2 | Cambio de estado desde modal del círculo | Actualización sin demora, visible para todos los miembros | 🔗 | ✅ | Cubierto por Fase 2 T06. |
| 10.1 | Sin zonas configuradas — cualquier estado elegido | Muestra: emoji · nickname · estado · timestamp relativo (ej: "Justo Ahora", "Hace X min") | 🔗 | ✅ | Test automatizado pasando 2026-03-20. Formato relativo, no `dd/mm/aa hh:mm:ss`. |
| 20.1 | Con zonas activas — usuario entra a una zona | Estado actualizado automáticamente con emoji de la zona | 👁 | | |
| 20.2 | Con zonas activas — usuario sale de una zona | Estado cambia a "En camino" automáticamente | 👁 | | |
| 30.1 | Dentro de zona, usuario cambia estado manualmente a no-zona | Muestra: emoji · nickname · estado · tiempo · ✋ Manual | 🔗 | ✅ | Test automatizado pasando 2026-03-20. |
| 30.2 | Fuera de zona, usuario cambia estado manualmente | Muestra: emoji · nickname · estado · tiempo · ✋ Manual · ❓ Ubicación desconocida | 🔗 | ✅ | Test automatizado pasando 2026-03-20. |
| 30.3 | Intento de cambiar zona automática por otra zona | Comportamiento bloqueado, se mantiene el estado actual | 🔗 | | |

---

## Fase 4 — Modo Silent

| No. | Caso de prueba | Resultado esperado | Tipo | Estado | Observaciones |
|:---:|:---|:---|:---:|:---:|:---|
| 4.1 | App minimizada | Ícono visible en barra superior del dispositivo | 👁 | | |
| 4.2 | Sin cierre de sesión, app minimizada | App permanece activa en modo silent con ícono visible | 👁 | | |
| 4.3 | Con cierre de sesión | Ícono desaparece de la barra superior *(comportamiento a confirmar)* | 👁 | | |
| 4.4 | Modal NotificationStatusSelector muestra 16 botones de estado | Grid visible con los 16 estados del sistema | 🔗 | ✅ | Test automatizado pasando 2026-03-20. Modal renderizado en aislamiento. |
| 4.5 | Selección de estado desde modal → Firestore actualizado | `statusType` actualizado en `circles/{id}/memberStatus` | 🔗 | ✅ | Test automatizado pasando 2026-03-20. |

---

## Fase 5 — Modo Configuración

| No. | Caso de prueba | Resultado esperado | Tipo | Estado | Observaciones |
|:---:|:---|:---|:---:|:---:|:---|
| 1 | Cambiar las 4 Quick Actions configuradas por el usuario | Las nuevas acciones quedan guardadas en preferencias y se reflejan en los shortcuts | 🔗 | ✅ | Test automatizado pasando 2026-03-20. |
| 2 | Verificar que los cambios de Quick Actions se reflejan en los shortcuts nativos | Los shortcuts del SO muestran los nuevos estados | 👁 | | Requiere inspección visual en el dispositivo. |
| 3 | Agregar un emoji personalizado | Emoji creado y visible en Firestore (`circles/{id}/customEmojis`) | 🔗 | ✅ | Test automatizado pasando 2026-03-20. Emoji creado directamente en Firestore (EmojiPicker nativo no testeable en integración). |
| 4 | Eliminar un emoji personalizado | Emoji eliminado de Firestore y desaparece del tab Estados | 🔗 | ✅ | Test automatizado pasando 2026-03-20. Fix: documento debe incluir `usageCount: 0` — Firestore excluye docs sin ese campo del `orderBy`. |
| 5 | Emoji personalizado aparece en el tab Estados de Settings | Tab Estados muestra el emoji recién creado con su label | 🔗 | ✅ | Test automatizado pasando 2026-03-20. Mismo fix que T5.4 (`usageCount: 0`). |

---

## Fase 6 — Funcionamiento UI/UX

| No. | Caso de prueba | Resultado esperado | Tipo | Estado | Observaciones |
|:---:|:---|:---|:---:|:---:|:---|
| — | Pendiente de definir | — | — | | |


---
## Tests Manuales 


| No. | ID | Fase | Caso de prueba | Notas |
|:---:|:--:|:----:|:---|:---|
| 1 | T1.5 | 1 | Login fallido — correo no encontrado | Firebase email-enumeration-protection devuelve `invalid-credential`. No automatizable sin cambiar config Firebase. |
| 2 | T1.10 | 1 | Eliminación de cuenta — usuario es **miembro común** del círculo | Requiere Brecha 2 implementada. Solo ese usuario removido; círculo y demás miembros intactos. |
| 3 | T1.11 | 1 | Eliminación de cuenta — sesión no reciente (requires-recent-login) | Flujo: login → cerrar app SIN cerrar sesión → esperar 5-10 min → reabrir → Eliminar Cuenta. |
| 4 | T2.8 | 2 | Eliminar cuenta siendo creador — otros miembros activos | Requiere dos dispositivos. Ver pasos en la fila T2.8 de Fase 2. |
| 5 | T2.9 | 2 | Eliminar cuenta siendo miembro común — creador sigue activo | Requiere dos dispositivos. Ver pasos en la fila T2.9 de Fase 2. |
| 8 | T2.10 | 2 | Solicitud de ingreso — flujo completo manual | Estado inicial cubierto por test automatizado. Verificar manualmente: PendingRequestView visible, datos correctos en Firestore, UX del solicitante. |
| 9 | T2.11 | 2 | Creador aprueba solicitud | A ve la solicitud en InCircleView y aprueba. B pasa automáticamente a InCircleView. |
| 10 | T2.12 | 2 | Creador rechaza solicitud | A rechaza. B regresa a NoCircleView. `pendingCircleId` eliminado en Firestore. |
| 11 | T2.13 | 2 | Solicitante rechazado intenta unirse al mismo círculo | App muestra error. No se crea nueva solicitud (rechazo permanente). |
| 12 | T2.14 | 2 | Solicitante rechazado puede crear su propio círculo | Después del rechazo, B puede crear un círculo nuevo sin restricción. |
| 13 | T2.15 | 2 | Segunda solicitud bloqueada mientras hay una pendiente activa | Con `pendingCircleId` activo, intentar unirse a otro círculo muestra error. |
| 14 | T3.20.1 | 3 | Con zonas activas — usuario entra a una zona | Requiere GPS activo y zona configurada en el círculo. |
| 15 | T3.20.2 | 3 | Con zonas activas — usuario sale de una zona | Verificar cambio automático a "En camino". |
| 16 | T4.1 | 4 | App minimizada — ícono visible en barra superior | Inspección visual en dispositivo físico. |
| 17 | T4.2 | 4 | App minimizada sin cerrar sesión — modo silent activo | Verificar que el ícono persiste y el servicio sigue vivo. |
| 18 | T4.3 | 4 | Cerrar sesión — ícono desaparece de barra superior | Comportamiento a confirmar. |
| 19 | T5.2 | 5 | Quick Actions reflejadas en shortcuts nativos del SO | Inspección visual: mantener pulsado el ícono de la app en el launcher. |

---

## Ejecución 

**Uno por uno**

- flutter test integration_test/auth_flow_test.dart -d R58W315389R

- flutter test integration_test/circle_flow_test.dart -d R58W315389R

- flutter test integration_test/status_flow_test.dart -d R58W315389R

- flutter test integration_test/silent_mode_flow_test.dart -d R58W315389R

- flutter test integration_test/settings_flow_test.dart -d R58W315389R


**Todo en Batch**

- flutter test integration_test/all_tests.dart -d R58W315389R

---