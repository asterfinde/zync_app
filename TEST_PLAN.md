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
| 3 | Registro fallido — email ya registrado | Mensaje "Este correo ya tiene una cuenta registrada. Inicia sesión." | 🔗 | ⚠️ | Lógica correcta. Test falla por teclado virtual del test anterior que bloquea el tap en modo integración. Retomar si se resuelve el reset de teclado entre tests. |
| 4 | Login exitoso — credenciales válidas | Acceso a la app | 🔗 | ✅ | Lógica verificada 2026-03-20. Error post-test en infra (Firestore stream permission-denied al hacer signOut) — no afecta funcionalidad. |
| 5 | Login fallido — correo no encontrado | Mensaje "No encontramos una cuenta con ese correo." | 👁 | | Firebase email-enumeration-protection devuelve `invalid-credential` en vez de `user-not-found`. No automatizable sin cambiar config de Firebase. |
| 6 | Login fallido — contraseña incorrecta | Mensaje "La contraseña es incorrecta. Verifica e intenta de nuevo." | 🔗 | ⚠️ | Lógica correcta. Test falla porque `pumpAndSettle(10s)` descarta el SnackBar (duración 4s) antes del `expect`. Retomar ajustando timing. |
| 7 | Recuperación de contraseña — correo válido registrado | Email de recuperación enviado | 🔗 | ✅ | Test automatizado pasando 2026-03-20. |
| 8 | Cierre de sesión | Regreso a pantalla de login | 🔗 | ✅ | Lógica verificada 2026-03-20. Error post-test en infra (mismo Firestore stream que T04) — no afecta funcionalidad. |
| 9 | Eliminación de cuenta — usuario sin círculo | Cuenta eliminada de Auth y Firestore. Redirige al login. | 👁 | ✅ | Probado manualmente 2026-03-18. Acceso desde "Mi Cuenta" en NoCircleView. |
| 10 | Eliminación de cuenta — usuario con círculo (miembro o creador) | Usuario sale del círculo, cuenta eliminada de Auth y Firestore. Redirige al login. | 👁 | ✅ | Probado manualmente 2026-03-18. Acceso desde Settings → sección "Sesión". |
| 11 | Eliminación de cuenta — sesión no reciente (requires-recent-login) | App solicita contraseña, re-autentica y elimina. Si contraseña incorrecta: SnackBar rojo, cuenta intacta. | 👁 | | Flujo: login → cerrar app SIN cerrar sesión → esperar 5-10 min → reabrir → Eliminar Cuenta. |

---

## Fase 2 — Círculos

| No. | Caso de prueba | Resultado esperado | Tipo | Estado | Observaciones |
|:---:|:---|:---|:---:|:---:|:---|
| 1 | Creación de un círculo | Círculo creado en Firestore, código de invitación generado | 🔗 | ✅ | Test automatizado pasando 2026-03-20. |
| 2 | Eliminación de un círculo | Solo el **creador** puede eliminar el círculo. Los miembros solo pueden abandonarlo. Al eliminarse, todos los miembros quedan desvinculados y regresan a "Aún no estás en un círculo". | 🔗 | ✅ | Test automatizado pasando 2026-03-20. |
| 3 | Intento de crear más de un círculo | **MVP: un círculo por usuario.** La app bloquea la creación de un segundo círculo. | 👁 | | Funcionalidad no implementada en MVP — excluido de automatización. |
| 4 | Generación del código de invitación | Código único generado y visible para compartir | 🔗 | ✅ | Test automatizado pasando 2026-03-20. |
| 5 | Estado/emoji inicial al unirse a un círculo | Se muestra "Todo bien" como estado por defecto | 🔗 | ✅ | Test automatizado pasando 2026-03-20. |
| 6 | Cambiar de estado/emoji | Estado actualizado en Firestore y visible para los miembros del círculo | 🔗 | ✅ | Test automatizado pasando 2026-03-20. |

---

## Fase 3 — Actualización de Emojis / Estados

| No. | Caso de prueba | Resultado esperado | Tipo | Estado | Observaciones |
|:---:|:---|:---:|:---:|:---:|:---|
| 1 | Estado default al unirse a un círculo | Emoji "Todo bien" asignado automáticamente | 🔗 | | Cubierto también por Fase 2 T05 — evaluar si es redundante. |
| 2 | Cambio de estado desde modal del círculo | Actualización sin demora, visible para todos los miembros | 🔗 | | Cubierto también por Fase 2 T06 — evaluar si es redundante. |
| 10.1 | Sin zonas configuradas — cualquier estado elegido | Muestra: emoji · nickname · estado · timestamp relativo (ej: "Justo Ahora", "Hace X min") | 🔗 | | Implementación usa formato relativo, no `dd/mm/aa hh:mm:ss`. |
| 20.1 | Con zonas activas — usuario entra a una zona | Estado actualizado automáticamente con emoji de la zona | 👁 | | |
| 20.2 | Con zonas activas — usuario sale de una zona | Estado cambia a "En camino" automáticamente | 👁 | | |
| 30.1 | Dentro de zona, usuario cambia estado manualmente a no-zona | Muestra: emoji · nickname · estado · tiempo · ⚡ Manual | 🔗 | | Requiere Key en badge Manual. |
| 30.2 | Fuera de zona, usuario cambia estado manualmente | Muestra: emoji · nickname · estado · tiempo · ⚡ Manual · 📍 Ubicación desconocida | 🔗 | | Requiere Key en badge Manual y locationInfo. |
| 30.3 | Intento de cambiar zona automática por otra zona | Comportamiento bloqueado, se mantiene el estado actual | 🔗 | | |

---

## Fase 4 — Modo Silent

| No. | Caso de prueba | Resultado esperado | Tipo | Estado | Observaciones |
|:---:|:---|:---|:---:|:---:|:---|
| 4.1 | App minimizada | Ícono visible en barra superior del dispositivo | 👁 | | |
| 4.2 | Sin cierre de sesión, app minimizada | App permanece activa en modo silent con ícono visible | 👁 | | |
| 4.3 | Con cierre de sesión | Ícono desaparece de la barra superior *(comportamiento a confirmar)* | 👁 | | |
| 4.4 | Toque del ícono en barra superior | Abre ventana de selección de estados con mismo layout que Fase 3 caso 2 | 👁 | | |
| 4.5 | Selección de estado desde modo silent | Estado actualizado sin abrir la app | 👁 | | |

---

## Fase 5 — Modo Configuración

| No. | Caso de prueba | Resultado esperado | Tipo | Estado | Observaciones |
|:---:|:---|:---|:---:|:---:|:---|
| — | Pendiente de definir | — | — | | |

---

## Fase 6 — Funcionamiento UI/UX

| No. | Caso de prueba | Resultado esperado | Tipo | Estado | Observaciones |
|:---:|:---|:---|:---:|:---:|:---|
| — | Pendiente de definir | — | — | | |
