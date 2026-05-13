# Sem 1 - Día 3 — DI con módulos + Contract (DbC)

**Rama:** refactor/sem1-di-modules

**Modelo:** Opus

**Base:** main → 9f8b15f (cierre Día 2)

---

## Contexto real del código

Antes de tocar nada, los hechos relevantes del estado actual:

| Archivo | Estado |
|---------|--------|
| `lib/core/di/injection_container.dart` | Activo en disco, desconectado del runtime — las 3 referencias externas están comentadas (`main.dart:15`, `initialization_service.dart:29`, `emoji_modal.dart:327/490`) |
| `GetIt.instance` (sl) | Instancia vacía — ninguna registración activa al arrancar la app |
| Auth | Funciona vía `FirebaseAuth.instance` directo, no vía DI |
| `lib/app/` | Solo tiene `.gitkeep` |
| Bloque comentado `main.dart` (líneas 295–387) | 92 líneas de dead code (versión legacy completa de `main.dart`) |

**Consecuencia para el plan:** el nuevo `initDependencies()` es una rehabilitación limpia, sin riesgo de colisión con registraciones existentes.

---

## Archivos del Día 3

| Acción | Archivo |
|--------|---------|
| Crear | `lib/app/di/injection_container.dart` |
| Crear | `lib/app/di/modules/external_module.dart` |
| Crear | `lib/app/di/modules/identity_module.dart` |
| Crear | `lib/app/di/modules/circle_module.dart` (placeholder) |
| Crear | `lib/app/di/modules/presence_module.dart` (placeholder) |
| Crear | `lib/app/di/modules/geofencing_module.dart` (placeholder) |
| Crear | `lib/app/di/modules/notifications_module.dart` (placeholder) |
| Crear | `lib/app/di/modules/platform_module.dart` (placeholder) |
| Crear | `lib/shared/contract.dart` |
| Crear | `test/shared/contract_test.dart` |
| Modificar | `lib/main.dart` (2 cambios quirúrgicos) |
| Eliminar | `lib/core/di/injection_container.dart` |

---

## Tarea 1 — lib/app/di/injection_container.dart

```dart
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

**Nota:** `sl` se declara aquí como punto único de acceso. Los módulos reciben `GetIt` como parámetro — nunca llaman `GetIt.instance` directamente.

---

## Tarea 2 — lib/app/di/modules/external_module.dart

Contiene exactamente lo que hoy está en las líneas 83–91 del `injection_container.dart` original, más `NetworkInfo`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nunakin_app/core/network/network_info.dart';
import 'package:nunakin_app/core/network/network_info_impl.dart';

Future<void> registerExternalModule(GetIt sl) async {
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerLazySingleton(() => sharedPreferences);
  sl.registerLazySingleton(() => FirebaseAuth.instance);
  sl.registerLazySingleton(() => FirebaseFirestore.instance);
  sl.registerLazySingleton(() => Connectivity());
  sl.registerLazySingleton<NetworkInfo>(() => NetworkInfoImpl(sl()));
}
```

**Por qué `NetworkInfo` aquí:** es infraestructura transversal (wrappea `Connectivity`), no pertenece a ningún bounded context en particular.

---

## Tarea 3 — lib/app/di/modules/identity_module.dart

Contiene exactamente las registraciones activas del `injection_container.dart` original (líneas 44–61):

```dart
import 'package:get_it/get_it.dart';
import 'package:nunakin_app/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:nunakin_app/features/auth/data/datasources/auth_local_data_source_impl.dart';
import 'package:nunakin_app/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:nunakin_app/features/auth/data/datasources/auth_remote_data_source_impl.dart';
import 'package:nunakin_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:nunakin_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:nunakin_app/features/auth/domain/usecases/get_current_user.dart';
import 'package:nunakin_app/features/auth/domain/usecases/sign_in_or_register.dart';
import 'package:nunakin_app/features/auth/domain/usecases/sign_out.dart';

Future<void> registerIdentityModule(GetIt sl) async {
  sl.registerLazySingleton(() => GetCurrentUser(sl()));
  sl.registerLazySingleton(() => SignInOrRegister(sl()));
  sl.registerLazySingleton(() => SignOut(sl()));
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      remoteDataSource: sl(),
      localDataSource: sl(),
      networkInfo: sl(),
    ),
  );
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(firebaseAuth: sl(), firestore: sl()),
  );
  sl.registerLazySingleton<AuthLocalDataSource>(
    () => AuthLocalDataSourceImpl(sharedPreferences: sl()),
  );
}
```

**Nota:** estos imports siguen apuntando a `lib/features/auth/`. La migración a `lib/contexts/identity/` ocurre en Sem 4 — aquí solo se mueven las registraciones, no el código.

---

## Tarea 4 — Módulos placeholder

Cinco archivos con la misma estructura. Ejemplo para `circle_module.dart`:

```dart
import 'package:get_it/get_it.dart';

/// Placeholder — se puebla en Sem 4 (Identity + Circle).
Future<void> registerCircleModule(GetIt sl) async {
  // TODO Sem 4: CircleRepository, JoinCircle, ApproveJoinRequest, LeaveCircle
}
```

Misma estructura para `presence_module.dart` (TODO Sem 2), `geofencing_module.dart` (TODO Sem 4), `notifications_module.dart` (TODO Sem 4), y `platform_module.dart`:

```dart
// platform_module.dart
import 'package:get_it/get_it.dart';

/// Placeholder — se puebla en Día 4 (KvStore) y Sem 2 (DomainEventBus).
Future<void> registerPlatformModule(GetIt sl) async {
  // TODO Día 4: KvStore (SharedPrefsKvStore)
  // TODO Sem 2: DomainEventBus
}
```

---

## Tarea 5 — lib/shared/contract.dart

```dart
import 'package:flutter/foundation.dart';

/// Thrown when a [Contract] condition is violated in debug mode.
/// No-op in release builds (assert is compiled out).
class ContractViolation extends Error {
  final String kind; // 'precondition' | 'postcondition' | 'invariant'
  final String description;

  ContractViolation(this.kind, this.description);

  @override
  String toString() => 'ContractViolation [$kind]: $description';
}

/// Design-by-Contract guards for use cases and state machine transitions.
///
/// All methods are no-ops in release builds — the assert block is
/// stripped by the compiler. Use at entry/exit of critical use cases only.
abstract final class Contract {
  static void requires(bool condition, String description) {
    assert(() {
      if (!condition) {
        if (kDebugMode) debugPrint('❌ [Contract.requires] $description');
        throw ContractViolation('precondition', description);
      }
      return true;
    }());
  }

  static void ensures(bool condition, String description) {
    assert(() {
      if (!condition) {
        if (kDebugMode) debugPrint('❌ [Contract.ensures] $description');
        throw ContractViolation('postcondition', description);
      }
      return true;
    }());
  }

  static void invariant(bool condition, String description) {
    assert(() {
      if (!condition) {
        if (kDebugMode) debugPrint('❌ [Contract.invariant] $description');
        throw ContractViolation('invariant', description);
      }
      return true;
    }());
  }
}
```

**Por qué `assert(() { }()`:** el compilador elimina el bloque completo (incluyendo el `throw`) en builds de release. Un `if (kDebugMode)` solo ocultaría el log pero evaluaría la expresión — el `assert` garantiza costo cero en producción.

**Restricción de uso:** `Contract` se define aquí pero no se aplica a código existente — se usa desde Sem 2 en adelante, en los use cases nuevos. Para Día 3 la clase existe pero no tiene callers.

---

## Tarea 6 — lib/main.dart (2 cambios quirúrgicos)

**Cambio A** — rehabilitar import DI (línea 15, actualmente comentada):

```dart
// ANTES
// import 'package:nunakin_app/core/di/injection_container.dart' as di; // 🔥 SIMPLIFICADO: Ya no se usa para Auth

// DESPUÉS
import 'package:nunakin_app/app/di/injection_container.dart' as di;
```

**Cambio B** — agregar llamada en `main()`, después de `Firebase.initializeApp()` y antes de `SessionCacheService.init()`:

```dart
await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

await di.initDependencies(); // ← agregar aquí

await SessionCacheService.init();
```

**Cambio C** — eliminar bloque comentado (líneas 295–387, 92 líneas de dead code):

```dart
// Eliminar todo desde:
/////////////////////////////////////////////
// // lib/main.dart
// ...
// hasta el final del archivo
```

**Lo que NO se toca en `main.dart`:** los `print()` activos (scope Sem 6), la lógica de `_updateStatusFromNative`, los lifecycle handlers, el `MethodChannel` hardcodeado (scope Sem 3).

---

## Tarea 7 — Eliminar lib/core/di/injection_container.dart

**Pre-condición confirmada:** las 3 referencias externas son comentarios muertos.

```bash
git rm lib/core/di/injection_container.dart
```

Si `lib/core/di/` queda vacía, agregar `.gitkeep` o eliminar el directorio vacío.

---

## Tarea 8 — test/shared/contract_test.dart

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nunakin_app/shared/contract.dart';

void main() {
  group('Contract.requires', () {
    test('condition true — no lanza', () {
      expect(() => Contract.requires(true, 'ok'), returnsNormally);
    });

    test('condition false — lanza ContractViolation con kind precondition', () {
      expect(
        () => Contract.requires(false, 'must be positive'),
        throwsA(
          isA<ContractViolation>()
            .having((e) => e.kind, 'kind', 'precondition')
            .having((e) => e.description, 'description', 'must be positive'),
        ),
      );
    });
  });

  group('Contract.ensures', () {
    test('condition true — no lanza', () {
      expect(() => Contract.ensures(true, 'ok'), returnsNormally);
    });

    test('condition false — lanza ContractViolation con kind postcondition', () {
      expect(
        () => Contract.ensures(false, 'state must be silent'),
        throwsA(
          isA<ContractViolation>()
            .having((e) => e.kind, 'kind', 'postcondition'),
        ),
      );
    });
  });

  group('Contract.invariant', () {
    test('condition true — no lanza', () {
      expect(() => Contract.invariant(true, 'ok'), returnsNormally);
    });

    test('condition false — lanza ContractViolation con kind invariant', () {
      expect(
        () => Contract.invariant(false, 'circle must have owner'),
        throwsA(
          isA<ContractViolation>()
            .having((e) => e.kind, 'kind', 'invariant'),
        ),
      );
    });
  });

  group('ContractViolation.toString', () {
    test('incluye kind y description', () {
      final v = ContractViolation('precondition', 'x must be positive');
      expect(v.toString(), contains('precondition'));
      expect(v.toString(), contains('x must be positive'));
    });
  });
}
```

---

## Restricciones

| Regla | Scope |
|-------|-------|
| No reemplazar ningún `print()` activo en `main.dart` | Sem 6 |
| No tocar `MethodChannel` hardcodeado en `main.dart` | Sem 3 |
| No mover `lib/features/auth/` | Sem 4 |
| No agregar `Contract` calls a código existente | Solo publicar la clase |
| Solo eliminar el bloque comentado de `main.dart` (líneas 295–387) | No comentarios de línea individuales |

---

## Entregable

**PR:** `refactor(di): module-based dependency injection + Contract for DbC`

---

## Criterio de done

| # | Criterio | Verificación |
|---|----------|--------------|
| 1 | App arranca idéntico al baseline (mvp-baseline-20260506) | Smoke test: login → seleccionar emoji → ver círculo |
| 2 | `flutter analyze` sin warnings nuevos | CI |
| 3 | `flutter test` 100% verde (24 tests existentes + nuevos de Contract) | `flutter test` |
| 4 | `lib/app/di/` con los 8 archivos | `tree lib/app/` |
| 5 | `lib/core/di/injection_container.dart` eliminado | `git status` |
| 6 | `initDependencies()` llamado en `main()` | Code review |
| 7 | Bloque comentado de `main.dart` (líneas 295–387) eliminado | Code review |
| 8 | Contract tests: 7/7 ✅ | `flutter test test/shared/contract_test.dart` |
| 9 | Contract no tiene callers en código existente | `grep -r "Contract\." lib/` |

---

## Riesgo específico del Día 3

| Riesgo | Probabilidad | Mitigación |
|--------|--------------|-------------|
| `initDependencies()` llama `SharedPreferences.getInstance()` que `main()` ya llamó antes | Baja | Flutter cachea la instancia — segunda llamada retorna el mismo objeto |
| `injection_container.dart` tiene referencia activa no detectada | Muy baja | `grep` en Tarea 7 antes de `git rm` confirma que las 3 referencias son comentarios |
| `ContractViolation` en tests lanza pero `assert` no evaluado | Nula | `flutter test` corre en modo debug — `assert` siempre activo |

---

## CONFIRMACIÓN FINAL

### Estado del Repositorio

- ✅ Branch refactor/sem1-di-modules mergeada y eliminada (local + remota).
- ✅ PR #147 squash-mergeado.
- ✅ main actualizado: 76a80f7 refactor(di): module-based dependency injection + Contract for DbC (#147).
- ✅ flutter analyze: 394 issues (mismo baseline, sin nuevos).
- ✅ flutter test: 31/31 ✅ (24 previos + 7 Contract).

### Memoria Guardada

- ✅ Archivo: project_session_20260507.md
- ✅ Índice MEMORY.md actualizado.

### Próximos Pasos

- Día 4 — KvStore en platform_module. El placeholder ya existe.
- Smoke test pendiente en dispositivo (login → emoji → círculo) antes del Día 4.
- scripts/seed.dart quedó referenciando el archivo eliminado (excluido en analysis_options.yaml, ya estaba roto desde marzo) — fuera del scope.

---