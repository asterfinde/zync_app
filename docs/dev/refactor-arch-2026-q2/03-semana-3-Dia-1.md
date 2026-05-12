# Sem 3 - Día 1 — Scaffold del bridge + feature flag

**Rama:** `refactor/sem3-bridge-scaffold`

**PR:** `refactor(bridge): scaffold NativeBridge + BridgeRouter + feature flag`

**Fecha planificada:** 2026-05-12 (lunes)

**Base:** tag `refactor-sem2-done` → commit `08d8962` (main activo: `38b15fa`)

---

## Contexto

Primer día de Sem 3 (Native Bridge). Es la semana de más riesgo del plan: 7 MethodChannels
heterogéneos → 1 canal `nunakin/bridge` v1. El Día 1 es **puramente aditivo**: no se migra
ningún handler todavía. Se construye el scaffold completo (interfaces Dart, stubs Kotlin,
feature flag) de modo que la app compile y arranque idéntica al baseline.

**Regla de oro:** mientras `USE_LEGACY_BRIDGE = true`, la ruta de producción es intocable.
Ningún código existente de `MainActivity.kt` se mueve hoy — solo se envuelve en
`setupLegacyChannels()`.

---

## Tarea 1 — Feature flag en `android/app/build.gradle`

Agregar en el bloque `defaultConfig`:

```gradle
defaultConfig {
    // ... campos existentes ...
    buildConfigField "boolean", "USE_LEGACY_BRIDGE", "true"
}
```

Luego en `MainActivity.kt`, localizar el método donde se registran los MethodChannels
(típicamente `configureFlutterEngine`) y dividirlo en dos métodos:

```kotlin
override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)

    if (BuildConfig.USE_LEGACY_BRIDGE) {
        setupLegacyChannels(flutterEngine)
    } else {
        setupBridgeRouter(flutterEngine)   // stub — Día 2+
    }
}

/** Todo el código de registro de canales existente va aquí, sin cambios. */
private fun setupLegacyChannels(flutterEngine: FlutterEngine) {
    // ── mover aquí el cuerpo actual de configureFlutterEngine ──
}

/** Stub — se implementa progresivamente en Días 2-5. */
private fun setupBridgeRouter(flutterEngine: FlutterEngine) {
    // TODO(sem3-día2): instanciar BridgeRouter y registrar nunakin/bridge
}
```

**Invariante:** `MainActivity.kt` no crece en líneas netas. El cuerpo de
`configureFlutterEngine` se mueve a `setupLegacyChannels`, no se duplica.

---

## Tarea 2 — `lib/platform/bridge/native_bridge.dart`

Interfaz abstracta del canal unificado. Toda la lógica de negocio que hoy llama a
MethodChannels directamente pasará a invocar esta interfaz.

```dart
import 'package:nunakin_app/platform/bridge/native_command.dart';
import 'package:nunakin_app/platform/bridge/native_event.dart';

/// Contrato del canal nativo unificado.
///
/// Reemplaza los 7 MethodChannels individuales por un único punto de entrada
/// tipado. La implementación concreta ([AndroidNativeBridge]) vive en
/// infrastructure y es la única clase autorizada a mencionar [MethodChannel].
abstract class NativeBridge {
  /// Stream de eventos emitidos por el lado nativo (Kotlin → Flutter).
  Stream<NativeEvent> get events;

  /// Envía un comando al lado nativo y espera su resultado.
  ///
  /// [T] es el tipo de retorno declarado por [NativeCommand<T>].
  Future<T> invoke<T>(NativeCommand<T> cmd);
}
```

---

## Tarea 3 — `lib/platform/bridge/native_event.dart`

Eventos que fluyen de Kotlin → Flutter. Cada clase corresponde a un evento semántico
concreto; no hay strings sueltos.

```dart
/// Eventos emitidos por el lado nativo hacia Flutter vía [NativeBridge.events].
sealed class NativeEvent {
  const NativeEvent();
}

/// El usuario seleccionó un estado desde la notificación persistente en barra.
class StatusUpdatedFromNotification extends NativeEvent {
  final String statusId;
  const StatusUpdatedFromNotification(this.statusId);
}

/// El usuario desactivó el Modo Silencio desde el tile de notificación nativa.
class SilentDeactivatedByUser extends NativeEvent {
  const SilentDeactivatedByUser();
}

/// El dispositivo cruzó hacia el interior de una zona configurada.
class GeofenceEntered extends NativeEvent {
  final String zoneId;
  const GeofenceEntered(this.zoneId);
}

/// El dispositivo salió de una zona configurada.
class GeofenceExited extends NativeEvent {
  final String zoneId;
  const GeofenceExited(this.zoneId);
}

/// El lado nativo recibió confirmación de cierre de sesión.
class SessionCleared extends NativeEvent {
  const SessionCleared();
}
```

---

## Tarea 4 — `lib/platform/bridge/native_command.dart`

Comandos que fluyen de Flutter → Kotlin. El tipo genérico `T` fuerza al compilador a
verificar el tipo de retorno en cada `invoke<T>()`.

```dart
/// Comandos enviados desde Flutter al lado nativo vía [NativeBridge.invoke].
///
/// Cada subclase declara el tipo de retorno en [T].
sealed class NativeCommand<T> {
  const NativeCommand();
}

/// Activa el Modo Silencio (tile de notificación + prefs nativos).
class ActivateSilentMode extends NativeCommand<void> {
  const ActivateSilentMode();
}

/// Desactiva el Modo Silencio y restaura el estado previo.
class DeactivateSilentMode extends NativeCommand<void> {
  const DeactivateSilentMode();
}

/// Solicita las coordenadas GPS actuales del dispositivo.
class GetCurrentLocation extends NativeCommand<({double lat, double lng})> {
  const GetCurrentLocation();
}

/// Persiste el UID y email del usuario autenticado en el lado nativo.
///
/// Necesario para que [StatusUpdateWorker] y [GeofencingService] Kotlin
/// operen en background sin acceso al estado Dart.
class SetUserSession extends NativeCommand<void> {
  final String uid;
  final String email;
  const SetUserSession({required this.uid, required this.email});
}

/// Borra la sesión persistida en el lado nativo (logout).
class ClearSession extends NativeCommand<void> {
  const ClearSession();
}
```

---

## Tarea 5 — `lib/platform/bridge/android_native_bridge.dart` — stub

Implementación mínima que compila y arroja `UnimplementedError`. Se completa handler por
handler en Días 2-5. Registrada en DI pero nunca invocada mientras el flag sea `true`.

```dart
import 'dart:async';
import 'package:nunakin_app/platform/bridge/native_bridge.dart';
import 'package:nunakin_app/platform/bridge/native_command.dart';
import 'package:nunakin_app/platform/bridge/native_event.dart';

/// Implementación Android de [NativeBridge].
///
/// Día 1: stub que compila. Días 2-5: handlers reales migrados desde los
/// 7 MethodChannels individuales.
class AndroidNativeBridge implements NativeBridge {
  final _eventController = StreamController<NativeEvent>.broadcast();

  @override
  Stream<NativeEvent> get events => _eventController.stream;

  @override
  Future<T> invoke<T>(NativeCommand<T> cmd) {
    // TODO(sem3-día2): implementar por tipo de comando via nunakin/bridge
    throw UnimplementedError('AndroidNativeBridge.invoke: $cmd');
  }

  void dispose() => _eventController.close();
}
```

---

## Tarea 6 — `android/app/src/main/kotlin/com/datainfers/zync/BridgeRouter.kt`

Clase Kotlin vacía con los 7 handler stubs. Cada método recibirá su implementación en
los días siguientes, uno por uno.

```kotlin
package com.datainfers.zync

import android.content.Context
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Router central del canal `nunakin/bridge` v1.
 *
 * Concentra los 7 handlers que hoy viven dispersos en MainActivity.kt.
 * Se instancia en setupBridgeRouter() cuando USE_LEGACY_BRIDGE = false.
 *
 * Día 1: stubs. Días 2-5: implementaciones reales migradas desde MainActivity.
 */
class BridgeRouter(private val context: Context) {

    /** Día 2 — activateSilentMode / deactivateSilentMode */
    fun handleSilentMode(call: MethodCall, result: MethodChannel.Result) {
        result.notImplemented()
    }

    /** Día 3 — updateStatus (StatusUpdateWorker → bridge) */
    fun handleStatus(call: MethodCall, result: MethodChannel.Result) {
        result.notImplemented()
    }

    /** Día 3 — raiseSOS */
    fun handleSOS(call: MethodCall, result: MethodChannel.Result) {
        result.notImplemented()
    }

    /** Día 4 — getCurrentLocation */
    fun handleLocation(call: MethodCall, result: MethodChannel.Result) {
        result.notImplemented()
    }

    /** Día 4 — setUserSession / clearSession */
    fun handleSession(call: MethodCall, result: MethodChannel.Result) {
        result.notImplemented()
    }

    /** Día 5 — registerZone / unregisterZone */
    fun handleGeofencing(call: MethodCall, result: MethodChannel.Result) {
        result.notImplemented()
    }

    /** Día 5 — setBadgeCount */
    fun handleBadge(call: MethodCall, result: MethodChannel.Result) {
        result.notImplemented()
    }
}
```

---

## Tarea 7 — Registrar `NativeBridge` en DI (`lib/app/di/modules/platform_module.dart`)

```dart
import 'package:nunakin_app/platform/bridge/android_native_bridge.dart';
import 'package:nunakin_app/platform/bridge/native_bridge.dart';
// ... imports existentes ...

Future<void> registerPlatformModule(GetIt sl) async {
  sl.registerLazySingleton<KvStore>(() => SharedPrefsKvStore(sl()));
  sl.registerLazySingleton<DomainEventBus>(DomainEventBus.new);

  // ── NUEVO ──────────────────────────────────────────────────────────────────
  // Registrado como interfaz para que los use cases no dependan de la impl
  // concreta. En Días 2-5 se invocará desde SilentCoordinator y demás.
  sl.registerLazySingleton<NativeBridge>(AndroidNativeBridge.new);
}
```

---

## Tarea 8 — Tests: `test/platform/bridge/`

### `test/platform/bridge/native_event_test.dart`

| # | Escenario | Qué verifica |
|---|-----------|-------------|
| 1 | `StatusUpdatedFromNotification('fine')` | `statusId == 'fine'` |
| 2 | `SilentDeactivatedByUser()` | instancia correcta, pattern match exhaustivo |
| 3 | `GeofenceEntered('zone-1')` | `zoneId == 'zone-1'` |
| 4 | `GeofenceExited('zone-1')` | `zoneId == 'zone-1'` |
| 5 | `SessionCleared()` | instancia correcta |
| 6 | switch exhaustivo sobre los 5 subtipos | no necesita `default` — el compilador exige cubrir todos |

### `test/platform/bridge/native_command_test.dart`

| # | Escenario | Qué verifica |
|---|-----------|-------------|
| 7 | `ActivateSilentMode()` | instancia correcta, type == `NativeCommand<void>` |
| 8 | `DeactivateSilentMode()` | ídem |
| 9 | `GetCurrentLocation()` | type param `({double lat, double lng})` es accesible |
| 10 | `SetUserSession(uid: 'u1', email: 'e@e.com')` | campos correctos |
| 11 | `ClearSession()` | instancia correcta |
| 12 | switch exhaustivo sobre los 5 comandos | no necesita `default` |

---

## Archivos afectados

| Archivo | Tipo | Cambio |
|---------|------|--------|
| `android/app/build.gradle` | Modificado | + `buildConfigField USE_LEGACY_BRIDGE` |
| `android/.../MainActivity.kt` | Modificado | Extrae cuerpo de `configureFlutterEngine` a `setupLegacyChannels()` + stub `setupBridgeRouter()` |
| `android/.../BridgeRouter.kt` | Nuevo | Router con 7 handler stubs |
| `lib/platform/bridge/native_bridge.dart` | Nuevo | Interfaz abstracta |
| `lib/platform/bridge/native_event.dart` | Nuevo | 5 eventos sealed |
| `lib/platform/bridge/native_command.dart` | Nuevo | 5 comandos sealed |
| `lib/platform/bridge/android_native_bridge.dart` | Nuevo | Stub con `UnimplementedError` |
| `lib/app/di/modules/platform_module.dart` | Modificado | + registro `NativeBridge` |
| `test/platform/bridge/native_event_test.dart` | Nuevo | 6 tests |
| `test/platform/bridge/native_command_test.dart` | Nuevo | 6 tests |

**Archivos de producción activa no modificados:** `StatusService`, `SilentFunctionalityCoordinator`,
`in_circle_view.dart`, los 7 MethodChannels existentes, lógica de negocio Kotlin.

---

## Criterios de done

| Criterio | Verificación |
|----------|-------------|
| `USE_LEGACY_BRIDGE = true` → app arranca y funciona idéntica al baseline | Arrancar app en dispositivo físico |
| `flutter analyze` sin warnings nuevos vs. baseline (394) | `flutter analyze` |
| `flutter test` en verde (incluyendo los 12 tests nuevos) | `flutter test` |
| `BridgeRouter.kt` compila sin warnings en Kotlin | Build de Android |
| `NativeBridge` accesible desde `GetIt.instance<NativeBridge>()` | Test de integración DI |
| `MainActivity.kt` no creció en líneas netas | `wc -l MainActivity.kt` ≤ 996 |
| Ningún MethodChannel existente fue renombrado o movido | Code review diff |

---

**Siguiente: Día 2 — Migrar `nunakin/silent` → `BridgeRouter.handleSilentMode` + `EnterSilentMode` use case**
