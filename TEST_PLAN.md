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
| 12 | Eliminación de cuenta — usuario es **creador** del círculo | El círculo entero es eliminado de Firestore. Todos los ex-miembros ven "Aún no estás en un círculo". Redirige al login. | 👁 | ✅ | Probado manualmente 2026-03-27. Fix requerido: doble invocación de `deactivateAfterLogout()` desde `auth_provider` + context shadow en `StatefulBuilder` impedían la navegación post-delete. Resuelto en PR #43. Verificar que se elimine el Círculo y que no quede vacío|

---

## Fase 2 — Círculos

| No. | Caso de prueba | Resultado esperado | Tipo | Estado | Observaciones |
|:---:|:---|:---|:---:|:---:|:---|
| 1 | Creación de un círculo | Círculo creado en Firestore, código de invitación generado | 🔗 | ✅ | Test automatizado pasando 2026-03-20. |
| 2 | Eliminación de un círculo | No existe acción explícita "eliminar círculo". El círculo se elimina como efecto secundario cuando el creador elimina su cuenta (T1.12 ✅). Los miembros no pueden salir sin eliminar su cuenta (filosofía MVP: "estás o no estás"). | 👁 | ✅ | Cubierto por T1.12 (creador) y T1.10 (miembro). Filosofía confirmada 2026-03-27: sin opción de salir del círculo sin eliminar cuenta. |
| 3 | Intento de crear más de un círculo | **MVP: un círculo por usuario.** La app bloquea la creación de un segundo círculo. | 👁 | ✅ | Cubierto por diseño de UI: el botón "Crear Círculo" solo existe en `NoCircleView`, que nunca se muestra si el usuario ya pertenece a un círculo. Validación backend de respaldo en `CircleService.createCircle()`. No requiere test manual. Verificado 2026-03-27. |
| 4 | Generación del código de invitación | Código único generado y visible para compartir | 🔗 | ✅ | Test automatizado pasando 2026-03-20. |
| 5 | Estado/emoji inicial al unirse a un círculo | Se muestra "Todo bien" como estado por defecto | 🔗 | ✅ | Test automatizado pasando 2026-03-20. |
| 6 | Cambiar de estado/emoji | Estado actualizado en Firestore y visible para los miembros del círculo | 🔗 | ✅ | Test automatizado pasando 2026-03-20. |
| 7 | La UI no ofrece "Salir del Círculo" sin eliminar cuenta | El usuario dentro de un círculo no encuentra ninguna opción para salir sin eliminar su cuenta (Settings u otra pantalla) | 🔗 | ✅ | Test automatizado pasando 2026-03-23. Verifica ausencia de `btn_leave_circle` en Settings. Decisión de diseño confirmada 2026-03-27: filosofía "estás o no estás" — `btn_leave_circle` y su lógica eliminados de `settings_page.dart`. |
| 8 | Eliminar cuenta siendo **creador** — otros miembros activos | Círculo eliminado de Firestore. Todos los ex-miembros ven "Aún no estás en un círculo". | 👁 | ✅ | Cubierto por T1.12 ✅. La lógica de eliminación del círculo y notificación a miembros vía Firestore streams es idéntica independientemente del número de miembros activos. No requiere test adicional. |
| 9 | Eliminar cuenta siendo **miembro común** — creador sigue activo | Solo ese miembro es removido. El círculo y los demás miembros siguen sin cambios. | 👁 | ✅ | Cubierto por T1.10 ✅ (flujo explícito: A crea círculo → B se une → B elimina cuenta → A verifica círculo intacto). Escenario idéntico. No requiere test adicional. |
| 10 | Solicitud de ingreso — solicitante queda en estado pendiente | B ingresa código y ve pantalla de espera. En Firestore: `joinRequests/{uid}` con status "pending" y `users/{uid}.pendingCircleId` seteado. | 🔗 | ✅ | Estado inicial verificado por test automatizado 2026-03-23. Flujo completo pendiente de prueba manual T2.11–T2.12. |
| 11 | Creador aprueba solicitud | A ve la solicitud en InCircleView con botón "Aceptar". B pasa automáticamente a InCircleView. `joinRequests/{uid}.status = "approved"`. | 🔗 | ✅ | Test automatizado pasando 2026-03-27. Ver `approval_flow_test.dart`. |
| 12 | Solicitud expira (48h sin respuesta) — lazy expiration | Creador abre app con solicitud > 48h: desaparece de InCircleView, `joinRequests/{uid}.status = "expired"`. Solicitante abre app: `pendingCircleId` se limpia, ve NoCircleView y puede reenviar el código. | 🔗 | ✅ | Test automatizado pasando 2026-03-27. Umbral bajado a 1 min para testing, restaurado a 48h post-test. Ver `expiration_flow_test.dart`. |
| 13 | Solicitante puede reenviar código tras expiración | Con solicitud expirada, B puede reingresar el mismo código y crear nueva solicitud. `joinRequests/{uid}` se sobreescribe con nuevo `requestedAt`. | 🔗 | ✅ | Test automatizado pasando 2026-03-27. Cubierto por el mismo flujo de T2.12. Ver `expiration_flow_test.dart`. |

---

## Fase 3 — Actualización de Emojis / Estados

| No. | Caso de prueba | Resultado esperado | Tipo | Estado | Observaciones |
|:---:|:---|:---:|:---:|:---:|:---|
| 1 | Estado default al unirse a un círculo | Emoji "Todo bien" asignado automáticamente | 🔗 | ✅ | Cubierto por Fase 2 T05. |
| 2 | Cambio de estado desde modal del círculo | Actualización sin demora, visible para todos los miembros | 🔗 | ✅ | Cubierto por Fase 2 T06. |
| 10.1 | Sin zonas configuradas — cualquier estado elegido | Muestra: emoji · nickname · estado · timestamp relativo (ej: "Justo Ahora", "Hace X min") | 🔗 | ✅ | Test automatizado pasando 2026-03-20. Formato relativo, no `dd/mm/aa hh:mm:ss`. |
| 20.1 | Con zonas activas — usuario entra a una zona | Estado actualizado automáticamente con emoji de la zona | 👁 | ✅ | Geofencing manual funciona correctamente |
| 20.2 | Con zonas activas — usuario sale de una zona | Estado cambia a "En camino" automáticamente | 👁 |✅ | Geofencing manual funciona correctamente |
| 30.1 | Dentro de zona, usuario cambia estado manualmente a no-zona | Muestra: emoji · nickname · estado · tiempo · ✋ Manual | 🔗 | ✅ | Test automatizado pasando 2026-03-20. |
| 30.2 | Fuera de zona, usuario cambia estado manualmente | Muestra: emoji · nickname · estado · tiempo · ❓ Ubicación desconocida (sin ✋ Manual — `manualOverride=false` cuando `zoneId=null`) | 🔗 | ✅ | Test automatizado pasando 2026-03-20. Corregido 2026-03-30: ✋ no aplica desde AUTO_DRIVING porque `wasInZone=false`. Confirmado por máquina de estados (Prueba B3). |
| 30.3 | Con zonas geográficas configuradas — selector de estado muestra botones 🏠🏫🏢🏥 visualmente inhabilitados | Botones de zona aparecen con opacidad reducida (atenuados). Si se tocan igualmente, aparece modal "Acción no permitida" y el estado no cambia. | 👁 | ✅ | Verificado manualmente 2026-03-30. Ver procedimiento en tabla de pruebas manuales. No automatizable: `StatusSelectorOverlay` carga Firebase via fire-and-forget en initState, sin streams activos el event loop del test binding no procesa las platform channel callbacks. |

---

## Fase 4 — Modo Silent *

| No. | Caso de prueba | Resultado esperado | Tipo | Estado | Observaciones |
|:---:|:---|:---|:---:|:---:|:---|
| 4.0 | Modal de barra superior idéntico al modal del Círculo | Ambos modales muestran los mismos 16 estados en el mismo orden, con el mismo botón SOS al fondo | 👁 | ✅ | Verificado 2026-03-31. PR #61 + commits a144ce2 y 15ee7e6: (1) "Bien" no aparecía — EmojiDialogActivity ahora usa hardcoded fallback como base, ignorando Firebase para predefinidos; (2) zonas configuradas no se bloqueaban — EmojiCacheService sincroniza zone types a SharedPreferences y ZoneService dispara re-sync al crear/editar/eliminar zonas; (3) espacio vacío antes del SOS — ScrollView usa WRAP_CONTENT con AT_MOST en lugar de altura fija; (4) emoji Reunión era 📅 en nativo vs 👥 en fuente de la verdad — corregido en hardcoded fallback. |
| 4.1 | App minimizada | Ícono visible en barra superior del dispositivo | 👁 | ✅ | Si se aprecia el ícono de la app con el valor "i". Se puede personalizar a otro? |
| 4.2 | Sin cierre de sesión, app minimizada | App permanece activa en modo silent con ícono visible | 👁 | ✅| Todo Ok pero con la misma duda anterior|
| 4.3 | Con cierre de sesión | Ícono desaparece de la barra superior  | 👁 |✅ | El usuario desaparece hasta que no se vuelva a loguear/ registrar _¿es correcto esto, o contradice la filosofía de ZYNC?_|
| 4.4 | Modal NotificationStatusSelector muestra 16 botones de estado | Grid visible con los 16 estados del sistema | 🔗 | ✅ | Test automatizado pasando 2026-03-20. Modal renderizado en aislamiento. |
| 4.5 | Selección de estado desde modal → Firestore actualizado | `statusType` actualizado en `circles/{id}/memberStatus` | 🔗 | ✅ | Test automatizado pasando 2026-03-20. |
| 4.6 | Usuario deniega permiso de notificaciones al ingresar | App funciona normalmente. No hay ícono en barra. SnackBar naranja explica la situación con botón "Habilitar" | 👁 | | GAP actual: no hay feedback al usuario. `_showNotificationsDisabledInfo()` existe en `silent_functionality_coordinator.dart` pero no está conectado al flujo de denegación |
| 4.7 | Intento de swipe sobre la notificación persistente | La notificación no se puede descartar con swipe | 👁 | | `setOngoing=true` en `KeepAliveService.kt` debería cubrirlo — verificar en dispositivo físico |
| 4.8 | "Borrar todo" en la barra de notificaciones | La notificación de ZYNC permanece intacta | 👁 | | Las notificaciones `ongoing` están excluidas del borrado masivo de Android — verificar en dispositivo físico |
| 4.9 | Usuario desactiva notificaciones desde Ajustes del sistema (post-login) | Ícono desaparece. Al volver a la app, SnackBar informativo aparece | 👁 | | GAP actual: no se detecta. Requiere chequeo en `onResume` vía `WidgetsBindingObserver` |
| 4.10 | Usuario "cierra" la app desde Recientes | Ícono permanece en barra — modo silent sigue activo | 👁 | | Comportamiento intencional: `onTaskRemoved()` + `START_STICKY` en `KeepAliveService.kt`. El único cierre real es el logout |
| 4.11 | Re-habilitar notificaciones tras denegación o revocación | Usuario toca "Habilitar" en SnackBar → va a Ajustes del sistema → activa → vuelve a app → ícono aparece | 👁 | | Infraestructura ya existe (`_checkAndNotifyPermissionStatus`, `openNotificationSettings`). Falta conectar al flujo de denegación |

---

## Fase 5 — Modo Configuración

| No. | Caso de prueba | Resultado esperado | Tipo | Estado | Observaciones |
|:---:|:---|:---|:---:|:---:|:---|
| 1 | Cambiar las 4 Quick Actions configuradas por el usuario | Las nuevas acciones quedan guardadas en preferencias y se reflejan en los shortcuts | 🔗 | ✅ | Test automatizado pasando 2026-03-20. |
| 2 | Verificar que los cambios de Quick Actions se reflejan en los shortcuts nativos | Los shortcuts del SO muestran los nuevos estados | 👁 | | Requiere inspección visual en el dispositivo. |
| 3 | Agregar un emoji personalizado | Emoji creado y visible en Firestore (`circles/{id}/customEmojis`) | 🔗 | ✅ | Test automatizado pasando 2026-03-20. Emoji creado directamente en Firestore (EmojiPicker nativo no testeable en integración). |
| 4 | Eliminar un emoji personalizado | Emoji eliminado de Firestore y desaparece del tab Estados | 🔗 | ✅ | Test automatizado pasando 2026-03-20. Fix: documento debe incluir `usageCount: 0` — Firestore excluye docs sin ese campo del `orderBy`. |
| 5 | Emoji personalizado aparece en el tab Estados de Settings | Tab Estados muestra el emoji recién creado con su label | 🔗 | ✅ | Test automatizado pasando 2026-03-20. Mismo fix que T5.4 (`usageCount: 0`). |
| 6 | Si el usuario cierra su sesión adrede, el Círculo, debería mostrar el emoji/estado que está off-line y que lo ha hecho manualmente (falta un emoji/estado?) | Se deja rastro en el Círculo de que el usuario ha cerrado su sesión | 👁 |  |
---

## Fase 6 — Funcionamiento UI/UX

| No. | Caso de prueba | Resultado esperado | Tipo | Estado | Observaciones |
|:---:|:---|:---|:---:|:---:|:---|
| 6.1 | Al girar el celular el modal de Emojis/Estados no cabe en la pantalla y ocurre un 'overflow' de la misma | Mantener la distribución de los elementos | 👁 | | |
| 6.2 | En la pantalla que crea un C+irculo nuevo, hay una demora en tener el foco el textbox donde se ingresa el nombre del mismo  | El foco debe de aparecer por default sobre el textbox de inmediato | 👁 | | |
| 6.3 | Cunado se cambia opción de Login a Registrar el foco no aparece en el primer textbox de cada una de ellas, sino que hay que colocarlo a mano  |Esto debiera ser automático | 👁 | | |
| 6.4 | Las ventanas modales de los emojis/estados tienen diferente "look and feel". La ventana modal desde la barra debeería parecerse lo más posible a la fuente de la verdad (ventana modal lanzada desde la pantalla del Círculo)  | Estas ventanas debieran ser casi idénticas, no solo en contenido sino además en la apariencia | 👁 | | |
---
## Tests Manuales 


| No. | ID | Fase | Caso de prueba | Notas |
|:---:|:--:|:----:|:---|:---|
| 1 | T1.5 | 1 | Login fallido — correo no encontrado | Firebase email-enumeration-protection devuelve `invalid-credential`. No automatizable sin cambiar config Firebase. |
| 2 | T1.10 | 1 | Eliminación de cuenta — usuario es **miembro común** del círculo | Requiere Brecha 2 implementada. Solo ese usuario removido; círculo y demás miembros intactos. |
| 3 | T1.11 | 1 | Eliminación de cuenta — sesión no reciente (requires-recent-login) | Flujo: login → cerrar app SIN cerrar sesión → esperar 5-10 min → reabrir → Eliminar Cuenta. |
| 4 | T2.10 | 2 | Solicitud de ingreso — flujo completo manual | Estado inicial cubierto por test automatizado. Verificar manualmente: PendingRequestView visible, datos correctos en Firestore, UX del solicitante. |
| 5 | T2.11 | 2 | Creador aprueba solicitud | A ve botón "Aceptar" en InCircleView. B pasa automáticamente a InCircleView. |
| 6 | T2.12 | 2 | Solicitud expira (48h) — lazy expiration | Solicitud desaparece de InCircleView del creador. Solicitante ve NoCircleView y puede reenviar. |
| 7 | T2.13 | 2 | Solicitante reenvía código tras expiración | B reingresa mismo código → nueva solicitud `pending` creada con nuevo `requestedAt`. |
| 10 | T3.20.1 | 3 | Con zonas activas — usuario entra a una zona | Requiere GPS activo y zona configurada en el círculo. |
| 11 | T3.20.2 | 3 | Con zonas activas — usuario sale de una zona | Verificar cambio automático a "En camino". |
| 11b | T3.30.3 | 3 | Con zonas geográficas configuradas — botones 🏠🏫🏢🏥 inhabilitados en el selector | Precondición: círculo con al menos una zona geográfica configurada. Pasos: (1) tocar propio avatar → selector abre → verificar que 🏠🏫🏢🏥 aparecen atenuados (opacidad reducida). (2) Tocar cualquiera de esos botones → modal "Acción no permitida" aparece → tocar "Entendido" → estado no cambió. |
| 12 | T4.1 | 4 | App minimizada — ícono visible en barra superior | Inspección visual en dispositivo físico. |
| 13 | T4.2 | 4 | App minimizada sin cerrar sesión — modo silent activo | Verificar que el ícono persiste y el servicio sigue vivo. |
| 14 | T4.3 | 4 | Cerrar sesión — ícono desaparece de barra superior | Comportamiento a confirmar. |
| 15 | T5.2 | 5 | Quick Actions reflejadas en shortcuts nativos del SO | Inspección visual: mantener pulsado el ícono de la app en el launcher. |
| 16 | T4.6 | 4 | Permiso de notificaciones denegado — feedback visible | Precondición: desinstalar app para resetear permisos. Pasos: instalar → login → denegar permisos → verificar que aparece SnackBar naranja con botón "Habilitar". GAP: aún no implementado. |
| 17 | T4.7 | 4 | Swipe sobre notificación persistente — no se descarta | Precondición: app con ícono visible. Pasos: abrir barra de notificaciones → intentar deslizar la notificación de ZYNC → verificar que permanece. |
| 18 | T4.8 | 4 | "Borrar todo" — notificación ZYNC permanece | Precondición: app con ícono visible + otras notificaciones presentes. Pasos: abrir barra → tocar "Borrar todo" → verificar que la notificación de ZYNC permanece. |
| 19 | T4.9 | 4 | Desactivar notificaciones desde Ajustes del sistema | Precondición: app con ícono visible. Pasos: Ajustes → Apps → ZYNC → Notificaciones → OFF → volver a app → verificar SnackBar informativo. GAP: aún no implementado. |
| 20 | T4.10 | 4 | Cerrar app desde Recientes — ícono persiste | Precondición: app con ícono visible. Pasos: abrir Recientes → deslizar ZYNC → esperar 3-5 seg → verificar que el ícono sigue en la barra superior. |
| 21 | T4.11 | 4 | Re-habilitar notificaciones desde SnackBar | Precondición: T4.6 o T4.9 ejecutado (sin ícono). Pasos: tocar "Habilitar" en SnackBar → activar en Ajustes → volver a app → verificar ícono aparece. GAP: aún no implementado. |

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