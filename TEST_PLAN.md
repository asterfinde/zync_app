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
| 30.4 | Se tiene que mantener apretando por 1s el botón de SOS del modal de emojis/estados | Luego de ese tiempo se cambia el estado a SOS y se cierra el modal correspondiente: verificar que esto ocurra en las 2 ventanas modales: la del Círculo y la de la Barra de Notificaciones | 👁 |  | Fix PR #71 (Bug B/C): el modal cierra inmediatamente al soltar el botón SOS; el update de GPS/Firestore corre en background. |

---

## Fase 4 — Modo Silencio

> **Nuevo flujo (post-rediseño):** El Modo Silencio se activa únicamente con un botón explícito en la pantalla del Círculo. Cuando está activo, la app pasa al background y la interacción ocurre exclusivamente desde la barra de notificaciones. Al reabrir la app, el Modo Silencio se desactiva automáticamente. No existe superposición de modales ni mutex.

| No. | Caso de prueba | Resultado esperado | Tipo | Estado | Observaciones |
|:---:|:---|:---|:---:|:---:|:---|
| 4.0 | Modal de barra superior idéntico al modal del Círculo | Ambos modales muestran los mismos 16 estados en el mismo orden, con el mismo botón SOS al fondo. Íconos de zona aparecen opacos/inhabilitados en ambos. | 👁 | ✅ | Verificado 2026-03-31. PR #61 + commits a144ce2 y 15ee7e6. |
| 4.1 | Botón "Modo Silencio" visible en pantalla del Círculo | Botón con fondo negro, borde menta, letras blancas, ubicado encima del botón "Ok" en `in_circle_view.dart` | 👁 |✅ | Nuevo. Pendiente de implementación. |
| 4.2 | Tap en "Modo Silencio" → aparece modal de confirmación | Modal con fondo negro, borde menta, letras blancas, botones Confirmar / Cancelar | 👁 |✅ | Nuevo. Si el usuario no tiene permiso de notificaciones, el permiso se solicita primero (Android 13+). Si lo deniega, aparece SnackBar informativo y el modal de confirmación no se muestra. |
| 4.3 | Confirmar Modo Silencio → app pasa al background de inmediato | La app se cierra sin dialogs adicionales (ni de Android ni de la app). El ícono "i" aparece en la barra de notificaciones. La sesión del usuario permanece activa. | 👁 | ✅ | Implementar con `moveTaskToBack(true)` en Kotlin. Sin dialog de Android post-confirmación. |
| 4.4 | Modal NotificationStatusSelector muestra 16 botones de estado | Grid visible con los 16 estados del sistema | 🔗 | ✅ | Test automatizado pasando 2026-03-20. Modal renderizado en aislamiento. |
| 4.5 | Selección de estado desde modal de barra → Firestore actualizado | `statusType` actualizado en `circles/{id}/memberStatus` | 🔗 | ✅ | Test automatizado pasando 2026-03-20. |
| 4.6 | Íconos de zona opacos/inhabilitados en modal de barra | Con zona geográfica configurada: los íconos 🏠🏫🏢🏥 aparecen atenuados en el modal de barra, igual que en el modal del Círculo. Si se tocan, aparece aviso "Acción no permitida". | 👁 | ✅| Comportamiento ya existe en el modal del Círculo — replicar en `EmojiDialogActivity`. |
| 4.7 | Intento de swipe sobre la notificación persistente | La notificación no se puede descartar con swipe | 👁 | | `setOngoing=true` en `KeepAliveService.kt` debería cubrirlo — verificar en dispositivo físico. |
| 4.8 | "Borrar todo" en la barra de notificaciones | La notificación de ZYNC permanece intacta | 👁 | | Las notificaciones `ongoing` están excluidas del borrado masivo de Android — verificar en dispositivo físico. |
| 4.9 | Con cierre de sesión | Ícono desaparece de la barra superior. El Modo Silencio queda desactivado. | 👁 | ✅ | Comportamiento existente verificado. |
| 4.10 | Usuario "cierra" la app desde Recientes estando en Modo Silencio | Ícono permanece en barra — KeepAlive service sigue activo | 👁 |✅ | Comportamiento intencional: `onTaskRemoved()` + `START_STICKY` en `KeepAliveService.kt`. El único cierre real del Modo Silencio es el logout o reabrir la app. |
| 4.11 | Reabrir la app desde el launcher estando en Modo Silencio | El ícono de la barra de notificaciones desaparece automáticamente. La interacción vuelve a ser desde la pantalla del Círculo. | 👁 | | Nuevo. Implementar en `onAppResumed()` / `onResume` de `MainActivity`: si `_isSilentModeActive == true`, llamar `deactivateSilentMode()`. |
| 4.12 | Permiso de notificaciones denegado al intentar activar Modo Silencio | El modal de confirmación no se muestra. Aparece SnackBar naranja con botón "Habilitar" que lleva a Ajustes del sistema. | 👁 | | Flujo: tap "Modo Silencio" → verificar permiso → si denegado → SnackBar. Android 13+: el dialog de permisos solo se muestra una vez; después de eso, solo se puede enviar a Ajustes. |
| 4.13 | Re-habilitar notificaciones desde Ajustes y volver a activar Modo Silencio | Usuario toca "Habilitar" en SnackBar → va a Ajustes → activa → vuelve a app → tap "Modo Silencio" → flujo normal de confirmación. | 👁 | | |
| 4.14 | Usuario desactiva notificaciones del sistema con Modo Silencio activo | El ícono desaparece de la barra. Al volver a la app, SnackBar informativo. Modo Silencio queda inactivo. | 👁 | | |

---

## Fase 5 — Modo Configuración

| No. | Caso de prueba | Resultado esperado | Tipo | Estado | Observaciones |
|:---:|:---|:---|:---:|:---:|:---|
| 5.1 | Cambiar las 4 Quick Actions configuradas por el usuario | Las nuevas acciones quedan guardadas en preferencias y se reflejan en los shortcuts | 🔗 | ✅ | Test automatizado pasando 2026-03-20. |
| 5.2 | Verificar que los cambios de Quick Actions se reflejan en los shortcuts nativos | Los shortcuts del SO muestran los nuevos estados | 👁 | | Requiere inspección visual en el dispositivo. |
| 5.3 | Agregar un emoji personalizado | Emoji creado y visible en Firestore (`circles/{id}/customEmojis`) | 🔗 | ✅ | Test automatizado pasando 2026-03-20. Emoji creado directamente en Firestore (EmojiPicker nativo no testeable en integración). |
| 5.4 | Eliminar un emoji personalizado | Emoji eliminado de Firestore y desaparece del tab Estados | 🔗 | ✅ | Test automatizado pasando 2026-03-20. Fix: documento debe incluir `usageCount: 0` — Firestore excluye docs sin ese campo del `orderBy`. |
| 5.5 | Emoji personalizado aparece en el tab Estados de Settings | Tab Estados muestra el emoji recién creado con su label | 🔗 | ✅ | Test automatizado pasando 2026-03-20. Mismo fix que T5.4 (`usageCount: 0`). |
| 5.6 | Si el usuario cierra su sesión adrede, el Círculo, debería mostrar el emoji/estado que está off-line y que lo ha hecho manualmente (falta un emoji/estado?) | Se deja rastro en el Círculo de que el usuario ha cerrado su sesión | 👁 |  |
---

## Fase 6 — Funcionamiento UI/UX

| No. | Caso de prueba | Resultado esperado | Tipo | Estado | Observaciones |
|:---:|:---|:---|:---:|:---:|:---|
| 6.1 | Al girar el celular el modal de Emojis/Estados no cabe en la pantalla y ocurre un 'overflow' de la misma | Mantener la distribución de los elementos | 👁 | ✅ | Fix implementado (PR #67). Pendiente verificación en dispositivo físico en landscape y tablet. |
| 6.2 | En la pantalla que crea un Círculo nuevo, hay una demora en tener el foco el textbox donde se ingresa el nombre del mismo  | El foco debe de aparecer por default sobre el textbox de inmediato | 👁 | ✅ | Fix implementado (PR #66): `autofocus: true` en `create_circle_view.dart`. Pendiente verificación en dispositivo físico. |
| 6.3 | Cuando se cambia opción de Login a Registrar el foco no aparece en el primer textbox de cada una de ellas, sino que hay que colocarlo a mano  |Esto debiera ser automático | 👁 | ✅ | Fix implementado (PR #66): `FocusNode` + `addPostFrameCallback` en `auth_final_page.dart`. Pendiente verificación en dispositivo físico. |
| 6.4 | Las ventanas de aviso que aparecen desde los modales de los emojis/estados, al tocarse un emoji no preconfigurado, tienen diferente "look and feel". La ventana de aviso del modal desde la barra debería parecerse lo más posible a la fuente de la verdad (ventana modal lanzada desde la pantalla del Círculo)  | Estas ventanas debieran ser casi idénticas, no solo en contenido sino además en la apariencia | 👁 | 🟡 | Fix implementado (PR #65): fondo negro + botón verde menta (`#1CE4B3`) en ambos modales. Pendiente verificación en dispositivo físico con zona geográfica configurada. |
| 6.5 | La segunda tarjeta llamada "Unirse a un Círculo" que aprece debajo de la tarjeta "Crear un Círculo", luego de que el usuario se Registra demora unos segundos en aparecer | Ambas tarjetas deberían aaparecer casi simultáneamente | 👁 | ✅ |  |
---

## Grupo 1 — App en Primer Plano (Abierta / Minimizada)

> Tests reportados en sesión 2026-04-09. Escenario: usuario con Modo Silencio activo interactuando con ambos modales (Barra de Notificaciones y Pantalla del Círculo).
> Estado de resolución: bugs 1.2/1.3/1.5/1.6/1.7 en análisis. Causa raíz identificada — fix pendiente de VoBo.

### A: SIN "MODO SILENCIO"

| ID | Escenario | Pasos | Resultado Obtenido |  Estado | 
|:---|:---|:---|:---|:---|
| **G1.A1** | Tap en emoji "Reunión" en Modal del Círculo | Sin Modo Silencio activo: (A) tocar emoji para abrir modal de estados → (B) seleccionar "Reunión" | El emoji/estado que aparece en pantalla del Círculo es el mismo que apareció en el modal usado desde la pantalla Círculo | ✅ |
| **G1.A2** | Tap en emoji "Universidad" en Modal del Círculo | Sin Modo Silencio activo: (A) tocar emoji para abrir modal de estados → (B) seleccionar "Universidad" | El emoji/estado que aparece en pantalla del Círculo es el mismo que apareció en el modal usado desde la pamtalla Círculo | ✅ |
| **G1.A3** | Tap en emoji "Bien" en Modal del Círculo | Sin Modo Silencio activo: (A) tocar emoji para abrir modal de estados → (B) seleccionar "Bien" | El emoji/estado que aparece en pantalla del Círculo es el mismo que apareció en el modal usado desde la pamtalla Círculo | ✅ |
| **G1.A4** | Tap en emoji "SOS" en Modal del Círculo | Sin Modo Silencio activo: (A) tocar emoji para abrir modal de estados → (B) seleccionar "SOS" | El emoji/estado que aparece en pantalla del Círculo es el mismo que apareció en el modal usado desde la pamtalla Círculo. Aparece el aviso de permiso para uso del GPS. Una vez seteado el emoji SOS se puede: cambiar a otro dándole tap sobre el mismo ó ver la posición del usuario en el Google Maps | ✅ |
| **G1.A5** | Tap en cualquiera de los 16 emojis/estados | Sin Modo Silencio activo: tocar cualquier de los emojis/estados mostrados desde el modal del  Círculo. | Aparece el mismo emoji/estado correspondiente en la pantalla del Círculo | ✅ |


---

### B: CON "MODO SILENCIO" & App Cerrada

| ID | Escenario | Pasos | Resultado Obtenido | Resultado Esperado | Estado |
|:---|:---|:---|:---|:---|:---:|
| **G1.B1** | Primer Tap en "Modo Silencio" | Tap en botón "Modo Silencio" en pantalla del Círculo | Aparecen los avisos de: Permitir las Notificaciones y Optimizar uso de la batería (este último no se cierra a pesar de haberle dado "Permitir", por qué). La app se minimiza. Ícono "i" aparece en Barra de Notificaciones en ~8 segundos | App se minimiza e ícono "i" aparece en la Barra de Notificaciones. No se cierra la sesión del usuario | ✅ |
| **G1.B2** | Tap en emoji "Reunión" desde modal de la Barra de Notificaciones (BN) | Con Modo Silencio activo y app minimizada: (A) tocar notificación, abrir modal → (B) seleccionar "Reunión" | El emoji/estado que aparece en pantalla del Círculo coincide con "Reunión" | El emoji/estado coincide y se mantiene | ✅ |
| **G1.B4** | Segundo Tap en "Modo Silencio" | Con Modo Silencio activo y app minimizada → reabrir app → tap en botón "Modo Silencio" nuevamente | App se minimiza. Ícono "i" sigue en Barra de Notificaciones en ~8 segundos | App se minimiza e ícono aparece una vez (sin reiniciar el servicio si ya estaba activo) | ✅ |
| **G1.B5** | Actualizar un emoji/estado desde la BN  | Con Modo Silencio activo y app minimizada → actualizar el emoji/estado desde Barra de Notificaciones | El ícono "i" desaparece de la BN | El ícono "i" NO debe desaparecer mientras el Modo Silencio está activo | ❌ CRÍTICO |

---

## Grupo 2 — App Cerrada con Swipe

Es necesario que para que estas opciones funcionen, primero se deberá activar el "Modo Silencio" dentro de la app si luego se procede a cerrarla. La sesión deberá quedar activa (preservar datos y emoji/estado) los cuales deberán reflejarse al abrirse la app nuevamente. El estado toma el valor del último estado del usuario desde Firebase. Si es un usuario nuevo el estado/emoji "default" es "Bien"

### C: CON "MODO SILENCIO" 

| ID | Escenario | Pasos | Resultado Obtenido | Resultado Esperado | Estado |
|:---|:---|:---|:---|:---|:---:|
| **G2.C1** | Mantener la sesión activa al cerrar la app | (A) Darle tap al botón "Modo Silencio" → (B) Swipe para cerrar la app | La app se cierra y aparece luego la BN | La sesión del usuario se preserva en el dispositivo incluyendo sus datos y su emoji/estado | ❌ CRÍTICO |

---

## PRIMER TRAMO — Modo Silencio (App Abierta/Minimizada)

> **Estado**: ✅ COMPLETADO (PR #95 - 2026-04-11)
> 
> **Regla fundamental**: Mientras la app esté abierta/minimizada (proceso vivo), el ícono "i" de Modo Silencio **PERMANECE SIEMPRE** hasta logout.
> 
> **NO importa**: cuánto tiempo pase, cuántas veces se minimice/maximice, si se interactúa con modales (nativos o Flutter).
> 
> **ÚNICA excepción**: Logout (cierre de sesión) → desactiva correctamente.

### Casos Normales - Proceso Vivo

| # | Caso de Prueba | Resultado Esperado | Prioridad | Estado |
|:---:|:---|:---|:---:|:---:|
| **PT.1** | Activar Modo Silencio → minimizar | Ícono "i" aparece en Barra de Notificaciones | ✅ Alta | ✅ VALIDADO |
| **PT.2** | Toca notificación → selecciona emoji | Ícono "i" permanece visible | ✅ Alta | ✅ VALIDADO |
| **PT.3** | Minimiza/maximiza rápido (<3s) | Ícono "i" permanece visible | ✅ Alta | ✅ VALIDADO |
| **PT.4** | Minimiza/maximiza lento (>3s) | Ícono "i" permanece visible | ✅ Alta | ✅ VALIDADO |
| **PT.5** | Maximiza → modal Flutter → emoji | Ícono "i" permanece visible | ✅ Alta | ✅ VALIDADO |
| **PT.6** | Logout | Ícono "i" desaparece correctamente | ✅ Alta | ✅ VALIDADO |

### Casos Edge - Proceso Vivo

| # | Escenario Edge | Resultado Esperado | Prioridad | Estado |
|:---:|:---|:---|:---:|:---:|
| **PT.E1** | Notificación → SOS (hold 1s) → maximizar | Ícono "i" **PERMANECE** visible | ✅ Alta | ✅ VALIDADO |
| **PT.E2** | Modal Flutter → emoji → minimizar/maximizar | Ícono "i" **PERMANECE** visible | ✅ Alta | ✅ VALIDADO |
| **PT.E7** | Activar → minimizar → maximizar → activar nuevamente | Ícono "i" **PERMANECE** (sin duplicar) | ✅ Alta | ✅ VALIDADO |

### Implementación

**Archivos modificados**:
- `MainActivity.kt` (líneas 149-238): Eliminada lógica de desactivación en `onResume()` para proceso vivo
- `EmojiDialogActivity.kt` (líneas 85-127): Eliminado código de timestamps (ya no necesario)

**PRs relacionados**:
- PR #94: Timestamp-based detection (parcialmente revertido)
- PR #95: Corrección final - ícono permanece siempre (app abierta/minimizada)

**Logs de diagnóstico** (deben aparecer):
```
🌙 [SILENT] onResume con Modo Silencio activo — manteniéndolo activo
🔔 [SILENT] Modal abierto — Modo Silencio permanece activo
🔍 [SILENT] onDestroy — Modo Silencio permanece activo
```

**Logs incorrectos** (NO deben aparecer):
```
❌ Modo Silencio desactivado desde onResume()
❌ [SILENT-FIX] Apertura intencional detectada — desactivando
```

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