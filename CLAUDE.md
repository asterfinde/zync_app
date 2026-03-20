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

### Tests unitarios
- Framework: `flutter_test` (estándar)
- Para lógica de negocio en `services/`
- Para validaciones y transformaciones de datos en `models/`

### Tests de integración (flujos de usuario)
- Framework: `integration_test` (paquete oficial de Flutter)
- Para flujos completos: login, registro, navegación principal
- Los tests se ubican en `integration_test/` en la raíz del proyecto
- Nombrar archivos: `[flujo]_test.dart` (ej: `auth_flow_test.dart`)
- **Requisito:** Todo widget interactuable debe tener un `Key` asignado

### Flujos prioritarios a automatizar

> Leyenda de tipo: 🔬 Test unitario | 🔗 Test de integración | 👁 Solo manual (no automatizable)

#### Fase 1 — Registro y Login de Usuarios

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

#### Fase 2 — Círculos

| No. | Caso de prueba | Resultado esperado | Tipo | Estado | Observaciones |
|:---:|:---|:---|:---:|:---:|:---|
| 1 | Creación de un círculo | Círculo creado en Firestore, código de invitación generado | 🔗 | | |
| 2 | Eliminación de un círculo | Solo el **creador** puede eliminar el círculo. Los miembros solo pueden abandonarlo. Al eliminarse, todos los miembros quedan desvinculados y regresan a "Aún no estás en un círculo". | 🔗 | | |
| 3 | Intento de crear más de un círculo | **MVP: un círculo por usuario.** La app bloquea la creación de un segundo círculo. | 👁 | | Funcionalidad no implementada en MVP — excluido de automatización. |
| 4 | Generación del código de invitación | Código único generado y visible para compartir | 🔗 | | |
| 5 | Estado/emoji inicial al unirse a un círculo | Se muestra "Todo bien" como estado por defecto | 🔗 | | |
| 6 | Cambiar de estado/emoji | Estado actualizado en Firestore y visible para los miembros del círculo | 🔗 | | |

#### Fase 3 — Actualización de Emojis / Estados

| No. | Caso de prueba | Resultado esperado | Tipo | Estado | Observaciones |
|:---:|:---|:---|:---:|:---:|:---|
| 1 | Estado default al unirse a un círculo | Emoji "Todo bien" asignado automáticamente | 🔗 | | |
| 2 | Cambio de estado desde modal del círculo | Actualización sin demora, visible para todos los miembros | 🔗 | | |
| 10.1 | Sin zonas configuradas — cualquier estado elegido | Muestra: emoji · nickname · estado · dd/mm/aa hh:mm:ss | 🔗 | | |
| 20.1 | Con zonas activas — usuario entra a una zona | Estado actualizado automáticamente con emoji de la zona | 👁 | | |
| 20.2 | Con zonas activas — usuario sale de una zona | Estado cambia a "En camino" automáticamente | 👁 | | |
| 30.1 | Dentro de zona, usuario cambia estado manualmente a no-zona | Muestra: emoji · nickname · estado · tiempo · ⚡ Manual | 🔗 | | |
| 30.2 | Fuera de zona, usuario cambia estado manualmente | Muestra: emoji · nickname · estado · tiempo · ⚡ Manual · 📍 Ubicación desconocida | 🔗 | | |
| 30.3 | Intento de cambiar zona automática por otra zona | Comportamiento bloqueado, se mantiene el estado actual | 🔗 | | |

#### Fase 4 — Modo Silent

| No. | Caso de prueba | Resultado esperado | Tipo | Estado | Observaciones |
|:---:|:---|:---|:---:|:---:|:---|
| 4.1 | App minimizada | Ícono visible en barra superior del dispositivo | 👁 | | |
| 4.2 | Sin cierre de sesión, app minimizada | App permanece activa en modo silent con ícono visible | 👁 | | |
| 4.3 | Con cierre de sesión | Ícono desaparece de la barra superior *(comportamiento a confirmar)* | 👁 | | |
| 4.4 | Toque del ícono en barra superior | Abre ventana de selección de estados con mismo layout que Fase 3 caso 2 | 👁 | | |
| 4.5 | Selección de estado desde modo silent | Estado actualizado sin abrir la app | 👁 | | |

#### Fase 5 — Modo Configuración

| No. | Caso de prueba | Resultado esperado | Tipo | Estado | Observaciones |
|:---:|:---|:---|:---:|:---:|:---|
| — | Pendiente de definir | — | — | | |

#### Fase 6 — Funcionamiento UI/UX

| No. | Caso de prueba | Resultado esperado | Tipo | Estado | Observaciones |
|:---:|:---|:---|:---:|:---:|:---|
| — | Pendiente de definir | — | — | | |


### Protocolo de pruebas manuales en dispositivo físico

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

### Reglas generales
- No instalar frameworks de testing adicionales sin aprobación.
- No automatizar todo de golpe. Priorizar los flujos más tediosos de probar manualmente.
- Cada test debe ser independiente (no depender del resultado de otro test).

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

## 13. Nota Final

- Este archivo es un documento vivo. Se actualiza conforme el proyecto avanza.
- La IA debe tratarlo como su fuente de verdad y nunca contradecir lo que aquí se establece.
- Si algo de este archivo entra en conflicto con una "buena práctica", **este archivo prevalece**.
- Si la IA considera que una regla de este archivo es contraproducente para un caso específico, debe comunicarlo al desarrollador con su razonamiento, pero **no actuar hasta recibir autorización**.
