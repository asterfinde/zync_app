# Structure — ZYNC

## Organización del proyecto

```
ZYNC/
  CLAUDE.md                        ← contrato del proyecto (raíz)
  TEST_PLAN.md                     ← plan de pruebas vivo
  .claude/
    ddd/
      ubiquitous-language.md       ← glosario oficial del dominio
      bounded-contexts.md          ← mapa de contextos y fronteras
    steering/
      product.md                   ← visión, propósito, restricciones de negocio
      tech.md                      ← stack, permisos, decisiones técnicas
      structure.md                 ← este archivo
    specs/
      {nombre-feature}/
        requirements.md            ← SBE (Gherkin) + EARS
        design.md                  ← arquitectura técnica + Mermaid
        tasks.md                   ← plan ejecutable trazado a Scenarios
  lib/
    core/
      cache/                       ← in_memory_cache, persistent_cache
      di/                          ← injection_container
      error/                       ← exceptions, failures
      models/                      ← user_status (StatusType)
      network/                     ← network_info
      services/                    ← servicios transversales (status, emoji, gps, etc.)
      splash/                      ← splash_screen
      usecases/                    ← usecase base
      utils/                       ← performance_tracker
      widgets/                     ← emoji_modal, status_widget, quick_actions_config
    features/
      auth/                        ← autenticación (auth_final_page.dart es el ÚNICO activo)
      circle/                      ← Circle Management (vistas y lógica de círculo)
      geofencing/                  ← Zones y ZoneEvents (dominio + servicios + UI)
      settings/                    ← Configuration (emoji management, settings page)
    notifications/                 ← notification_service, notification_actions
    providers/                     ← circle_provider (Riverpod)
    quick_actions/                 ← quick_actions_service, handler
    services/                      ← circle_service, auth_service (legacy)
    widgets/                       ← widgets globales (status_selector, sos, home_screen)
  integration_test/                ← tests de integración por flujo
  android/                         ← código nativo Android
  pubspec.yaml
```

## Convenciones de nomenclatura

| Elemento | Convención | Ejemplo |
|---|---|---|
| Archivos | snake_case | `circle_service.dart` |
| Clases | PascalCase | `CircleService` |
| Variables / funciones | camelCase | `sendStatus()` |
| Constantes | camelCase | `maxZonesPerCircle` |
| Pantallas | `[nombre]_screen.dart` | `home_screen.dart` |
| Servicios | `[nombre]_service.dart` | `status_service.dart` |
| Modelos | `[nombre]_model.dart` | `circle_model.dart` |
| Widgets | `[nombre]_widget.dart` | `status_widget.dart` |

## Reglas de estructura

- La estructura de `lib/` heredada del MVP **no se modifica** sin
  decisión explícita del desarrollador.
- Toda nueva feature sigue la estructura: `features/{nombre}/data + domain + presentation`
- No agregar capas adicionales de Clean Architecture sin decisión explícita.
- Widgets < 100 líneas: en el mismo archivo.
- Widgets > 100 líneas: extraer a archivo propio.
- No usar `print()` — usar `debugPrint()` o `log()`.
- Toda lectura/escritura a Firestore va en `services/`. Nunca en widgets directamente.

## Reglas de specs

- Cada spec vive en `.claude/specs/{nombre-feature}/`
- Los archivos de specs se versionan en Git junto al código
- El nombre de la carpeta usa kebab-case: `sos-activation`, `multi-circle`
- El Bounded Context de cada spec se declara en `requirements.md`
- Los términos usados en specs deben estar en `ddd/ubiquitous-language.md`

## Convenciones Git (Trunk-Based Development)

- Ramas de corta duración integradas rápidamente a `main`
- Formato de commit: `tipo(scope): descripción` en inglés
  - `feat(circle):` nueva feature en Circle Management
  - `fix(sos):` corrección en Safety/SOS
  - `docs(specs):` actualización de specs o ddd
  - `test(messaging):` tests en Messaging
- Un commit por task completada
- Flujo post-commit: PR → merge → borrar rama local y remota → pull desde main

## Archivos con estado especial

| Archivo | Estado |
|---|---|
| `lib/features/auth/presentation/pages/auth_final_page.dart` | ÚNICO archivo activo de auth |
| `lib/features/auth/presentation/pages/sign_in_page.dart` | Legacy — sin uso activo |
| `lib/features/auth/presentation/provider/auth_provider.dart` | Legacy — sin uso activo |
| `lib/services/auth_service.dart` | Legacy — sin uso activo |
| `lib/main_test.dart`, `lib/main_minimal_test.dart` | Dev — eliminar antes de release |
| `lib/dev_auth_simple/`, `lib/dev_auth_test/`, `lib/dev_test/`, `lib/dev_utils/` | Dev — eliminar antes de release ⚠️ |
