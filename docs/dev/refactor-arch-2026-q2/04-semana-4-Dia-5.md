# Semana 4, Día 5 — Migración `features/auth/` → `contexts/identity/` + smoke test + tag

**Fecha:** 2026-05-20
**Rama propuesta:** `refactor/sem4-auth-migration`
**Modelo:** Opus 4.7

---

## Objetivo

Consolidar el bounded context `identity/` absorbiendo todo el código activo de
`lib/features/auth/`. `auth_final_page.dart` es el único archivo activo de auth
(CLAUDE.md §12) — se mueve tal cual, sin tocar lógica (incluye su uso vigente
de `SecureCredentialService`). Cerrar la semana con smoke test 6 pasos en
dispositivo físico y crear tag `refactor-sem4-done`.

---

## Análisis previo — call graph completo

### Archivos en `lib/features/auth/` y su estado de uso

| Archivo | Callers activos (fuera de `features/auth/`) | Estado |
|---------|---------------------------------------------|--------|
| `presentation/pages/auth_final_page.dart` | `lib/main.dart` (vía AuthWrapper), `settings_page.dart` (3 navs), `no_circle_view.dart` (3 navs), `pending_request_view.dart` (1 nav), `integration_test/auth_flow_test.dart` | **ACTIVO** — mover |
| `presentation/pages/auth_wrapper.dart` | `lib/main.dart:10,339` | **ACTIVO** — mover |
| `presentation/pages/sign_in_page.dart` | Ninguno (solo declarado, no instanciado) | **LEGACY** — eliminar |
| `presentation/widgets/auth_form.dart` | Solo `sign_in_page.dart` (legacy) | **LEGACY** — eliminar |
| `presentation/provider/auth_provider.dart` | `in_circle_view.dart:13`, `no_circle_view.dart:4`, `settings_page.dart:5`, `sign_in_page.dart:9` (legacy) | **ACTIVO** — mover |
| `presentation/provider/auth_state.dart` | `in_circle_view.dart:14`, `no_circle_view.dart:5`, `settings_page.dart:6`, `sign_in_page.dart:10` (legacy), `auth_provider.dart` | **ACTIVO** — mover (con rename para evitar colisión) |
| `domain/entities/user.dart` | `lib/services/auth_service.dart:7` (alias `as app`), data layer, presentation layer | **ACTIVO** — mover |
| `domain/repositories/auth_repository.dart` | `identity_module.dart`, `auth_repository_impl.dart`, use cases | **ACTIVO** — mover |
| `domain/usecases/get_current_user.dart` | `identity_module.dart` | **ACTIVO** — mover (registrado en DI aunque no haya consumer activo) |
| `domain/usecases/sign_in_or_register.dart` | `identity_module.dart`, `scripts/seed.dart` | **ACTIVO** — mover |
| `domain/usecases/sign_out.dart` | `identity_module.dart`, `scripts/seed.dart` | **ACTIVO** — mover |
| `data/repositories/auth_repository_impl.dart` | `identity_module.dart` | **ACTIVO** — mover |
| `data/datasources/auth_remote_data_source.dart` + `_impl.dart` | `identity_module.dart`, `auth_repository_impl.dart` | **ACTIVO** — mover |
| `data/datasources/auth_local_data_source.dart` + `_impl.dart` | `identity_module.dart`, `auth_repository_impl.dart` | **ACTIVO** — mover |
| `data/models/user_model.dart` | `auth_local_data_source.dart`, `_impl.dart`, `auth_remote_data_source.dart`, `_impl.dart`, `auth_repository_impl.dart` | **ACTIVO** — mover |
| `domain/entities/.gitkeep` | — | **OBSOLETO** — eliminar (carpeta ya tiene contenido) |

### Callers externos a actualizar (resumen)

| Archivo caller | Imports a actualizar |
|----------------|----------------------|
| `lib/main.dart` | `auth_wrapper.dart` |
| `lib/services/auth_service.dart` | `domain/entities/user.dart` |
| `lib/features/settings/presentation/pages/settings_page.dart` | `auth_provider.dart`, `auth_state.dart`, `auth_final_page.dart` |
| `lib/features/circle/presentation/widgets/in_circle_view.dart` | `auth_provider.dart`, `auth_state.dart` |
| `lib/features/circle/presentation/widgets/no_circle_view.dart` | `auth_provider.dart`, `auth_state.dart`, `auth_final_page.dart` |
| `lib/features/circle/presentation/widgets/pending_request_view.dart` | `auth_final_page.dart` |
| `lib/app/di/modules/identity_module.dart` | 9 imports a `features/auth/` |
| `integration_test/auth_flow_test.dart` | `auth_final_page.dart` |
| `scripts/seed.dart` | `sign_in_or_register.dart`, `sign_out.dart` |

---

## Gaps identificados vs. PA doc original (`04-semana-4-identity-circle.md` §Día 5)

| Gap | Causa | Solución aplicada |
|-----|-------|------------------|
| PA original "borra `presentation/widgets/`" sin distinguir archivos | `auth_form.dart` es el único legacy ahí — verificado por grep | Eliminar `auth_form.dart` (solo consumido por legacy `sign_in_page.dart`) |
| PA original ignora `sign_in_page.dart` | No mencionado en plan; CLAUDE.md §12 ya lo lista como legacy junto a `auth_form.dart` | Eliminar (sin callers activos — verificado por grep) |
| PA original ignora `auth_provider.dart` + `auth_state.dart` con callers en 4 archivos | Plan asumía migración directa a `IdentityViewModel` Día 1 | Migrar en bloque a `contexts/identity/presentation/provider/` (mantener API existente). La consolidación con `IdentityViewModel` queda para Sem 5 cuando se refactorice `settings_page.dart` y vistas de círculo |
| Colisión de nombre: `Authenticated` existe en `features/auth/.../auth_state.dart` (con `User` field) y en `contexts/identity/domain/session_state.dart` (con `uid`/`email`) | Día 1 introdujo `SessionState` sin tocar el `AuthState` existente | El `Authenticated` clásico (con `user.nickname`) sigue siendo el que consumen `no_circle_view`, `in_circle_view`, `settings_page`. **No renombrar AuthState** en este día; coexisten en paquetes distintos (`contexts/identity/presentation/provider/auth_state.dart` vs `contexts/identity/domain/session_state.dart`). Riesgo bajo: ningún archivo los usa juntos. |
| `lib/services/auth_service.dart` importa `features/auth/domain/entities/user.dart` | El refactor de Sem 1 dejó `AuthService` fuera de `lib/services/` | Actualizar import a `contexts/identity/domain/entities/user.dart`. **No mover `auth_service.dart`** (queda para Sem 5 — fuera de scope) |
| `scripts/seed.dart` importa use cases de `features/auth/` y tiene cabecera incorrecta (`// test/seed_database_test.dart`) + import roto a `core/di/injection_container.dart` | Archivo legacy de scripting | Actualizar SOLO los imports de auth (no tocar el resto — fuera de scope, reportar como deuda) |
| `lib/features/auth/domain/entities/.gitkeep` | Marcador git de carpeta originalmente vacía | Eliminar (la carpeta tiene contenido y se va a borrar) |
| Carpeta destino `contexts/identity/presentation/pages/` no existe | Día 1 solo creó `view_models/` | Crear como parte del move (mkdir implícito) |
| Carpeta destino `contexts/identity/data/` no especificada en PA original — usa `infrastructure/` | Convención de bounded contexts establecida en Sem 2 | Mover `data/repositories/`, `data/datasources/`, `data/models/` → `contexts/identity/infrastructure/` (subcarpetas `repositories/`, `datasources/`, `models/`) |
| Carpeta `contexts/identity/domain/entities/` no existe | Día 1 sólo creó `session_state.dart` directo en `domain/` | Crear `contexts/identity/domain/entities/` para alojar `user.dart` |
| Carpeta `contexts/identity/domain/repositories/` y `domain/usecases/` no existen | Día 1 usó `application/ports/` para `IdentityRepository` | Mover `auth_repository.dart` → `domain/repositories/` y use cases → `domain/usecases/` (preserva estructura legacy hasta refactor Sem 5/6) |

---

## Archivos a crear (0)

Ninguno. Sólo se crean carpetas destino implícitamente al mover archivos.

---

## Archivos a mover (17 archivos + 1 .gitkeep a borrar)

### Páginas (presentation)

| Origen | Destino |
|--------|---------|
| `lib/features/auth/presentation/pages/auth_final_page.dart` | `lib/contexts/identity/presentation/pages/auth_final_page.dart` |
| `lib/features/auth/presentation/pages/auth_wrapper.dart` | `lib/contexts/identity/presentation/pages/auth_wrapper.dart` |

### Provider/State (presentation)

| Origen | Destino |
|--------|---------|
| `lib/features/auth/presentation/provider/auth_provider.dart` | `lib/contexts/identity/presentation/provider/auth_provider.dart` |
| `lib/features/auth/presentation/provider/auth_state.dart` | `lib/contexts/identity/presentation/provider/auth_state.dart` |

### Domain

| Origen | Destino |
|--------|---------|
| `lib/features/auth/domain/entities/user.dart` | `lib/contexts/identity/domain/entities/user.dart` |
| `lib/features/auth/domain/repositories/auth_repository.dart` | `lib/contexts/identity/domain/repositories/auth_repository.dart` |
| `lib/features/auth/domain/usecases/get_current_user.dart` | `lib/contexts/identity/domain/usecases/get_current_user.dart` |
| `lib/features/auth/domain/usecases/sign_in_or_register.dart` | `lib/contexts/identity/domain/usecases/sign_in_or_register.dart` |
| `lib/features/auth/domain/usecases/sign_out.dart` | `lib/contexts/identity/domain/usecases/sign_out.dart` |

### Data → Infrastructure

| Origen | Destino |
|--------|---------|
| `lib/features/auth/data/datasources/auth_local_data_source.dart` | `lib/contexts/identity/infrastructure/datasources/auth_local_data_source.dart` |
| `lib/features/auth/data/datasources/auth_local_data_source_impl.dart` | `lib/contexts/identity/infrastructure/datasources/auth_local_data_source_impl.dart` |
| `lib/features/auth/data/datasources/auth_remote_data_source.dart` | `lib/contexts/identity/infrastructure/datasources/auth_remote_data_source.dart` |
| `lib/features/auth/data/datasources/auth_remote_data_source_impl.dart` | `lib/contexts/identity/infrastructure/datasources/auth_remote_data_source_impl.dart` |
| `lib/features/auth/data/models/user_model.dart` | `lib/contexts/identity/infrastructure/models/user_model.dart` |
| `lib/features/auth/data/repositories/auth_repository_impl.dart` | `lib/contexts/identity/infrastructure/repositories/auth_repository_impl.dart` |

**Regla del move:** los archivos se mueven con su contenido EXACTO (preservar lógica, comentarios `[FIX]`, secciones legacy comentadas). Sólo se actualizan los `import` paths internos relativos que apunten a otros archivos movidos.

---

## Archivos a eliminar (3)

| Archivo | Razón |
|---------|-------|
| `lib/features/auth/presentation/pages/sign_in_page.dart` | Sin callers activos (verificado por grep — sólo auto-referencia y backups). Marcado legacy en CLAUDE.md §12. |
| `lib/features/auth/presentation/widgets/auth_form.dart` | Consumido únicamente por `sign_in_page.dart` (también eliminado). Marcado legacy en CLAUDE.md §12. |
| `lib/features/auth/domain/entities/.gitkeep` | Carpeta destino se elimina; marker obsoleto. |

**Tras el move:** la carpeta `lib/features/auth/` debe quedar vacía y se elimina recursivamente.

---

## Archivos a modificar (9 — sólo imports)

### Imports activos a actualizar

| Archivo | Cambio |
|---------|--------|
| `lib/main.dart` | `package:nunakin_app/features/auth/presentation/pages/auth_wrapper.dart` → `package:nunakin_app/contexts/identity/presentation/pages/auth_wrapper.dart` |
| `lib/services/auth_service.dart` | `'../features/auth/domain/entities/user.dart' as app` → `'../contexts/identity/domain/entities/user.dart' as app` |
| `lib/features/settings/presentation/pages/settings_page.dart` | Líneas 5–7: 3 imports a `features/auth/...` → `contexts/identity/...` (preservar líneas comentadas 1048-1050, 1687-1689 — no tocar, son código muerto sin riesgo) |
| `lib/features/circle/presentation/widgets/in_circle_view.dart` | Líneas 13–14: `auth_provider.dart` y `auth_state.dart` → `contexts/identity/presentation/provider/...` |
| `lib/features/circle/presentation/widgets/no_circle_view.dart` | Líneas 4–6: `auth_provider.dart`, `auth_state.dart`, `auth_final_page.dart` → rutas `contexts/identity/...` |
| `lib/features/circle/presentation/widgets/pending_request_view.dart` | Línea 5: `auth_final_page.dart` → `contexts/identity/presentation/pages/auth_final_page.dart` |
| `lib/app/di/modules/identity_module.dart` | 9 imports: data layer + domain layer + use cases → `contexts/identity/infrastructure/...` y `contexts/identity/domain/...` |
| `integration_test/auth_flow_test.dart` | Línea 26: `auth_final_page.dart` → `contexts/identity/presentation/pages/auth_final_page.dart` |
| `scripts/seed.dart` | Líneas 8–9: `sign_in_or_register.dart`, `sign_out.dart` → `contexts/identity/domain/usecases/...` (NO tocar import roto de `core/di/injection_container.dart` — fuera de scope, reportar como deuda) |

### Imports internos a actualizar (post-move, dentro de `contexts/identity/`)

| Archivo movido | Imports relativos a corregir |
|----------------|-----------------------------|
| `presentation/pages/auth_final_page.dart` | Ya usa `package:nunakin_app/...` absolutos — sin cambios |
| `presentation/pages/auth_wrapper.dart` | Ya usa absolutos `package:nunakin_app/...` — sin cambios |
| `presentation/provider/auth_provider.dart` | `'../../domain/entities/user.dart'` (a través de `auth_state.dart`) — verificar tras move |
| `presentation/provider/auth_state.dart` | `'../../domain/entities/user.dart'` → mantener (la profundidad relativa cambia de 2 a 3 niveles). **Nuevo:** `'../../domain/entities/user.dart'` (3 niveles desde `presentation/provider/`) |
| `domain/repositories/auth_repository.dart` | `'../../../../core/error/failures.dart'` → `'../../../../core/error/failures.dart'` (3 niveles arriba desde `contexts/identity/domain/repositories/` hasta `lib/` → `../../../core/error/failures.dart`). Verificar profundidad real |
| `domain/usecases/*.dart` | `'../../../../core/error/failures.dart'`, `'../../../../core/usecases/usecase.dart'`, `'../entities/user.dart'`, `'../repositories/auth_repository.dart'` — recalcular profundidad |
| `infrastructure/repositories/auth_repository_impl.dart` | `'../../../../core/error/exceptions.dart'`, `'../../../../core/error/failures.dart'`, `'../../../../core/network/network_info.dart'`, `'../../domain/entities/user.dart'`, `'../../domain/repositories/auth_repository.dart'`, `'../datasources/...'` — recalcular |
| `infrastructure/datasources/*.dart` | `'../../../../core/error/exceptions.dart'`, `'../models/user_model.dart'` — recalcular |
| `infrastructure/models/user_model.dart` | `'package:nunakin_app/features/auth/domain/entities/user.dart'` → `'package:nunakin_app/contexts/identity/domain/entities/user.dart'` |

**Regla:** Antes de cada Edit de import relativo, calcular la profundidad desde `lib/` hasta el archivo movido. Si la cuenta es ambigua, convertir a import absoluto `package:nunakin_app/...` para evitar errores.

---

## Pasos de implementación (orden estricto)

1. **Verificar tree limpio** (`git status` debe estar limpio antes de empezar).
2. **Crear rama** `refactor/sem4-auth-migration` desde `main`.
3. **Eliminar legacy primero** (`sign_in_page.dart`, `auth_form.dart`) — descarta posibilidades de imports rotos colaterales.
4. **Mover archivos** uno por uno usando `git mv` (preserva history) en este orden:
   - `domain/entities/user.dart` (es la base, lo importan muchos)
   - `domain/repositories/auth_repository.dart`
   - `domain/usecases/` (los 3)
   - `data/models/user_model.dart` → `infrastructure/models/`
   - `data/datasources/` (los 4) → `infrastructure/datasources/`
   - `data/repositories/auth_repository_impl.dart` → `infrastructure/repositories/`
   - `presentation/provider/auth_state.dart`
   - `presentation/provider/auth_provider.dart`
   - `presentation/pages/auth_final_page.dart`
   - `presentation/pages/auth_wrapper.dart`
5. **Actualizar imports relativos internos** dentro de los archivos movidos (de a un archivo por commit pequeño si conviene).
6. **Actualizar imports en los 9 callers externos** (lista de la sección anterior).
7. **Eliminar carpeta** `lib/features/auth/` recursivamente (debe estar vacía).
8. **Verificar `flutter analyze`** — 0 errores nuevos vs baseline Sem 4 Día 4.
9. **Verificar `flutter test`** — sin regresiones en `test/contexts/identity/`, `test/contexts/circle/`, `test/contexts/geofencing/`, `test/contexts/presence/`.
10. **Smoke test 6 pasos en dispositivo físico** (ver siguiente sección).
11. **Si smoke test PASS:** crear tag `refactor-sem4-done` + push.
12. **Guardar memoria** `project_refactor_sem4_done.md`.

---

## Smoke test 6 pasos (pre-tag, OBLIGATORIO en device físico)

1. Login con cuenta existente → llega a HomePage.
2. Estado del usuario carga correctamente en Círculo.
3. Cambio de estado manual → refleja en Círculo + Firestore.
4. Silent Mode ON → estado cambia; OFF → emoji previo restaurado.
5. Minimizar (5 min) → maximizar → estado no se resetea; token refresh corre sin error.
6. Logout → re-login → estado persiste.

**Si cualquier paso falla:** no crear tag. Investigar regresión por import roto o cambio inesperado de lógica en archivos movidos.

---

## Criterio de done

- [ ] `flutter analyze --no-fatal-infos` → 0 errores nuevos vs baseline Sem 4 Día 4
- [ ] `flutter test` → tests verdes en todos los contextos existentes (`identity`, `circle`, `geofencing`, `presence`)
- [ ] `lib/features/auth/` ELIMINADA por completo (carpeta vacía recursivamente)
- [ ] `git grep "features/auth"` en `lib/` retorna ÚNICAMENTE líneas comentadas (las de `settings_page.dart` 1048-1050/1687-1689 y `emoji_modal.dart` 330-331/493-494/`backups/` son ruido aceptable)
- [ ] `auth_final_page.dart` mantiene su lógica EXACTA (incluyendo uso de `SecureCredentialService`) — diff sólo en imports
- [ ] `auth_wrapper.dart` mantiene su lógica EXACTA (incluyendo `_refreshTokenWithRetry` indirecto y limpieza Point 21) — diff sólo en imports
- [ ] Smoke test 6 pasos PASS en device físico (Android)
- [ ] Tag `refactor-sem4-done` creado y pusheado
- [ ] Memoria `project_refactor_sem4_done.md` guardada

---

## Invariantes a preservar

- **`auth_final_page.dart` no cambia su lógica** — sólo su ubicación. Sigue importando `SecureCredentialService` desde `core/services/`, sigue usando `FirebaseAuth.instance` directamente, sigue navegando a `HomePage`.
- **`AuthWrapper` no cambia su lógica** — sigue siendo `StatefulWidget`, sigue suscribiéndose a `FirebaseAuth.instance.authStateChanges()` directamente (no a `IdentityRepository.session` — esa migración queda para Sem 5/6).
- **`authProvider` sigue siendo el `StateNotifierProvider<AuthNotifier, AuthState>`** que consumen `in_circle_view`, `no_circle_view`, `settings_page`. Su API pública (`ref.watch(authProvider)`, `ref.read(authProvider.notifier).signOut()`, estados `Authenticated`/`Unauthenticated`/`AuthLoading`/`AuthError`/`AuthInitial`) no cambia.
- **`AuthState` (sealed class con `Authenticated`/`Unauthenticated`/...) coexiste con `SessionState`** (`Authenticated`/`Anonymous` del context identity). No se renombran — viven en paquetes distintos (`presentation/provider/auth_state.dart` vs `domain/session_state.dart`). Riesgo de colisión: BAJO — ningún archivo los importa juntos.
- **`AuthService` (en `lib/services/auth_service.dart`) no se mueve** — su migración a `contexts/identity/` o consolidación con `IdentityRepository` se planifica en Sem 5/6. Sólo se actualiza el import de `User` entity.
- **`scripts/seed.dart` no se refactoriza más allá del cambio mínimo de imports auth.** Su import roto `core/di/injection_container.dart` y su cabecera incorrecta quedan como deuda técnica para reportar.
- **Identity DI (`identity_module.dart`) mantiene exactamente los mismos registros** — `GetCurrentUser`, `SignInOrRegister`, `SignOut`, `AuthRepository`, `AuthRemoteDataSource`, `AuthLocalDataSource`, `IdentityRepository`, `IdentityViewModel`. Sólo cambian los paths de import.
- **`backups/` no se toca** — sus referencias a `package:zync_app/features/auth/...` y `package:nunakin_app/features/auth/...` son históricos congelados.

---

## Riesgos identificados

| Riesgo | Probabilidad | Mitigación |
|--------|-------------|------------|
| Colisión `Authenticated` (AuthState vs SessionState) cause confusión futura | Baja (no se importan juntos) | Documentar en CLAUDE.md §12; renombrar en Sem 5 cuando se consolide ViewModel |
| Imports relativos rotos tras move (profundidad de `..` cambia) | Alta | Convertir a imports absolutos `package:nunakin_app/...` cuando sea ambiguo; correr `flutter analyze` después de CADA move |
| `git mv` falla en Windows por path con espacios o longitud | Baja | Usar PowerShell `Move-Item` como fallback; comprobar que git tracking persiste |
| `scripts/seed.dart` queda con import roto y rompe build de scripts | Baja (scripts no entran al build de la app) | Reportar como deuda; sólo cambiar los 2 imports de auth |
| Smoke test falla por regresión sutil en `AuthWrapper._initializeSilentFunctionalityIfNeeded()` por cambio de ubicación | Media | Diff EXACTO de `auth_wrapper.dart` antes y después debe ser sólo `// lib/features/...` → `// lib/contexts/identity/...` |
| `integration_test/auth_flow_test.dart` deja de compilar | Baja | Actualizar import en el mismo PR |

---

## Notas de scope (lo que NO se hace en Día 5)

- **No migrar `AuthNotifier` a `IdentityViewModel`** — la consolidación queda para Sem 5/6 cuando se refactorice `no_circle_view.dart`, `in_circle_view.dart` y `settings_page.dart`.
- **No mover `lib/services/auth_service.dart` a `contexts/identity/`** — fuera de scope. Sólo se actualiza un import.
- **No tocar `AuthWrapper` para que consuma `IdentityRepository`** — sigue usando `FirebaseAuth.instance.authStateChanges()` directo. Migración a port en Sem 5/6.
- **No borrar `lib/features/` completo** — `lib/features/circle/`, `lib/features/settings/`, `lib/features/geofencing/`, etc. siguen vigentes. Sólo `lib/features/auth/` se elimina.
- **No reformatear código** dentro de los archivos movidos — sólo update de imports.
- **No agregar tests nuevos** — los tests existentes en `test/contexts/identity/` (`session_state_test.dart`, `identity_view_model_test.dart`) deben seguir verdes; el resto se evalúa por smoke test en device.

---

## Reporte esperado de cierre

```
## RESUMEN EJECUTIVO

### Tareas Realizadas
- Movidos 17 archivos: features/auth/ → contexts/identity/
- Eliminados 3 legacy: sign_in_page.dart, auth_form.dart, .gitkeep
- Actualizados 9 callers externos (lib/main.dart, lib/services/auth_service.dart, 4 archivos de circle/settings, identity_module.dart, integration_test, scripts/seed.dart)
- flutter analyze: 0 errores nuevos
- flutter test: N tests verdes
- Smoke test device físico: 6/6 PASS
- Tag refactor-sem4-done creado

### Riesgo activo
[Si AuthWrapper se mueve sin probar en device físico antes del tag → riesgo
activo de regresión en login/logout. NO crear tag sin smoke test PASS.]
```
