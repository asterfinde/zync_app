# CLAUDE.md — Reglas de Proyecto

> Este archivo es el contrato entre el desarrollador y la IA.
> La IA debe leerlo al inicio de cada sesión y respetar cada regla sin excepción.

---

## 1. Información del Proyecto

- **Nombre:** ZYNC
- **Descripción:** Crear una aplicación móvil para Android y iOS que permite a un usuario enviar una imagen/emoji predefinido a un "círculo cercano" de confianza. La aplicación. además, tiene una función social simple y una función crítica de SOS que adjunta la ubicación actual del usuario.
- **Tipo:** Aplicación móvil (Android en su primera etapa luego se expandirá hacia iOS)
- **Etapa actual:** MVP — 90%
- **Stack:** Flutter + Firebase (Firestore, Auth, Storage, API Key Anthropic Claude Sonnet)
- **Versión de Flutter:** 3.38.2
- **Versión de Dart:** 3.10.0
- **Versión mínima de Android:** 21
- **Versión mínima de iOS:** No considerada aún
- **App ID:** com.datainfers.zync

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
- Al cierre de sesión, proponer entradas para las secciones 11 y 12 si corresponde, y esperar aprobación.

---

## 3. Estructura del Proyecto

```
lib/
|   firebase_options.dart
|   generate-tree.bat
|   generate-tree.sh
|   main.dart
|   main_minimal_test.dart
|   main_test.dart
|   tree-~0,4-~4,2-~6,2.txt
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
|           emoji_modal_backup.dart
|           emoji_modal_backup_20250930_154539.dart
|           quick_actions_config_widget.dart
|           status_widget.dart
|           
+---dev_auth_simple
|       auth_simple_page.dart
|       
+---dev_auth_test
|       dev_auth_test_page.dart
|       
+---dev_test
|       mock_data.dart
|       test_members_page.dart
|       
+---dev_utils
|       clean_auth.dart
|       clean_firestore.dart
|       
+---features
|   +---auth
|   |   +---data
|   |   |   +---datasources
|   |   |   |       auth_local_data_source.dart
|   |   |   |       auth_local_data_source_impl.dart
|   |   |   |       auth_remote_data_source.dart
|   |   |   |       auth_remote_data_source_impl.dart
|   |   |   |       
|   |   |   +---models
|   |   |   |       user_model.dart
|   |   |   |       
|   |   |   \---repositories
|   |   |           auth_repository_impl.dart
|   |   |           
|   |   +---domain
|   |   |   +---entities
|   |   |   |       .gitkeep
|   |   |   |       user.dart
|   |   |   |       
|   |   |   +---repositories
|   |   |   |       auth_repository.dart
|   |   |   |       
|   |   |   \---usecases
|   |   |           get_current_user.dart
|   |   |           sign_in_or_register.dart
|   |   |           sign_out.dart
|   |   |           
|   |   \---presentation
|   |       +---pages
|   |       |       auth_final_page.dart
|   |       |       auth_wrapper.dart
|   |       |       sign_in_page.dart
|   |       |       
|   |       +---provider
|   |       |       auth_provider.dart
|   |       |       auth_state.dart
|   |       |       
|   |       \---widgets
|   |               auth_form.dart
|   |               
|   +---circle
|   |   +---domain_old
|   |   |   \---entities
|   |   |           user_status.dart
|   |   |           
|   |   \---presentation
|   |       +---pages
|   |       |       home_page.dart
|   |       |       home_page_backup.dart
|   |       |       quick_status_selector_page.dart
|   |       |       quick_status_selector_page_backup.dart
|   |       |       
|   |       \---widgets
|   |               create_circle_view.dart
|   |               in_circle_view.dart
|   |               in_circle_view_broken_backup.dart
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
|   |   |           
|   |   +---presentation
|   |   |   +---pages
|   |   |   |       zones_page.dart
|   |   |   |       
|   |   |   \---widgets
|   |   |           geofencing_debug_widget.dart
|   |   |           zone_form.dart
|   |   |           
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
|           |       
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

**Regla:** 

Dado el avance del proyecto, esta estructura NO se cambia. No se agregan capas adicionales
(domain, use_cases, repositories abstractos, etc.) salvo decisión explícita del desarrollador.

---

## 4. Convenciones de Código

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
- No usar `print()` para debugging — usar `debugPrint()` o `log()`.
- Manejar estados de carga y error en cada pantalla (no solo el happy path).

### State Management
- **Solución:** [especificar: Provider, Riverpod, Bloc, etc.]
- No mezclar soluciones de state management.
- No migrar de una solución a otra sin decisión explícita del desarrollador.

---

## 5. Firebase — Reglas Específicas

- **Firestore:** Toda lectura/escritura va dentro de `services/`. Nunca en widgets directamente.
- **Auth:** Usar el servicio centralizado `shared/services/auth_service.dart`.
- **Security Rules:** No asumir que las reglas de Firestore están configuradas. Preguntar antes de crear colecciones nuevas.
- **Colecciones existentes:** circles, users, predefinedEmojis

```js
rules_version = '2';

service cloud.firestore {
  match /databases/{database}/documents {
    // Emojis predefinidos: lectura pública para usuarios autenticados
    match /predefinedEmojis/{emojiId} {
      allow read: if request.auth != null;
      allow write: if false; // Solo admins via consola
    }
    
    // Reglas para usuarios: pueden leer y escribir sus propios datos
    // ADEMÁS: pueden leer el nickname de otros usuarios SI están en el mismo círculo
    match /users/{userId} {
      // Escribir: solo el propio usuario
      allow write: if request.auth != null && request.auth.uid == userId;
      
      // Leer: el propio usuario O miembros del mismo círculo (para nicknames)
      allow read: if request.auth != null && (
        // El propio usuario puede leer su documento completo
        request.auth.uid == userId ||
        // O si ambos usuarios están en el mismo círculo
        (
          exists(/databases/$(database)/documents/users/$(request.auth.uid)) &&
          get(/databases/$(database)/documents/users/$(request.auth.uid)).data.circleId != null &&
          get(/databases/$(database)/documents/users/$(request.auth.uid)).data.circleId == resource.data.circleId
        )
      );
    }
    
    // Permite acceso a sub-colecciones del usuario (para futuras funcionalidades)
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }

    // Permite leer y escribir en la colección circles para usuarios autenticados
    // Esto permite crear, leer, actualizar y eliminar círculos
    match /circles/{circleId} {
      allow read, write: if request.auth != null;
    }
    
    // Permite acceso a sub-colecciones de circles (como miembros, mensajes, etc.)
    match /circles/{circleId}/{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
  ```
- No crear colecciones o subcollections nuevas sin aprobación.

---

## 6. Dependencias — Regla Estricta

**Antes de sugerir o instalar cualquier paquete:**

1. Informar el nombre exacto del paquete y la versión propuesta.
2. Confirmar compatibilidad con la versión actual de Flutter del proyecto.
3. Verificar que no genera conflictos con dependencias existentes en `pubspec.yaml`.
4. Esperar aprobación explícita del desarrollador.

**Si hay conflicto de versiones:**

- NO intentar resolverlo con overrides o forzando versiones.
- Informar el conflicto exacto y proponer alternativas.
- Si no hay alternativa viable, decirlo claramente. No alentar a "seguir intentando".
- Si tras dos intentos el problema persiste, DETENERSE y registrar el problema en la sección 12 como deuda técnica.

**Paquetes prohibidos:**
- No definidos

---

## 7. Testing

### Frameworks
- **Unitarios:** `flutter_test` (estándar) — para lógica de negocio en `services/` y validaciones en `models/`
- **Integración:** `integration_test` (paquete oficial de Flutter) — para flujos completos de usuario
- Los tests de integración se ubican en `integration_test/` en la raíz del proyecto
- Nombrar archivos: `[flujo]_test.dart` (ej: `auth_flow_test.dart`)

### Reglas generales
- **Requisito:** Todo widget interactuable debe tener un `Key` asignado antes de escribir el test.
- No instalar frameworks de testing adicionales sin aprobación.
- No automatizar todo de golpe. Priorizar los flujos más tediosos de probar manualmente.
- Cada test debe ser independiente (no depender del resultado de otro test).

### Plan de pruebas y estado de fases

Ver [`TEST_PLAN.md`](TEST_PLAN.md) — contiene las tablas de casos por fase, estados, observaciones y el protocolo de pruebas en dispositivo físico.

---

## 8. Git — Reglas de Commit

Estoy trabajando la metodología Trunk-Based Software Development (TBSD), para tener ramas de corta duración que se integran rápidamente al "tronco" principal y único

- **Antes de commitear:** La IA debe listar TODOS los archivos modificados y explicar por qué se tocó cada uno.
- **Si aparece un archivo inesperado:** No commitear. Investigar primero.
- **Formato de mensaje:** `tipo: descripción breve`
  - `feat:` nueva funcionalidad
  - `fix:` corrección de bug
  - `refactor:` refactorización (solo si fue solicitada)
  - `style:` cambios de formato/estilo sin lógica
  - `docs:` documentación
  - `test:` agregar o modificar tests
- **Idioma de commits:** Inglés
- **Un commit por tarea.** De ahora en adelante es mejor no mezclar features o fixes en un solo commit. 
- **Luego del commit** Hacer el PR correspondiente, luego borrar las ramas trabajadas (local/remota) y hacer un Pull en el repo remoto para obtener la versión última de la app.

---

## 9. Lo Que la IA No Decide

Las siguientes decisiones son EXCLUSIVAS del desarrollador:

- Arquitectura del proyecto
- Elección de paquetes o dependencias
- Estructura de base de datos (colecciones, esquemas)
- Estrategia de autenticación
- Flujo de navegación de la app
- Diseño de UI/UX (la IA implementa, no diseña salvo que se pida)
- Priorización de features
- Cuándo algo "está listo"

---

## 10. Protocolo de Sesión de Trabajo

### Al Inicio
1. La IA lee este archivo completo, incluyendo las secciones 11 y 12.
2. La IA revisa si hay ítems en la sección 12 (Deuda Técnica) relacionados con la tarea de la sesión y los menciona si es relevante.
3. El desarrollador indica qué va a trabajar en esta sesión.
4. La IA confirma que entiende el alcance.

### Durante
1. Pedidos pequeños y verificables.
2. La IA muestra el diff antes de aplicar.
3. El desarrollador revisa y aprueba.
4. Se verifica que funciona antes de seguir.

### Al Cierre
1. La IA lista los cambios realizados en la sesión.
2. Si hay decisiones técnicas relevantes, la IA propone la entrada para la sección 11 y espera aprobación.
3. Si se detectaron problemas no resueltos, la IA propone la entrada para la sección 12 y espera aprobación.
4. Commit con mensaje descriptivo.

### Gestión de contexto

- Al recibir un resumen de sesión comprimida por el sistema: guardar estado en `memory/` antes de continuar.
- Antes de cambiar a un feature no relacionado con la tarea en curso: guardar memoria y sugerir `/clear` al desarrollador.
- Si el desarrollador dice "nueva tarea": guardar memoria → sugerir `/clear`.
- El contenido a guardar siempre incluye:
  - Rama activa y archivos modificados pendientes de commit
  - Estado exacto de la tarea (qué se hizo, qué falta)
  - Próximo paso concreto para retomar
  - Decisiones técnicas no registradas aún en sección 11
- La memoria persistente vive en `memory/` — no duplicar en este archivo.

---

## 11. Decisiones Técnicas (Bitácora)

> Registrar aquí las decisiones importantes tomadas durante el desarrollo.
> Formato: fecha — decisión — razón
>
> **Responsabilidad:** El desarrollador toma la decisión. La IA la registra aquí
> solo cuando el desarrollador lo indica explícitamente al cierre de sesión.
> La IA nunca agrega entradas por su cuenta.

| Fecha | Decisión | Razón |
|-------|----------|-------|
| [fecha] | Se descartó Clean Architecture | Sobreingeniería para el alcance del MVP. Se adoptó estructura por features. |
| [fecha] | Se descartó Patrol para testing | Incompatibilidad de versiones con Flutter [versión]. Se usa flutter_test estándar. |
| 2026-03-16 | `auth_final_page.dart` es el ÚNICO archivo activo de autenticación | Este archivo maneja login, registro, recuperación de contraseña y navegación post-auth de forma autónoma. `sign_in_page.dart` y `auth_form.dart` son legacy sin uso. La IA debe trabajar SOLO en `auth_final_page.dart` para cualquier tarea de auth. |
| 2026-03-17 | Solo el creador de un círculo puede eliminarlo | Los miembros solo pueden abandonarlo. Al eliminar, todos los miembros quedan desvinculados. Evita círculos "zombie" en Firestore y mantiene la jerarquía clara dentro del grupo. |
| 2026-03-17 | MVP: un único círculo por usuario | Múltiples círculos generan fricción (¿a cuál actualizo mi estado?). La agencia del adolescente se expresa en *qué comparte y cuándo*, no en cuántos círculos tiene. Múltiples círculos evaluados para v2.0. |

---

## 12. Problemas Conocidos / Deuda Técnica

> Registrar aquí problemas identificados que se resolverán después del MVP.
>
> **Responsabilidad:** La IA puede detectar y proponer ítems para esta lista,
> pero solo se agregan con aprobación del desarrollador, quien asigna la prioridad.
> La IA no corrige deuda técnica por iniciativa propia.

| Problema | Prioridad | Notas |
|----------|-----------|-------|
| Archivos legacy de auth sin uso: `sign_in_page.dart`, `auth_form.dart`, `auth_provider.dart`, `auth_service.dart` | Media | Contienen cambios que no afectan la app. El flujo activo usa `auth_final_page.dart` directamente. Evaluar eliminación post-MVP. |

---

## 13. Sistema de Memoria Persistente

> La memoria permite que la IA retenga contexto entre sesiones separadas.
> Sin ella, cada sesión comienza desde cero.

### Ubicación

```
C:\Users\dante\.claude\projects\c--Users-dante-projects-zync-app\memory\
```

El índice vive en `MEMORY.md` dentro de esa carpeta. Ese archivo se carga automáticamente al inicio de cada sesión — es lo primero que la IA lee para orientarse.

### Tipos de memoria

| Tipo | Qué guarda | Cuándo usarlo |
|------|------------|---------------|
| `user` | Rol, preferencias, nivel técnico del desarrollador | Al aprender algo sobre cómo trabaja el desarrollador |
| `feedback` | Correcciones y ajustes de comportamiento | Cuando el desarrollador dice "no hagas X" o "en vez de X haz Y" |
| `project` | Estado de tareas, decisiones pendientes, próximo paso | Al cerrar sesión o antes de un `/clear` |
| `reference` | Dónde vive información externa (Linear, Slack, Grafana, etc.) | Al aprender sobre recursos externos al repo |

### Estructura de cada archivo de memoria

```markdown
---
name: nombre descriptivo
description: una línea — se usa para decidir si es relevante en futuras sesiones
type: user | feedback | project | reference
---

Contenido. Para tipos feedback y project, incluir siempre:
**Why:** razón por la que se guarda
**How to apply:** cuándo y cómo aplicarlo
```

### Qué NO guardar en memoria

- Código, arquitectura o estructura de archivos (se lee del repo)
- Historial de git o cambios recientes (usar `git log`)
- Soluciones a bugs (el fix está en el código; el contexto en el commit)
- Nada que ya esté en este CLAUDE.md
- Estado efímero de la conversación actual

### Protocolo de cierre de sesión (obligatorio)

Al cerrar cada sesión, la IA **debe** proponer al desarrollador una entrada de memoria de tipo `project` con:

1. **Feature activo** — qué se estaba trabajando
2. **Archivos modificados** — con estado (commiteados o pendientes)
3. **Próximo paso** — acción concreta para retomar en la siguiente sesión
4. **Decisiones técnicas** — las que no están aún en la sección 11

El desarrollador aprueba o ajusta antes de que se guarde.

---

## 14. Nota Final

- Este archivo es un documento vivo. Se actualiza conforme el proyecto avanza.
- La IA debe tratarlo como su fuente de verdad y nunca contradecir lo que aquí se establece.
- Si algo de este archivo entra en conflicto con una "buena práctica", **este archivo prevalece**.
- Si la IA considera que una regla de este archivo es contraproducente para un caso específico, debe comunicarlo al desarrollador con su razonamiento, pero **no actuar hasta recibir autorización**.
