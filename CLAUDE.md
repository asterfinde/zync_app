# CLAUDE.md — Reglas de Proyecto

> Este archivo es el contrato entre el desarrollador y la IA.
> La IA debe leerlo al inicio de cada sesión y respetar cada regla sin excepción.

---

## 1. Información del Proyecto

- **Nombre:** Nunakin
- **Descripción:** Aplicación móvil que permite a un usuario enviar una imagen/emoji predefinido a un "círculo cercano" de confianza. Incluye función social simple y función crítica de SOS con ubicación GPS.
- **Tipo:** Aplicación móvil (Android primera etapa, luego iOS)
- **Etapa actual:** MVP — 90%
- **Stack:** Flutter + Firebase (Firestore, Auth, Storage, API Key Anthropic Claude Sonnet)
- **Versión de Flutter:** 3.38.2
- **Versión de Dart:** 3.10.0
- **Versión mínima de Android:** 21
- **Versión mínima de iOS:** No considerada aún
- **App ID:** com.datainfers.zync *(se mantiene por compatibilidad — no cambiar)*

---

## 2. Regla Principal — No Actuar Sin Autorización

**LA IA NO DEBE:**

- Modificar archivos que no estén directamente relacionados con lo que se le pidió.
- Refactorizar código existente "por buenas prácticas" sin autorización explícita.
- Cambiar nombres de clases, funciones o variables existentes salvo que se le pida.
- Agregar, actualizar o eliminar dependencias en `pubspec.yaml` sin aprobación previa.
- Cambiar la arquitectura o estructura de carpetas del proyecto.
- Asumir que un error en el código existente debe corregirse si no se le pidió.

**LA IA DEBE:**

- Si detecta código que podría mejorarse, INFORMAR al desarrollador y esperar instrucción.
- Si un cambio solicitado impacta otros archivos, LISTAR los archivos afectados ANTES de modificar.
- Si encuentra un bug o inconsistencia no relacionada con la tarea, REPORTARLO sin corregirlo.
- Confirmar el alcance exacto de cada cambio antes de ejecutarlo.
- **Antes de cualquier `git checkout` o cambio de rama:** listar explícitamente los archivos que podrían verse afectados y esperar confirmación — incluso en modo `SOLO`.
- Al cierre de sesión, proponer entradas para las secciones 11 y 12 si corresponde, y esperar aprobación.
- **Antes de proponer cualquier cambio en lógica de navegación, tap handlers o flujos de usuario:** listar TODOS los flujos que pasan por el mismo código y confirmar que ninguno regresiona. Si algún flujo existente se ve afectado, reportarlo ANTES de pedir VoBo.
- **Gateway de control — "Verifica antes de VoBo":** cuando el desarrollador dice "verifica", "revisa", "investiga", "analiza" o frases similares, presentar ÚNICAMENTE el diagnóstico y el plan propuesto. NO implementar nada hasta recibir "VoBo" explícito. Aplica incluso en modo `SOLO`.
- **En refactorizaciones incrementales con feature flag:** antes de migrar cualquier caller Dart a una interfaz nueva (ej. `NativeBridge.invoke()`), verificar que la implementación del otro lado (Kotlin/nativo) ya está activa. Si no lo está, el caller debe incluir el fallback al camino legacy en el mismo commit — nunca en un PR separado.
- **En el reporte de cierre de cada PR:** si algún flujo de usuario queda en estado de transición (un lado migrado, otro inactivo), incluir explícitamente la advertencia `⚠️ Riesgo activo: [descripción]. Verificar en dispositivo antes del próximo PR.` Si no se incluyó: el desarrollador debe asumir que ese flujo NO fue verificado.

### Protocolo de diagnóstico de bugs (obligatorio)

Aplicar en este orden en todos los bugs. No saltear pasos.

**Paso 1 — Leer REGLAS_NEGOCIO.md primero**
Si el bug involucra algo visible al usuario (bloqueo, validación, dimming, dialog "no permitido"):
- Leer `docs/dev/REGLAS_NEGOCIO.md`.
- Si el comportamiento está especificado como CORRECTO: el bug está en OTRO lado — **nunca eliminar la restricción**. Eliminar una restricción correcta basándose solo en el síntoma reportado es un error de diagnóstico, no un fix.
- Si no está especificado como correcto: continuar al Paso 2.

**Paso 2 — Trazar el call graph desde el tap/acción**
1. Identificar el handler del tap (grep el texto del botón o el key del widget).
2. Seguir cada llamada hacia abajo hasta el widget que SE RENDERIZA realmente. No asumir que una clase en el mismo archivo es la que ejecuta.
3. Verificar con grep que cada archivo tiene callers **activos** en el flujo real. Si no hay callers: es código muerto — reportarlo, no tocarlo.
4. Identificar la **clase activa** antes de continuar.

**Paso 3 — Leer los métodos críticos de la clase activa**
1. `initState()` completo.
2. Todos los métodos async de carga (`loadX`, `fetchX`, `syncX`).
3. Los `setState()` / `notifyListeners()` — qué los dispara.
Solo la clase que el call graph confirma. No clases "cercanas conceptualmente".

**Paso 4 — Identificar la fuente de verdad desincronizada**
Checar las 7 fuentes activas: Firestore `memberStatus`, `flutter.current_status_id`, `flutter.manual_status_id`, `flutter.pre_silent_status_id`, `flutter.is_silent_mode_active`, `NativeStateManager` (Room), static fields en memoria. Identificar cuál está desincronizada.

**Paso 5 — Verificar que el fix no rompe flujos existentes**
Listar TODOS los flujos que pasan por el mismo código. Confirmar que ninguno regresiona. Si algún flujo se ve afectado → reportarlo ANTES de pedir VoBo.

**Paso 6 — Proponer con nivel de confianza explícito**
Un plan PA95C (>95% confianza) debe tener: causa raíz identificada (no hipótesis), call graph trazado hasta la línea exacta, `REGLAS_NEGOCIO.md` consultado, archivos afectados con líneas específicas, flujos impactados verificados.

> Para bugs de lifecycle nativo Android: los logs diagnósticos son la única fuente de verdad — leerlos antes de cualquier otro paso.

### Modo autónomo vs. modo con autorización

| Prefijo | Significado | Comportamiento |
|---------|-------------|----------------|
| `SOLO` | Sin interrupciones | La IA ejecuta todos los pasos de forma autónoma: cambios, commit, PR, merge y limpieza de ramas. No pide autorización en ningún punto. |
| `AUTH` | Con autorización (default) | La IA muestra el alcance de cada cambio y espera aprobación antes de proceder. |

**Reglas:**
- El prefijo aplica únicamente a la instrucción que lo lleva.
- Si no hay prefijo, se asume `AUTH`.
- En modo `SOLO`, la IA reporta un resumen al final de todo lo ejecutado.

---

## 3. Estructura del Proyecto

```
lib/
|   firebase_options.dart
|   main.dart
|
+---core
|   |   global_keys.dart
|   |
|   +---cache
|   |       in_memory_cache.dart
|   |       persistent_cache.dart
|   |
|   +---di
|   |       injection_container.dart
|   |
|   +---error
|   |       exceptions.dart
|   |       failures.dart
|   |
|   +---models
|   |       user_status.dart
|   |
|   +---network
|   |       network_info.dart
|   |       network_info_impl.dart
|   |
|   +---services
|   |       app_badge_service.dart
|   |       emoji_cache_service.dart
|   |       emoji_management_service.dart
|   |       emoji_service.dart
|   |       gps_service.dart
|   |       initialization_service.dart
|   |       keep_alive_service.dart
|   |       native_state_bridge.dart
|   |       quick_actions_preferences_service.dart
|   |       session_cache_service.dart
|   |       silent_functionality_coordinator.dart
|   |       status_modal_service.dart
|   |       status_service.dart
|   |
|   +---splash
|   |       splash_screen.dart
|   |
|   +---usecases
|   |       usecase.dart
|   |
|   +---utils
|   |       performance_tracker.dart
|   |
|   \---widgets
|           emoji_modal.dart
|           quick_actions_config_widget.dart
|           status_widget.dart
|
+---features
|   +---auth
|   |   +---data
|   |   |   +---datasources
|   |   |   |       auth_local_data_source.dart
|   |   |   |       auth_local_data_source_impl.dart
|   |   |   |       auth_remote_data_source.dart
|   |   |   |       auth_remote_data_source_impl.dart
|   |   |   +---models
|   |   |   |       user_model.dart
|   |   |   \---repositories
|   |   |           auth_repository_impl.dart
|   |   +---domain
|   |   |   +---entities
|   |   |   |       user.dart
|   |   |   +---repositories
|   |   |   |       auth_repository.dart
|   |   |   \---usecases
|   |   |           get_current_user.dart
|   |   |           sign_in_or_register.dart
|   |   |           sign_out.dart
|   |   \---presentation
|   |       +---pages
|   |       |       auth_final_page.dart  ← ÚNICO archivo activo de auth
|   |       |       auth_wrapper.dart
|   |       +---provider
|   |       |       auth_state.dart
|   |       \---widgets
|   |               (legacy — ver sección 12)
|   |
|   +---circle
|   |   \---presentation
|   |       +---pages
|   |       |       home_page.dart
|   |       |       quick_status_selector_page.dart
|   |       \---widgets
|   |               create_circle_view.dart
|   |               in_circle_view.dart
|   |               in_circle_view_new.dart
|   |               join_circle_view.dart
|   |               no_circle_view.dart
|   |               quick_status_send_dialog.dart
|   |
|   +---geofencing
|   |   +---domain
|   |   |   \---entities
|   |   |           zone.dart
|   |   |           zone_event.dart
|   |   +---presentation
|   |   |   +---pages
|   |   |   |       zones_page.dart
|   |   |   \---widgets
|   |   |           geofencing_debug_widget.dart
|   |   |           zone_form.dart
|   |   \---services
|   |           geofencing_service.dart
|   |           zone_event_service.dart
|   |           zone_service.dart
|   |
|   \---settings
|       \---presentation
|           +---pages
|           |       emoji_management_page.dart
|           |       settings_page.dart
|           \---widgets
|                   create_emoji_dialog.dart
|                   delete_emoji_dialog.dart
|
+---notifications
|       notification_actions.dart
|       notification_service.dart
|
+---providers
|       circle_provider.dart
|
+---quick_actions
|       quick_actions_handler.dart
|       quick_actions_service.dart
|
+---services
|       auth_service.dart
|       circle_service.dart
|
+---test_helpers
|       performance_monitor.dart
|       test_cache.dart
|       test_page.dart
|
\---widgets
        home_screen_widget.dart
        notification_status_selector.dart
        sos_gps_test_widget.dart
        status_selector_overlay.dart
        widget_models.dart
        widget_service.dart
```

**Regla:** Esta estructura NO se cambia. No se agregan capas adicionales sin decisión explícita del desarrollador.

---

## 4. Comunicación con la IA

### Estilo de respuesta
Respuestas cortas y directas. Sin artículos innecesarios, sin cortesías, sin relleno.
El código habla por sí mismo.
Ejemplo: "Bug en línea 42. Falta Text widget. Propongo esto:" — no: "He analizado tu código y encontré que..."

> **Nota:** Este estilo aplica a las *respuestas* de la IA, no a los prompts del desarrollador.
> Los prompts pueden y deben ser tan detallados como la tarea lo requiera — la precisión del prompt evita iteraciones innecesarias y ahorra tokens.

### Idioma
Español neutro latinoamericano. Nunca usar modismos rioplatenses (ej: "andá", "hacés", "vos", "tenés"). Usar formas neutras: "ve", "haces", "tú/usted", "tienes".

---

## 5. Convenciones de Código

### Naming
- Archivos: `snake_case.dart`
- Clases: `PascalCase`
- Variables y funciones: `camelCase`
- Constantes: `camelCase` (Dart convention, no SCREAMING_CASE)
- Archivos de pantalla: `[nombre]_screen.dart`
- Archivos de servicio: `[nombre]_service.dart`
- Archivos de modelo: `[nombre]_model.dart`
- Archivos de widget: `[nombre]_widget.dart` o nombre descriptivo

### Estilo
- Preferir `const` constructors siempre que sea posible.
- Usar `final` por defecto para variables locales.
- Widgets pequeños: mantener en el mismo archivo.
- Widgets complejos (> 100 líneas): extraer a archivo propio.
- No usar `print()` — usar `debugPrint()` o `log()`.
- Manejar estados de carga y error en cada pantalla (no solo el happy path).

### State Management
- **⚠️ PENDIENTE DEFINIR** — completar antes de agregar nueva lógica de estado.
- No mezclar soluciones de state management.
- No migrar de una solución a otra sin decisión explícita del desarrollador.

---

## 6. Firebase — Reglas Específicas

- **Firestore:** Toda lectura/escritura va dentro de `services/`. Nunca en widgets directamente.
- **Auth:** Usar el servicio centralizado `shared/services/auth_service.dart`.
- **Security Rules:** No asumir que las reglas están configuradas. Preguntar antes de crear colecciones nuevas.
- **Colecciones existentes:** `circles`, `users`, `predefinedEmojis`

```js
rules_version = '2';

service cloud.firestore {
  match /databases/{database}/documents {
    match /predefinedEmojis/{emojiId} {
      allow read: if request.auth != null;
      allow write: if false;
    }
    match /users/{userId} {
      allow write: if request.auth != null && request.auth.uid == userId;
      allow read: if request.auth != null && (
        request.auth.uid == userId ||
        (
          exists(/databases/$(database)/documents/users/$(request.auth.uid)) &&
          get(/databases/$(database)/documents/users/$(request.auth.uid)).data.circleId != null &&
          get(/databases/$(database)/documents/users/$(request.auth.uid)).data.circleId == resource.data.circleId
        )
      );
    }
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    match /circles/{circleId} {
      allow read, write: if request.auth != null;
    }
    match /circles/{circleId}/{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

- No crear colecciones o subcollections nuevas sin aprobación.

---

## 7. Dependencias — Regla Estricta

Antes de sugerir o instalar cualquier paquete:

1. Informar nombre exacto y versión propuesta.
2. Confirmar compatibilidad con Flutter 3.38.2.
3. Verificar que no genera conflictos con `pubspec.yaml` existente.
4. Esperar aprobación explícita.

**Si hay conflicto de versiones:**
- NO intentar resolverlo con overrides.
- Informar el conflicto exacto y proponer alternativas.
- Si tras dos intentos el problema persiste, DETENERSE y registrar en sección 12.

---

## 8. Testing

### Frameworks
- **Unitarios:** `flutter_test` (estándar)
- **Integración:** `integration_test` → ubicar en `integration_test/` en raíz
- Nombrar archivos: `[flujo]_test.dart`

### Reglas
- Todo widget interactuable debe tener un `Key` asignado antes de escribir el test.
- No instalar frameworks adicionales sin aprobación.
- Cada test debe ser independiente.
- Ver [`TEST_PLAN.md`](TEST_PLAN.md) para casos por fase y protocolo de pruebas.

---

## 9. Git — Reglas de Commit

Metodología: Trunk-Based Development (ramas de corta duración).

- **Nunca commitear directamente en `main`.**
- Crear rama antes de cualquier operación git.
  - Nomenclatura: `feat/`, `fix/`, `docs/`, `test/`, `refactor/`
  - Ejemplo: `git checkout -b fix/ms2-status-text`
- **Antes de commitear:** listar TODOS los archivos modificados con razón de cada cambio.
- **Si aparece archivo inesperado:** no commitear, investigar primero.
- **Formato de mensaje:** `tipo: descripción breve` en inglés.
- **Un commit por tarea.** No mezclar features o fixes.
- **Post-commit:** PR → merge → borrar rama local y remota → pull en main.

---

## 10. Lo Que la IA No Decide

Decisiones EXCLUSIVAS del desarrollador:
- Arquitectura, paquetes/dependencias, estructura de base de datos
- Estrategia de autenticación, flujo de navegación
- Diseño UI/UX (la IA implementa, no diseña salvo que se pida)
- Priorización de features, cuándo algo "está listo"

---

## 11. Protocolo de Sesión de Trabajo

### Al Inicio
1. Leer automáticamente el archivo de memoria más reciente en:
   `C:\Users\dante\.claude\projects\c--Users-dante-projects-zync-app\memory\`
   El archivo sigue el patrón `project_session_YYYYMMDD.md` — leer el de fecha más reciente.
2. Confirmar al desarrollador qué memoria se cargó y cuál es el estado actual.
3. Leer este archivo completo, incluyendo secciones 12 y 13.
3b. Verificar que las secciones "Estructura del Proyecto" y "Decisiones Técnicas" embebidas en
    `.claude/agents/analyst.md` y `.claude/agents/prompt-engineer.md` coincidan con las
    secciones 3 y 12 de este archivo. Si hay diferencias: actualizarlas antes de continuar
    y reportar al desarrollador qué cambió.
4. Revisar si hay ítems en [`docs/dev/DEUDA_TECNICA.md`](docs/dev/DEUDA_TECNICA.md) relacionados con la tarea y mencionarlos si es relevante.
5. El desarrollador indica qué va a trabajar.
6. La IA confirma que entiende el alcance.

### Durante
1. Pedidos pequeños y verificables.
2. Mostrar diff antes de aplicar.
3. Verificar que funciona antes de continuar.

### Al Cierre

**OBLIGATORIO — presentar este formato:**

```markdown
## 📊 RESUMEN EJECUTIVO

### Tareas Realizadas
- [✅ lista de tareas completadas]

### Archivos Modificados
- `ruta/archivo.ext` (líneas X-Y): descripción breve

### Estadísticas
| Métrica | Valor |
|---------|-------|
| Archivos modificados | N |
| Líneas agregadas | +X |
| Líneas eliminadas | -Y |

---

## ✅ CONFIRMACIÓN FINAL

### Estado del Repositorio
- ✅ Branch `[nombre]` limpio
- ✅ PR #[número] mergeado (si aplica)
- ✅ Último commit: `[hash]` — descripción

### Memoria Guardada
- ✅ Archivo: `MEMORY[id]`
- ✅ Ubicación: `C:\Users\dante\.claude\projects\c--Users-dante-projects-nunakin-app\memory\`

### Próximos Pasos
- [lista concreta]
```

### Formato de comentarios en código (fixes)

```dart
// ════════════════════════════════════════════════════════════
// [FIX] Descripción breve
// Fecha: YYYY-MM-DD
// PROBLEMA: descripción del bug
// SOLUCIÓN: explicación del cambio
// ════════════════════════════════════════════════════════════
```

### Gestión de contexto

- Al recibir resumen comprimido por el sistema: guardar estado en `memory/` antes de continuar.
- Antes de cambiar a feature no relacionado: guardar memoria y sugerir `/clear`.
- Si el desarrollador dice "nueva tarea": guardar memoria → sugerir `/clear`.
- **Antes de `/clear`:** guardar memoria primero y confirmar al desarrollador antes de proceder.

---

## 12. Decisiones Técnicas (Bitácora)

> El desarrollador toma la decisión. La IA la registra solo cuando se indica al cierre de sesión. La IA nunca agrega entradas por su cuenta.

| Fecha | Decisión | Razón |
|-------|----------|-------|
| — | Se descartó Clean Architecture | Sobreingeniería para MVP. Se adoptó estructura por features. |
| — | Se descartó Patrol para testing | Incompatibilidad de versiones con Flutter actual. Se usa `flutter_test` estándar. |
| 2026-03-16 | `auth_final_page.dart` es el ÚNICO archivo activo de auth | Maneja login, registro, recuperación y navegación post-auth. `sign_in_page.dart` y `auth_form.dart` son legacy sin uso. Trabajar SOLO en `auth_final_page.dart` para cualquier tarea de auth. |
| 2026-03-17 | Solo el creador del círculo puede eliminarlo | Miembros solo pueden abandonarlo. Evita círculos zombie en Firestore. |
| 2026-03-17 | MVP: un único círculo por usuario | Múltiples círculos generan fricción. La agencia del adolescente se expresa en qué comparte y cuándo. Múltiples círculos evaluados para v2.0. |
| 2026-03-27 | Sin opción de salir del círculo sin eliminar cuenta | Usuarios sin círculo son ruido. La única salida es eliminar la cuenta. `btn_leave_circle` y su lógica eliminados de `settings_page.dart`. |

---

## 13. Deuda Técnica

> Archivo externo: [`docs/dev/DEUDA_TECNICA.md`](docs/dev/DEUDA_TECNICA.md)
>
> La tabla completa vive allí para no engordar este archivo. Al inicio de cada sesión, si la tarea está relacionada con un ítem de deuda, leer ese archivo y mencionarlo al desarrollador.

---

## 14. Sistema de Memoria Persistente

### Ubicación

```
C:\Users\dante\.claude\projects\c--Users-dante-projects-nunakin-app\memory\
```

El índice vive en `MEMORY.md`. Se carga automáticamente al inicio de cada sesión.

### Tipos de memoria

| Tipo | Qué guarda |
|------|------------|
| `user` | Rol, preferencias, nivel técnico del desarrollador |
| `feedback` | Correcciones de comportamiento ("no hagas X", "en vez de X haz Y") |
| `project` | Estado de tareas, decisiones pendientes, próximo paso |
| `reference` | Dónde vive información externa al repo |

### Estructura de cada archivo

```markdown
---
name: nombre descriptivo
description: una línea
type: user | feedback | project | reference
---

Contenido. Para feedback y project, incluir siempre:
**Why:** razón
**How to apply:** cuándo y cómo
```

### Qué NO guardar

- Código, arquitectura o estructura de archivos (se lee del repo)
- Historial de git (usar `git log`)
- Soluciones a bugs (el fix está en el código)
- Nada que ya esté en este CLAUDE.md

### Protocolo de cierre (obligatorio)

Proponer entrada de tipo `project` con:
1. Feature activo — qué se estaba trabajando
2. Archivos modificados — con estado (commiteados o pendientes)
3. Próximo paso — acción concreta para retomar
4. Decisiones técnicas no registradas aún en sección 12

El desarrollador aprueba o ajusta antes de guardar.

---

## 15. Seguridad

> La IA no modifica configuraciones de seguridad sin aprobación. Si detecta un riesgo nuevo, lo reporta aquí.

### Cubierto

| Capa | Mecanismo | Notas |
|------|-----------|-------|
| Autenticación | Firebase Auth | Email/password + re-auth para operaciones críticas |
| Autorización | Firestore Security Rules | Acceso por rol: owner vs member, mismo círculo |
| Datos en tránsito | HTTPS/TLS | Todas las comunicaciones Firebase van cifradas |
| Datos en reposo | Firebase encryption | Gestionado por Google |
| Signing key Android | `android/key.properties` | Excluido del repo ✅ |
| Service account | `scripts/serviceAccountKey.json` | Excluido del repo ✅ |

### Pendientes pre-lanzamiento (obligatorios)

| Ítem | Riesgo | Acción requerida |
|------|--------|-----------------|
| Política de privacidad | Alto | Google Play la exige. Cubrir: email, nickname, GPS — uso, retención, eliminación. |
| Justificación `ACCESS_BACKGROUND_LOCATION` | Alto | Google Play exige declaración explícita. Justificación: geofencing para estado automático. |
| API Key de Anthropic | Alto | Verificar ubicación. Si está en el cliente → Cloud Function o Remote Config restringido. |
| Firebase API Key en `firebase_options.dart` | Bajo | Es identificador público, no un secret. Verificar que Security Rules estén correctas en producción. |
| Validación server-side de inputs | Medio | Agregar en Cloud Functions o Firestore Rules para campos críticos. |
| Logs con datos de usuario | Medio | Auditar `debugPrint()` / `log()` que expongan UIDs, emails o coordenadas. Condicionar con `kDebugMode`. |

### Pendientes post-MVP

| Ítem | Descripción |
|------|-------------|
| Auditoría de dependencias | `flutter pub audit` para CVEs conocidos |
| Rate limiting | Limitar operaciones críticas (crear Circle, SOS, JoinRequest) |
| Penetration testing | Revisión formal antes de escalar usuarios |
| Certificate pinning | Protección MITM — evaluar para v2.0 |
| Ofuscación del APK | ProGuard/R8 — relevante si la app escala |
| Retención de datos GPS | Definir política: cuánto tiempo se guardan ZoneEvents y coordenadas SOS |

### Reglas para la IA

- **Nunca** sugerir almacenar secrets en código fuente o assets.
- **Nunca** modificar Firestore Security Rules sin aprobación.
- **Siempre** condicionar logs con datos sensibles a `kDebugMode`.
- Si se detecta una key expuesta: reportarlo de inmediato como bloqueante.

---

## 16. Nota Final

- Este archivo es un documento vivo. Se actualiza conforme el proyecto avanza.
- La IA debe tratarlo como su fuente de verdad y nunca contradecirlo.
- Si algo aquí entra en conflicto con una "buena práctica", **este archivo prevalece**.
- Si la IA considera que una regla es contraproducente para un caso específico, debe comunicarlo con razonamiento — pero **no actuar hasta recibir autorización**.
