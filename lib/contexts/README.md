# Bounded Contexts — Reglas de Imports

## Estructura interna de cada contexto

```
contexts/<nombre>/
├── domain/               ← reglas puras, sin imports externos
├── application/
│   ├── ports/            ← interfaces (repositorios, servicios) consumidas por el contexto
│   └── use_cases/        ← lógica de aplicación
├── infrastructure/       ← adapters concretos (Firestore, native bridge, prefs)
└── presentation/         ← view models + widgets propios del contexto
```

## Reglas obligatorias por capa

| Capa | Puede importar | NO puede importar |
|------|----------------|-------------------|
| `domain/` | Solo `shared/` | Todo lo demás |
| `application/` | `domain/`, `shared/` | `infrastructure/`, `presentation/`, Flutter SDK |
| `infrastructure/` | `domain/`, `application/ports/`, `shared/`, paquetes externos | `presentation/` directamente |
| `presentation/` | `application/use_cases/`, `domain/`, `shared/`, Flutter SDK | `infrastructure/` directamente |

## Reglas entre contextos

- Un contexto **NO** importa la capa `domain/` de otro contexto directamente.
- La comunicación entre contextos se hace vía eventos de dominio o puertos expuestos en `application/`.
- `shared/` y `platform/` son los únicos módulos transversales — no contienen lógica de negocio.

## Convención de imports (Dart)

Usar siempre **package imports**, nunca relative imports fuera del propio archivo/directorio:

```dart
// ✅ Correcto
import 'package:nunakin_app/shared/result.dart';
import 'package:nunakin_app/contexts/presence/domain/presence_state.dart';
import 'package:nunakin_app/platform/persistence/kv_store.dart';

// ❌ Incorrecto
import '../../../shared/result.dart';
import '../../presence/domain/presence_state.dart';
```

## Enforcement

- `analysis_options.yaml` activa `always_use_package_imports` para detectar relative imports entre paquetes.
- La regla de capas (domain no importa infrastructure) se verifica en code review.
- Incorporación de `import_lint` evaluada a partir de Sem 2 cuando haya código real en los contextos.

## Contextos definidos

| Contexto | Responsabilidad |
|----------|-----------------|
| `identity` | Autenticación, sesión de usuario |
| `circle` | Membresía, solicitudes de unión, propiedad del círculo |
| `presence` | Estado del usuario, Modo Silencio, SOS, transiciones |
| `geofencing` | Zonas, eventos de entrada/salida, estado automático |
| `notifications` | Push, persistente, badge |
