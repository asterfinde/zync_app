# Semana 1 — Cimientos

> **Período:** lunes 2026-05-11 a viernes 2026-05-15 (5 días hábiles)
> **Premisa:** NO tocar features. Todo es aditivo. `main` siempre verde.
> **Riesgo global:** Bajo.
> **Documento padre:** [00-plan-unificado.md](00-plan-unificado.md).

---

## 0. Objetivo

Establecer el esqueleto arquitectónico antes de migrar lógica de negocio:

- Carpetas de bounded contexts vacías pero presentes.
- Tipos transversales (`Result<T>`, `Failure`, `Contract`) en `shared/`.
- DI real reescrito con módulos.
- Persistencia abstraída (`KvStore`).
- Contrato compartido Dart↔Kotlin para SharedPreferences keys e IDs de estado.

**Al cierre de la semana, el comportamiento de la app es idéntico al pre-refactor.** El cambio es invisible al usuario. Lo que cambia es la base sobre la que se trabajará desde Semana 2.

---

## 1. Premisas y reglas de la semana

1. **Cero cambios funcionales.** Si una feature se comporta diferente, hay un bug en la migración.
2. **Cada PR pasa lint + analyzer + tests existentes.**
3. **Cada PR es revisado contra el tag `mvp-baseline-20260506`** para confirmar que el comportamiento de runtime es idéntico.
4. **No se borra código legado todavía.** Las clases existentes siguen funcionando. La nueva infraestructura coexiste.
5. **Si un cambio aditivo rompe algo, se revierte de inmediato y se replantea.**

---

## 2. Plan día por día

### Día 1 (lunes) — Estructura de carpetas + branch

**Rama:** `refactor/sem1-scaffold`

**Tareas:**

1. Crear estructura de carpetas vacías con `.gitkeep`:

```
lib/
├── contexts/
│   ├── identity/
│   │   ├── domain/.gitkeep
│   │   ├── application/{ports,use_cases}/.gitkeep
│   │   ├── infrastructure/.gitkeep
│   │   └── presentation/{widgets,view_models}/.gitkeep
│   ├── circle/         (misma estructura)
│   ├── presence/       (misma estructura)
│   ├── geofencing/     (misma estructura)
│   └── notifications/  (misma estructura)
├── platform/
│   ├── bridge/.gitkeep
│   └── persistence/.gitkeep
├── shared/
│   ├── .gitkeep
│   └── events/.gitkeep      ← placeholder para DomainEventBus (Sem 2)
└── app/.gitkeep
```

   Nota: `presentation/` se divide en `widgets/` (widgets atómicos del BC) y
   `view_models/` (lógica de presentación). Las pantallas completas que orquestan
   múltiples BCs van en `app/screens/` (Sem 5). Ver §2.2 de `00-plan-unificado.md`.

2. Documentar en `lib/contexts/README.md` las reglas de imports (ver §2 del plan unificado),
   incluyendo: regla de `platform/` solo desde `infrastructure/`, comunicación inter-BC vía
   `DomainEventBus`, y split de `presentation/`.

3. Configurar `analysis_options.yaml`:
   - Extender exclude a `scripts/**` (completo).
   - Documentar como TODO las reglas `always_use_package_imports`, `directives_ordering`
     (activar Sem 2) y `avoid_print` (activar Sem 6). No activarlas aún — surfacean
     ~585 violaciones pre-existentes que se limpian con la migración gradual.

**Entregable:** PR `refactor(scaffold): structure for bounded contexts`.

**Criterio de done:**
- `flutter analyze` verde.
- `flutter test` verde (suite existente sin tocar).
- Estructura visible en el árbol del repo.

---

### Día 2 (martes) — `Result<T>` y `Failure`

**Rama:** `refactor/sem1-result-failure`

**Tareas:**

1. Crear `lib/shared/result.dart`:

```dart
sealed class Result<T> {
  const Result();

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is FailureResult<T>;

  T? get valueOrNull => switch (this) {
        Success<T>(value: final v) => v,
        FailureResult<T>() => null,
      };

  Failure? get failureOrNull => switch (this) {
        Success<T>() => null,
        FailureResult<T>(failure: final f) => f,
      };

  R fold<R>(R Function(T) onSuccess, R Function(Failure) onFailure) =>
      switch (this) {
        Success<T>(value: final v) => onSuccess(v),
        FailureResult<T>(failure: final f) => onFailure(f),
      };
}

final class Success<T> extends Result<T> {
  final T value;
  const Success(this.value);
}

final class FailureResult<T> extends Result<T> {
  final Failure failure;
  const FailureResult(this.failure);
}
```

2. Crear `lib/shared/failure.dart`:

```dart
sealed class Failure {
  final String code;
  final String message;
  final Object? cause;
  final StackTrace? stackTrace;

  const Failure({
    required this.code,
    required this.message,
    this.cause,
    this.stackTrace,
  });
}

final class NetworkFailure extends Failure {
  const NetworkFailure({required super.message, super.cause, super.stackTrace})
      : super(code: 'network');
}

final class AuthFailure extends Failure {
  const AuthFailure({required super.message, super.cause, super.stackTrace})
      : super(code: 'auth');
}

final class ValidationFailure extends Failure {
  const ValidationFailure({required super.message, super.cause, super.stackTrace})
      : super(code: 'validation');
}

final class DomainFailure extends Failure {
  const DomainFailure({required super.message, super.cause, super.stackTrace})
      : super(code: 'domain');
}

final class PlatformFailure extends Failure {
  const PlatformFailure({required super.message, super.cause, super.stackTrace})
      : super(code: 'platform');
}

final class UnexpectedFailure extends Failure {
  const UnexpectedFailure({required super.message, super.cause, super.stackTrace})
      : super(code: 'unexpected');
}
```

3. Crear `lib/shared/unit.dart`:

```dart
class Unit {
  const Unit._();
  static const Unit instance = Unit._();
}
```

4. Tests unitarios `test/shared/result_test.dart` cubriendo:
   - `Success.fold` invoca `onSuccess`.
   - `FailureResult.fold` invoca `onFailure`.
   - Pattern matching exhaustivo.
   - `valueOrNull` y `failureOrNull` correctos.

**Entregable:** PR `refactor(shared): add Result<T> and Failure types`.

**Criterio de done:**
- Tests unitarios cubriendo Result y Failure (≥95% coverage del archivo).
- No se reemplaza ningún `try/catch` existente todavía — solo se publica el tipo.
- Documentación inline (dartdoc) en cada clase pública.

---

### Día 3 (miércoles) — DI con módulos por contexto + `Contract` (DbC)

**Rama:** `refactor/sem1-di-modules`

**Tareas:**

1. Reescribir `lib/core/di/injection_container.dart` (o moverlo a `lib/app/di/`) con módulos:

```dart
// lib/app/di/injection_container.dart
import 'package:get_it/get_it.dart';
import 'modules/external_module.dart';
import 'modules/identity_module.dart';
import 'modules/circle_module.dart';
import 'modules/presence_module.dart';
import 'modules/geofencing_module.dart';
import 'modules/notifications_module.dart';
import 'modules/platform_module.dart';

final sl = GetIt.instance;

Future<void> initDependencies() async {
  await registerExternalModule(sl);
  await registerPlatformModule(sl);
  await registerIdentityModule(sl);
  await registerCircleModule(sl);
  await registerPresenceModule(sl);
  await registerGeofencingModule(sl);
  await registerNotificationsModule(sl);
}
```

2. Crear `lib/app/di/modules/`:
   - `external_module.dart` — registra `FirebaseAuth.instance`, `FirebaseFirestore.instance`, `Connectivity`, `SharedPreferences`. (Idéntico a hoy, solo movido.)
   - `identity_module.dart` — registra lo de Auth que hoy está en `injection_container`.
   - `circle_module.dart`, `presence_module.dart`, `geofencing_module.dart`, `notifications_module.dart` — vacíos pero presentes (placeholder con un comentario `// TODO Sem N: registrar X`).
   - `platform_module.dart` — vacío (se llena en Sem 1 día 4-5).

3. Eliminar todo el código comentado masivo del `injection_container.dart` original. **Nota:** este código ya estaba muerto desde la decisión de marzo (sección 12 del CLAUDE.md). Su eliminación no afecta el comportamiento.

4. Crear `lib/shared/contract.dart`:

```dart
import 'package:flutter/foundation.dart';

class ContractViolation extends Error {
  final String kind; // 'precondition' | 'postcondition' | 'invariant'
  final String description;
  ContractViolation(this.kind, this.description);

  @override
  String toString() => 'ContractViolation [$kind]: $description';
}

abstract final class Contract {
  static void requires(bool condition, String description) {
    assert(() {
      if (!condition) {
        if (kDebugMode) {
          debugPrint('❌ [Contract.requires] $description');
        }
        throw ContractViolation('precondition', description);
      }
      return true;
    }());
  }

  static void ensures(bool condition, String description) {
    assert(() {
      if (!condition) {
        if (kDebugMode) {
          debugPrint('❌ [Contract.ensures] $description');
        }
        throw ContractViolation('postcondition', description);
      }
      return true;
    }());
  }

  static void invariant(bool condition, String description) {
    assert(() {
      if (!condition) {
        if (kDebugMode) {
          debugPrint('❌ [Contract.invariant] $description');
        }
        throw ContractViolation('invariant', description);
      }
      return true;
    }());
  }
}
```

   El uso de `assert(() { ... }())` garantiza que el bloque entero se elimina en builds de release (`assert` se compila como no-op).

5. Tests `test/shared/contract_test.dart`:
   - En modo debug, `requires(false, ...)` lanza `ContractViolation`.
   - `requires(true, ...)` no lanza.
   - Mismo patrón para `ensures` e `invariant`.

6. Migrar `main.dart` a usar `initDependencies()` en lugar del `di.init()` actual. Actualmente está comentado (línea 15 de `main.dart`); se rehabilita la llamada apuntando al nuevo entrypoint.

**Entregable:** PR `refactor(di): module-based dependency injection + Contract for DbC`.

**Criterio de done:**
- App arranca y funciona idéntico al baseline.
- Tests existentes verdes.
- Tests de `Contract` verdes (debug y release).
- `injection_container.dart` original (1.0) eliminado.

---

### Día 4 (jueves) — `KvStore` interfaz + impl SharedPreferences

**Rama:** `refactor/sem1-kvstore`

**Tareas:**

1. Crear `lib/platform/persistence/kv_store.dart`:

```dart
abstract class KvStore {
  Future<String?> getString(String key);
  Future<void> setString(String key, String value);
  Future<bool?> getBool(String key);
  Future<void> setBool(String key, bool value);
  Future<int?> getInt(String key);
  Future<void> setInt(String key, int value);
  Future<void> remove(String key);
  Future<bool> containsKey(String key);
}
```

2. Impl `lib/platform/persistence/shared_prefs_kv_store.dart`:

```dart
import 'package:shared_preferences/shared_preferences.dart';
import 'kv_store.dart';

class SharedPrefsKvStore implements KvStore {
  final SharedPreferences _prefs;
  SharedPrefsKvStore(this._prefs);

  @override
  Future<String?> getString(String key) async => _prefs.getString(key);

  @override
  Future<void> setString(String key, String value) async {
    await _prefs.setString(key, value);
  }

  // ... resto de métodos
}
```

3. Registrar `KvStore` en `platform_module.dart`:

```dart
Future<void> registerPlatformModule(GetIt sl) async {
  sl.registerLazySingleton<KvStore>(() => SharedPrefsKvStore(sl()));
}
```

4. Crear `lib/platform/persistence/storage_keys.dart` — **fuente única de verdad para todas las claves**:

```dart
abstract final class StorageKeys {
  // Presence
  static const currentStatusId = 'current_status_id';
  static const manualStatusId = 'manual_status_id';
  static const preSilentStatusId = 'pre_silent_status_id';
  static const isSilentModeActive = 'is_silent_mode_active';

  // Geofencing
  static const suppressNextGeofenceCheck = 'suppress_next_geofence_check';

  // Session
  static const sessionUserId = 'session_user_id';
  static const sessionEmail = 'session_email';

  // ... auditar archivo por archivo y consolidar todo

  StorageKeys._();
}
```

5. **Auditoría**: grep de `getString(`, `setString(`, `getBool(`, `setBool(` en `lib/` y catálogo de toda clave usada. Documentar en `docs/dev/refactor-arch-2026-q2/storage-keys-audit.md` (cada clave con archivo origen, escritor, lector). **No migrar lectores todavía.**

6. Tests `test/platform/persistence/shared_prefs_kv_store_test.dart` con `SharedPreferences.setMockInitialValues({})`.

**Entregable:** PR `refactor(platform): add KvStore abstraction + centralize storage keys`.

**Criterio de done:**
- `KvStore` registrado en DI.
- `StorageKeys` con todas las claves del proyecto.
- Doc de auditoría completo.
- Tests verdes.
- Comportamiento de la app idéntico al baseline.

---

### Día 5 (viernes) — Contrato compartido Dart↔Kotlin + cierre

**Rama:** `refactor/sem1-shared-contract`

**Tareas:**

1. Crear `lib/platform/persistence/native_keys.dart` — **claves leídas/escritas también desde Kotlin**:

```dart
/// Claves de SharedPreferences que cruzan la frontera Dart↔Kotlin.
///
/// IMPORTANTE: cualquier cambio aquí debe reflejarse en
/// android/app/src/main/kotlin/com/datainfers/zync/SharedKeys.kt
abstract final class NativeSharedKeys {
  static const flutterPrefix = 'flutter.';

  static const currentStatusId = 'current_status_id';
  static const manualStatusId = 'manual_status_id';
  static const preSilentStatusId = 'pre_silent_status_id';
  static const isSilentModeActive = 'is_silent_mode_active';
  static const suppressNextGeofenceCheck = 'suppress_next_geofence_check';

  /// Equivalente con prefijo Flutter (cómo SharedPreferences plugin las almacena).
  static String flutter(String key) => '$flutterPrefix$key';

  NativeSharedKeys._();
}
```

2. Crear `android/app/src/main/kotlin/com/datainfers/zync/SharedKeys.kt`:

```kotlin
package com.datainfers.zync

/**
 * Claves de SharedPreferences que cruzan la frontera Dart↔Kotlin.
 *
 * IMPORTANTE: cualquier cambio aquí debe reflejarse en
 * lib/platform/persistence/native_keys.dart
 *
 * Las claves escritas desde Flutter llevan prefijo "flutter.".
 */
object SharedKeys {
    private const val FLUTTER_PREFIX = "flutter."

    const val CURRENT_STATUS_ID = "current_status_id"
    const val MANUAL_STATUS_ID = "manual_status_id"
    const val PRE_SILENT_STATUS_ID = "pre_silent_status_id"
    const val IS_SILENT_MODE_ACTIVE = "is_silent_mode_active"
    const val SUPPRESS_NEXT_GEOFENCE_CHECK = "suppress_next_geofence_check"

    fun flutter(key: String): String = "$FLUTTER_PREFIX$key"
}
```

3. Crear `lib/contexts/presence/domain/value_objects/status_id.dart` — IDs canónicos:

```dart
abstract final class StatusIds {
  static const fine = 'fine';
  static const home = 'home';
  static const school = 'school';
  static const work = 'work';
  static const university = 'university';
  static const sos = 'sos';
  static const doNotDisturb = 'do_not_disturb';
  static const publicTransport = 'public_transport';

  static const Set<String> blockedManualSelectionIfZoneConfigured = {
    home, school, work, university,
  };

  StatusIds._();
}
```

4. Equivalente Kotlin `android/app/src/main/kotlin/com/datainfers/zync/StatusIds.kt`.

5. **Reemplazo selectivo de literales por constantes** — solo en archivos de alto-impacto donde la duplicación causa los bugs:
   - `lib/core/services/status_service.dart` (`_blockedZoneStatusIds`, current_status_id, manual_status_id).
   - `lib/core/services/silent_functionality_coordinator.dart` (pre_silent_status_id, is_silent_mode_active, manual_status_id).
   - `lib/main.dart` (suppress_next_geofence_check).
   - `lib/features/circle/presentation/widgets/in_circle_view.dart` (lectores de pre_silent, manual, current).
   - `MainActivity.kt`, `StatusUpdateWorker.kt`, `EmojiDialogActivity.kt`.

   **NO migrar todos los archivos** — solo los de la ruta crítica de los bugs recientes. El resto se migra en su semana correspondiente.

6. Smoke test en device físico: ciclo Normal → Silent → Normal con backgrounding ≥10 minutos.

7. Cierre de semana:
   - Memoria de cierre en `memory/` (formato sección 11 del CLAUDE.md).
   - Tag `refactor-sem1-done` en el último commit verde de la semana.
   - Publicar borrador de `02-semana-2-presence.md`.

**Entregable:** PR `refactor(platform): shared Dart/Kotlin keys + StatusIds constants`.

**Criterio de done:**
- Constantes compartidas usadas en archivos de alto-impacto.
- Smoke test verde.
- Memoria guardada.
- Tag `refactor-sem1-done` creado.

---

## 3. Estructura de archivos resultante (al cierre de Sem 1)

```
lib/
├── app/
│   └── di/
│       ├── injection_container.dart
│       └── modules/
│           ├── circle_module.dart            (placeholder)
│           ├── external_module.dart
│           ├── geofencing_module.dart        (placeholder)
│           ├── identity_module.dart          (registra Auth)
│           ├── notifications_module.dart     (placeholder)
│           ├── platform_module.dart          (registra KvStore + DomainEventBus)
│           └── presence_module.dart          (placeholder)
│
├── contexts/
│   ├── README.md                             (reglas de imports + platform/ rule + event bus)
│   ├── circle/
│   │   ├── domain/
│   │   ├── application/{ports,use_cases}/
│   │   ├── infrastructure/
│   │   └── presentation/{widgets,view_models}/   (vacíos)
│   ├── geofencing/     (misma estructura)
│   ├── identity/       (misma estructura — auth se mueve en Sem 4)
│   ├── notifications/  (misma estructura)
│   └── presence/
│       ├── domain/value_objects/status_id.dart
│       ├── application/{ports,use_cases}/
│       ├── infrastructure/
│       └── presentation/{widgets,view_models}/   (vacíos)
│
├── platform/
│   ├── bridge/                               (vacío — se puebla en Sem 3)
│   └── persistence/
│       ├── kv_store.dart
│       ├── native_keys.dart
│       ├── shared_prefs_kv_store.dart
│       └── storage_keys.dart
│
├── shared/
│   ├── contract.dart
│   ├── events/                               (placeholder — se puebla en Sem 2)
│   │   ├── domain_event.dart
│   │   └── domain_event_bus.dart
│   ├── failure.dart
│   ├── result.dart
│   └── unit.dart
│
└── (resto de lib/ intacto — features/, core/, services/, widgets/, etc.)

android/app/src/main/kotlin/com/datainfers/zync/
├── SharedKeys.kt
├── StatusIds.kt
└── (resto intacto)
```

---

## 4. Criterios de aceptación (semana completa)

| # | Criterio | Cómo se verifica |
|---|----------|------------------|
| 1 | App arranca y funciona idéntico al baseline `mvp-baseline-20260506` | Smoke test manual en device físico — ciclo Normal/Silent/BN |
| 2 | `flutter analyze` sin warnings nuevos | CI |
| 3 | Suite de tests existentes verde | CI |
| 4 | Tests nuevos de `Result`, `Failure`, `Contract`, `KvStore` con ≥95% coverage | `flutter test --coverage` |
| 5 | `injection_container.dart` reescrito con módulos, sin código comentado masivo | Code review |
| 6 | `StorageKeys` y `NativeSharedKeys` cubren todas las claves del proyecto | Doc de auditoría completo |
| 7 | Constantes compartidas Dart↔Kotlin existen y se usan en archivos de alto-impacto | grep de literales restantes |
| 8 | Tag `refactor-sem1-done` creado en main | `git tag -l` |
| 9 | Memoria de cierre guardada | Archivo en `memory/` |
| 10 | Borrador `02-semana-2-presence.md` publicado | Archivo en `docs/dev/refactor-arch-2026-q2/` |

---

## 5. Tests requeridos (mínimos)

### Nuevos
- `test/shared/result_test.dart`
- `test/shared/contract_test.dart`
- `test/platform/persistence/shared_prefs_kv_store_test.dart`

### Existentes (no se tocan)
- `integration_test/` debe seguir verde.
- `test/` actual debe seguir verde.

### Smoke test manual (al cierre)
1. Login → seleccionar emoji manual ("En clase").
2. Activar Modo Silencio.
3. Backgrounding 15 min.
4. Reabrir app: el modal debe mostrar "En clase" como activo.
5. Desactivar Modo Silencio: el estado vuelve a "En clase" en Firestore.

Si cualquiera de estos pasos falla, **se revierte la última PR de la semana** y se replantea.

---

## 6. Riesgos específicos de Sem 1

| Riesgo | Probabilidad | Mitigación |
|--------|--------------|------------|
| Mover `injection_container.dart` rompe imports en archivos legacy | Media | Hacerlo en una sola PR, con grep+replace global. CI debe atrapar errores de import. |
| El nuevo `Contract` lanza excepciones en debug que antes pasaban silenciosas | Baja | DbC solo se introduce en código nuevo de Sem 2+. En Sem 1 la clase existe pero no se usa en código de producción. |
| Eliminar código comentado masivo de `injection_container.dart` borra accidentalmente algo útil | Baja | Verificar contra git history. El código está comentado desde marzo (decisión documentada en CLAUDE.md §12). |
| Auditoría de keys revela claves sin documentar que rompen el contrato Dart↔Kotlin | Media | Documentar todo lo encontrado. No reemplazar literales en archivos no listados como alto-impacto en Día 5. |

---

## 7. Definición de "done" para Semana 1

Sem 1 está cerrada cuando se cumplen **todos** los criterios de aceptación (§4) y:

- [ ] Todos los PRs mergeados a `main`.
- [ ] Tag `refactor-sem1-done` creado en remoto.
- [ ] Memoria de cierre publicada.
- [ ] Borrador del doc de Sem 2 publicado.
- [ ] Smoke test pasado en device físico.
- [ ] Análisis estático verde.
- [ ] Cobertura de tests nuevos ≥95% en archivos `shared/` y `platform/persistence/`.

---

## 8. Salida de emergencia

Si al final del día 5 **cualquier criterio de aceptación falla**:

1. Revertir el último PR problemático.
2. Documentar en `docs/dev/refactor-arch-2026-q2/blockers.md`.
3. **Sem 2 NO inicia** hasta que Sem 1 esté cerrada.
4. Si el bloqueo no se resuelve en 24h, replantear con el desarrollador la viabilidad del cronograma global.

---

## 9. Próximos pasos al cierre

Al cerrar Sem 1, generar:

- `02-semana-2-presence.md` — detalle día por día de Sem 2.
- Memoria de cierre Sem 1 (`memory/refactor_sem1_done_YYYYMMDD.md`).
- Actualización de `00-plan-unificado.md` §3.2 con cualquier ajuste descubierto.
