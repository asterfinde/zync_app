# Sem 3 - Día 4 — Migrar `nunakin/location` + `nunakin/session`

**Rama:** `refactor/sem3-bridge-location-session`

**PR:** `refactor(bridge): Sem3 Día4 — migrate nunakin/location + nunakin/session to BridgeRouter`

**Modelo de implementación:** Claude Sonnet 4.6 — suficiente. Location y session son canales
de dirección única (Flutter→Kotlin) sin Worker en background ni doble escritura a Firestore.
Complejidad inferior a Días 2 y 3. Opus 4.7 se reserva para Día 5 (flag flip + cleanup total).

**Fecha planificada:** 2026-05-22 (jueves)

**Base:** PR #167 → commit `78423f6`

---

## Contexto

### Estado al inicio de Día 4

| Componente | Estado |
|-----------|--------|
| `BridgeRouter.handleLocation` | Stub — `result.notImplemented()` |
| `BridgeRouter.handleSession` | Stub — `result.notImplemented()` |
| `AndroidNativeBridge.invoke(GetCurrentLocation)` | `UnimplementedError` |
| `AndroidNativeBridge.invoke(SetUserSession)` | `UnimplementedError` |
| `AndroidNativeBridge.invoke(ClearSession)` | `UnimplementedError` |
| `NativeStateBridge.dart` (`zync/native_state`) | Activo en producción — legacy path |
| `GPSService.dart` (geolocator) | Activo en producción — legacy path |

### Dirección de los canales

| Canal | Dirección | Método(s) |
|-------|-----------|-----------|
| `nunakin/location` | Flutter → Kotlin | `getCurrentLocation` |
| `nunakin/session` | Flutter → Kotlin | `setUserSession`, `clearSession` |
| `nunakin/bridge` (evento) | Kotlin → Flutter | `nativeEvent {type: sessionCleared}` |

### Lo que NO existe como canal legacy

A diferencia de Silent Mode (`zync/keep_alive`) o Status (`com.datainfers.zync/status_update`),
**`nunakin/location` no tiene un canal legacy directo en `setupLegacyChannels`**. La ubicación
GPS se obtiene hoy vía el plugin `geolocator` (Dart-side, sin MethodChannel explícito en
`MainActivity`). El bridge introduce un path alternativo Flutter→Kotlin para `GetCurrentLocation`
que usará `FusedLocationProviderClient` — la misma API que usa `EmojiDialogActivity.kt`.

**`nunakin/session`** sí tiene un equivalente legacy: el canal `zync/native_state` con el método
`setUserId` / logout. `BridgeRouter.handleSession` extrae esa lógica.

### Split de responsabilidades MainActivity ↔ BridgeRouter

`BridgeRouter` maneja la lógica de dominio (NativeStateManager, SharedPrefs, eventos).
`MainActivity` retiene las operaciones de UI que dependen del ciclo de vida de la Activity:
- `warmUpModalEngine()` — se llama desde el `when` en `setupBridgeRouter` tras `setUserSession`
- `destroyModalEngine()` — se llama desde el `when` en `setupBridgeRouter` tras `clearSession`
- `currentUserId` field — se actualiza en `setupBridgeRouter` tras cada llamada a `handleSession`

Este split evita pasar referencias de Activity a BridgeRouter más allá de lo necesario.

---

## Restricciones explícitas

> Estas restricciones son tan importantes como las tareas.

| Restricción | Razón |
|-------------|-------|
| **NO tocar `setupLegacyChannels`** | Ruta de producción activa con `USE_LEGACY_BRIDGE = true` |
| **NO modificar `NativeStateBridge.dart`** | Sigue en uso con flag legacy; migración de callers es post-Día 5 |
| **NO modificar `GPSService.dart`** | Sigue usando geolocator; migración de callers es post-Día 5 |
| **NO hacer `USE_LEGACY_BRIDGE = false`** | El flip es exclusivo de Día 5 |
| **NO llamar `warmUpModalEngine()` desde BridgeRouter** | Ciclo de vida de engine es responsabilidad de MainActivity |
| **`handleLocation` no usa el hilo principal para la callback** | `FusedLocationProviderClient.getCurrentLocation` ejecuta la callback en el main looper por defecto — no requiere `Handler(Looper.getMainLooper())` adicional |

---

## T1 — `BridgeRouter.handleLocation` (Kotlin)

Implementar obtención de ubicación GPS vía `FusedLocationProviderClient`.
Patrón idéntico al que ya usa `EmojiDialogActivity.kt`.

```kotlin
import android.Manifest
import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.google.android.gms.tasks.CancellationTokenSource

fun handleLocation(call: MethodCall, result: MethodChannel.Result) {
    val fineOk = ActivityCompat.checkSelfPermission(
        context, Manifest.permission.ACCESS_FINE_LOCATION
    ) == PackageManager.PERMISSION_GRANTED
    val coarseOk = ActivityCompat.checkSelfPermission(
        context, Manifest.permission.ACCESS_COARSE_LOCATION
    ) == PackageManager.PERMISSION_GRANTED

    if (!fineOk && !coarseOk) {
        Log.w(tag, "📍 [LOCATION] Sin permiso ACCESS_FINE_LOCATION ni ACCESS_COARSE_LOCATION")
        result.error("NO_PERMISSION", "Location permission not granted", null)
        return
    }

    val cts = CancellationTokenSource()
    LocationServices.getFusedLocationProviderClient(activity)
        .getCurrentLocation(Priority.PRIORITY_HIGH_ACCURACY, cts.token)
        .addOnSuccessListener { location ->
            if (location != null) {
                Log.d(tag, "📍 [LOCATION] Obtenida: ${location.latitude}, ${location.longitude}")
                result.success(mapOf("lat" to location.latitude, "lng" to location.longitude))
            } else {
                Log.w(tag, "📍 [LOCATION] FusedLocationProvider devolvió null")
                result.error("NULL_LOCATION", "Location is null — GPS disabled or no fix", null)
            }
        }
        .addOnFailureListener { e ->
            Log.e(tag, "📍 [LOCATION] Error: ${e.message}")
            result.error("LOCATION_ERROR", e.message, null)
        }
}
```

**Imports a agregar en `BridgeRouter.kt`:**
```kotlin
import android.Manifest
import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.google.android.gms.tasks.CancellationTokenSource
```

**Nota:** `com.google.android.gms:play-services-location` ya está en `build.gradle` (usada por
`EmojiDialogActivity`). No se agrega dependencia nueva.

---

## T2 — `BridgeRouter.handleSession` (Kotlin)

Extraer lógica del canal legacy `zync/native_state` (`setupLegacyChannels`, líneas ~426-479).

```kotlin
fun handleSession(call: MethodCall, result: MethodChannel.Result, messenger: BinaryMessenger) {
    when (call.method) {
        "setUserSession" -> {
            val uid   = call.argument<String>("uid") ?: ""
            val email = call.argument<String>("email") ?: ""

            if (uid.isNotEmpty()) {
                val existingCircleId = context
                    .getSharedPreferences("worker_state", Context.MODE_PRIVATE)
                    .getString("circleId", "") ?: ""

                Log.d(tag, "[SESSION] setUserSession: uid=$uid circleId(preserved)=$existingCircleId")
                NativeStateManager.saveUserState(context, uid, email, existingCircleId)
                context.getSharedPreferences("worker_state", Context.MODE_PRIVATE)
                    .edit()
                    .putString("userId", uid)
                    .putString("circleId", existingCircleId)
                    .commit()
                result.success(true)
            } else {
                Log.w(tag, "[SESSION] setUserSession recibió uid vacío — usar clearSession en su lugar")
                result.error("INVALID_UID", "uid must not be empty", null)
            }
        }
        "clearSession" -> {
            Log.d(tag, "[SESSION] clearSession — limpiando NativeStateManager")
            NativeStateManager.clear(context)
            emitSessionClearedEvent(messenger)
            result.success(true)
        }
        else -> result.notImplemented()
    }
}

fun emitSessionClearedEvent(messenger: BinaryMessenger) {
    MethodChannel(messenger, "nunakin/bridge").invokeMethod(
        "nativeEvent",
        mapOf("type" to "sessionCleared")
    )
    Log.d(tag, "[SESSION] SessionCleared event emitido hacia Flutter")
}
```

**Invariante:** `circleId` se **preserva** al hacer `setUserSession` — el bridge no recibe
`circleId` (es un concepto del Círculo, no de la sesión). El caller Dart que necesite
actualizar `circleId` sigue usando el canal legacy `zync/native_state` hasta que el
contexto de Circle tenga su propio canal en Sem 4.

---

## T3 — `MainActivity.setupBridgeRouter` — 3 rutas nuevas (Kotlin)

Agregar los 3 métodos al `when` del canal `nunakin/bridge` y manejar los side effects
de UI que no pertenecen a BridgeRouter.

```kotlin
private fun setupBridgeRouter(flutterEngine: FlutterEngine) {
    val router = BridgeRouter(activity = this)
    val messenger = flutterEngine.dartExecutor.binaryMessenger
    activeBridgeRouter = router
    bridgeBinaryMessenger = messenger

    MethodChannel(messenger, "nunakin/bridge").setMethodCallHandler { call, result ->
        when (call.method) {
            // Silent (Día 2)
            "activateSilentMode"   -> router.handleSilentMode(call, result)
            "deactivateSilentMode" -> router.handleSilentMode(call, result)
            "checkBattery"         -> router.handleSilentMode(call, result)
            "requestBattery"       -> router.handleSilentMode(call, result)
            // Status / SOS (Día 3 — stubs)
            "updateStatus"         -> router.handleStatus(call, result)
            "raiseSOS"             -> router.handleSOS(call, result)
            // Location (Día 4)
            "getCurrentLocation"   -> router.handleLocation(call, result)
            // Session (Día 4)
            "setUserSession" -> {
                router.handleSession(call, result, messenger)
                // Side effects de MainActivity: UI + campo local
                currentUserId = call.argument<String>("uid")
                if (!currentUserId.isNullOrEmpty()) warmUpModalEngine()
            }
            "clearSession" -> {
                router.handleSession(call, result, messenger)
                currentUserId = null
                destroyModalEngine()
            }
            else -> result.notImplemented()
        }
    }
}
```

---

## T4 — `AndroidNativeBridge.invoke` (Dart)

Implementar los 3 comandos pendientes. Eliminar el test obsoleto
`'Unimplemented command throws UnimplementedError'` (ya no aplica para `GetCurrentLocation`).

```dart
@override
Future<T> invoke<T>(NativeCommand<T> cmd) async {
  switch (cmd) {
    case ActivateSilentMode():
      // ... (existente — no modificar)

    case DeactivateSilentMode():
      // ... (existente — no modificar)

    case GetCurrentLocation():
      final raw = await _channel.invokeMapMethod<String, dynamic>('getCurrentLocation');
      if (raw == null) {
        throw PlatformException(code: 'NULL_RESULT', message: 'getCurrentLocation returned null');
      }
      return (lat: (raw['lat'] as num).toDouble(), lng: (raw['lng'] as num).toDouble()) as T;

    case SetUserSession():
      await _channel.invokeMethod<void>('setUserSession', {
        'uid':   cmd.uid,
        'email': cmd.email,
      });
      return null as T;

    case ClearSession():
      await _channel.invokeMethod<void>('clearSession');
      return null as T;

    // El `default` se elimina — todos los comandos del sealed class están cubiertos.
  }
}
```

**Nota sobre el `default`:** Una vez cubiertos todos los casos del sealed class, Dart
infiere exhaustividad en tiempo de compilación. Eliminar `default: throw UnimplementedError(...)`
hace que agregar un comando nuevo en `native_command.dart` genere un warning del compilador
(compile-time safety).

---

## T5 — Tests unitarios

Modificar `test/platform/bridge/android_native_bridge_test.dart`:

### Cambio en tests existentes

Reemplazar el test `'Unimplemented command throws UnimplementedError'` por el test 8
(ya que `GetCurrentLocation` ahora tiene implementación, no lanza error):

```dart
// Eliminar:
test('Unimplemented command throws UnimplementedError', () async {
  expect(
    () => bridge.invoke(const GetCurrentLocation()),
    throwsA(isA<UnimplementedError>()),
  );
  expect(calls, isEmpty);
});
```

### Nuevos tests

| # | Escenario | Qué verifica |
|---|-----------|-------------|
| 8 | `GetCurrentLocation` | Invoca `getCurrentLocation` en el canal; parsea `{lat: 1.23, lng: 4.56}` → record correcto |
| 9 | `SetUserSession(uid: 'u1', email: 'e@e.com')` | Invoca `setUserSession` con args `{uid: 'u1', email: 'e@e.com'}` |
| 10 | `ClearSession()` | Invoca `clearSession` sin argumentos |

```dart
setUp(() {
  channel = const MethodChannel(AndroidNativeBridge.channelName);
  calls = <MethodCall>[];
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
    calls.add(call);
    // Mock de retorno para getCurrentLocation
    if (call.method == 'getCurrentLocation') {
      return {'lat': 1.23, 'lng': 4.56};
    }
    return null;
  });
  bridge = AndroidNativeBridge(channel: channel);
});

test('GetCurrentLocation invokes "getCurrentLocation" and parses result', () async {
  final loc = await bridge.invoke(const GetCurrentLocation());
  expect(calls.single.method, 'getCurrentLocation');
  expect(loc.lat, closeTo(1.23, 0.001));
  expect(loc.lng, closeTo(4.56, 0.001));
});

test('SetUserSession invokes "setUserSession" with uid and email', () async {
  await bridge.invoke(const SetUserSession(uid: 'u1', email: 'e@e.com'));
  expect(calls.single.method, 'setUserSession');
  expect(calls.single.arguments['uid'], 'u1');
  expect(calls.single.arguments['email'], 'e@e.com');
});

test('ClearSession invokes "clearSession" with no arguments', () async {
  await bridge.invoke(const ClearSession());
  expect(calls.single.method, 'clearSession');
  expect(calls.single.arguments, isNull);
});
```

---

## Archivos afectados

| Archivo | Tipo | Cambio |
|---------|------|--------|
| `android/.../BridgeRouter.kt` | Modificado | Implementar `handleLocation` + `handleSession` + `emitSessionClearedEvent` + imports GPS |
| `android/.../MainActivity.kt` | Modificado | Agregar `getCurrentLocation`, `setUserSession`, `clearSession` al `when` en `setupBridgeRouter` |
| `lib/platform/bridge/android_native_bridge.dart` | Modificado | Implementar `GetCurrentLocation`, `SetUserSession`, `ClearSession` en `invoke()`; eliminar `default` throw |
| `test/platform/bridge/android_native_bridge_test.dart` | Modificado | Reemplazar test `UnimplementedError` + agregar tests 8-10 |
| `docs/dev/refactor-arch-2026-q2/03-semana-3-Dia-4.md` | Nuevo | Este documento |

**Archivos NO modificados:**
- `NativeStateBridge.dart` — legacy activo
- `GPSService.dart` — legacy activo  
- `StatusService.dart`
- `native_bridge.dart`, `native_event.dart`, `native_command.dart`
- `setupLegacyChannels` en `MainActivity.kt`
- `USE_LEGACY_BRIDGE` en `build.gradle`

---

## Criterios de done

| # | Criterio | Verificación |
|---|----------|-------------|
| 1 | `handleLocation` retorna `{lat, lng}` cuando hay permiso | Test unitario #8 |
| 2 | `handleLocation` retorna error `NO_PERMISSION` sin permiso | Code review + log |
| 3 | `handleSession(setUserSession)` escribe NativeStateManager + worker_state | Code review |
| 4 | `handleSession(clearSession)` limpia NativeStateManager y emite `SessionCleared` | Code review + test #10 |
| 5 | `AndroidNativeBridge.invoke` cubre los 5 comandos del sealed class (0 `default`) | Compilador Dart — sin warnings |
| 6 | Test obsoleto `UnimplementedError` eliminado | Tests no contienen referencia |
| 7 | `flutter test` — todos en verde (≥103) | Salida del comando |
| 8 | `flutter analyze` — 0 warnings nuevos vs. baseline (394) | Salida del comando |
| 9 | `flutter build apk --debug` — sin errores de compilación Kotlin | Salida del build |
| 10 | `MainActivity.kt` no crece más de 15 líneas vs. post-Día 3 (≤1044) | `wc -l MainActivity.kt` |

---

## Nota sobre criterio de líneas del plan maestro

El plan maestro indica `MainActivity.kt ≤350 líneas` para Día 4. Esta cifra es alcanzable
**solo después de eliminar `setupLegacyChannels`**, lo que ocurre en Día 5 (o PR siguiente
tras el flip del flag). Con `USE_LEGACY_BRIDGE = true` activo durante toda la semana,
`setupLegacyChannels` (~280 líneas) permanece intacto. El criterio real de Día 4 es que
`MainActivity` **no crezca significativamente** (≤+15 líneas). La reducción a ≤350 se
registra como meta de Día 5.

---

## Riesgos específicos de Día 4

| Riesgo | Probabilidad | Mitigación |
|--------|--------------|------------|
| `FusedLocationProviderClient.getCurrentLocation` retorna null sin GPS activo | Media | Manejo explícito en `addOnSuccessListener` con `result.error("NULL_LOCATION", ...)` |
| `result.success()` llamado dos veces (desde BridgeRouter + MainActivity) | Baja | `handleSession` llama `result.success()` solo para `setUserSession`; `clearSession` también. El código de MainActivity después del `router.handleSession(...)` NO llama `result` de nuevo |
| `circleId` borrado en `setUserSession` | Media | Explícitamente preservado leyendo de `worker_state` antes de escribir |
| Dart `default` eliminado — nuevo comando no compilará | Positivo | Es el comportamiento deseado: compile-time safety |

---

**Siguiente: Día 5 — Migrar `nunakin/geofencing` + `nunakin/badge` + flip del flag +
cierre de Sem 3. Usar Claude Opus 4.7.**
