# Sem 2 - Día 5 — `PresenceViewModel` + DI wiring + cierre de Sem 2

**Rama:** `refactor/sem2-vm-di-close`

**PR:** `refactor(presence): PresenceViewModel + DI wiring + Sem 2 close`

**Fecha:** 2026-05-08

**Base:** PR #158 → commit `0111e91`

---

## Contexto

Día final de Sem 2. Se completa el Presence context con:

1. `PresenceViewModel` — expone `Stream<PresenceState>` a la capa de presentación (sin
   conectar a ningún widget todavía — eso ocurre en Sem 5).
2. `presence_module.dart` — el placeholder se reemplaza por el registro completo de todos
   los objetos del contexto.
3. Test de integración `presence_integration_test.dart` — ejercita el ciclo completo de
   transiciones con fakes, sin dispositivo ni Firestore real.
4. Cierre formal: `flutter test`, `flutter analyze`, tag `refactor-sem2-done`, memoria,
   borrador `03-semana-3-native-bridge.md`.

**Premisa invariante:** todo es aditivo. Los objetos nuevos están en el contenedor DI pero
ningún código de producción los invoca todavía. `StatusService` y
`SilentFunctionalityCoordinator` siguen siendo la ruta activa.

---

## Estado del repo al inicio

| Archivo | Estado |
|---------|--------|
| `lib/contexts/presence/domain/presence_state.dart` | ✅ Día 1 |
| `lib/contexts/presence/application/ports/presence_repository.dart` | ✅ Día 2 |
| `lib/contexts/presence/infrastructure/shared_prefs_presence_repository.dart` | ✅ Día 2 |
| `lib/contexts/presence/application/ports/presence_publisher.dart` | ✅ Día 3 |
| `lib/contexts/presence/application/use_cases/set_manual_status.dart` | ✅ Día 3 |
| `lib/contexts/presence/application/use_cases/enter_silent_mode.dart` | ✅ Día 3 |
| `lib/contexts/presence/application/use_cases/exit_silent_mode.dart` | ✅ Día 4 |
| `lib/contexts/presence/application/use_cases/raise_sos.dart` | ✅ Día 4 |
| `lib/contexts/presence/infrastructure/firestore_presence_publisher.dart` | ✅ Día 4 |
| `lib/app/di/modules/presence_module.dart` | ⚠️ placeholder (TODO Sem 2) |
| `lib/app/di/modules/external_module.dart` | ✅ tiene `FirebaseFirestore.instance` |
| `lib/app/di/modules/platform_module.dart` | ✅ tiene `KvStore` + `DomainEventBus` |

---

## Tarea 1 — `PresenceViewModel`

**Archivo:** `lib/contexts/presence/presentation/view_models/presence_view_model.dart`

Clase pura Dart — sin `StatefulWidget`, sin `ChangeNotifier`, sin Riverpod. La conexión
al widget tree se hace en Sem 5 cuando `InCircleView` se descompone.

```dart
import 'dart:async';
import 'package:nunakin_app/contexts/presence/application/ports/presence_repository.dart';
import 'package:nunakin_app/contexts/presence/domain/presence_state.dart';

class PresenceViewModel {
  final PresenceRepository _repository;
  StreamSubscription<PresenceState>? _sub;
  PresenceState? _current;

  PresenceViewModel({required PresenceRepository repository})
      : _repository = repository;

  Future<void> init() async {
    final result = await _repository.currentState();
    _current = result.valueOrNull;
    _sub = _repository.stateStream.listen((state) {
      _current = state;
    });
  }

  Stream<PresenceState> get stateStream => _repository.stateStream;
  PresenceState? get currentSnapshot => _current;

  void dispose() => _sub?.cancel();
}
```

**Por qué clase pura y no ChangeNotifier:** Sem 5 decide el mecanismo reactivo definitivo
(puede ser Riverpod, ValueNotifier, o simple Stream). Esta clase no impone nada.

---

## Tarea 2 — `presence_module.dart` completo

**Archivo:** `lib/app/di/modules/presence_module.dart` — reemplaza el placeholder.

Registra en orden: infrastructure → application (use cases) → presentation (view model).

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get_it/get_it.dart';
import 'package:nunakin_app/contexts/presence/application/ports/presence_publisher.dart';
import 'package:nunakin_app/contexts/presence/application/ports/presence_repository.dart';
import 'package:nunakin_app/contexts/presence/application/use_cases/enter_silent_mode.dart';
import 'package:nunakin_app/contexts/presence/application/use_cases/exit_silent_mode.dart';
import 'package:nunakin_app/contexts/presence/application/use_cases/raise_sos.dart';
import 'package:nunakin_app/contexts/presence/application/use_cases/set_manual_status.dart';
import 'package:nunakin_app/contexts/presence/infrastructure/firestore_presence_publisher.dart';
import 'package:nunakin_app/contexts/presence/infrastructure/shared_prefs_presence_repository.dart';
import 'package:nunakin_app/contexts/presence/presentation/view_models/presence_view_model.dart';
import 'package:nunakin_app/platform/persistence/kv_store.dart';

Future<void> registerPresenceModule(GetIt sl) async {
  // Infrastructure
  sl.registerLazySingleton<PresenceRepository>(
    () => SharedPrefsPresenceRepository(sl<KvStore>()),
  );
  sl.registerLazySingleton<PresencePublisher>(
    () => FirestorePresencePublisher(sl<FirebaseFirestore>()),
  );

  // Use cases (Factory: nueva instancia por solicitud, stateless)
  sl.registerFactory(() => SetManualStatus(repository: sl(), publisher: sl()));
  sl.registerFactory(() => EnterSilentMode(repository: sl()));
  sl.registerFactory(() => ExitSilentMode(repository: sl()));
  sl.registerFactory(() => RaiseSOS(repository: sl(), publisher: sl()));

  // Presentation
  sl.registerLazySingleton(() => PresenceViewModel(repository: sl()));
}
```

**Nota:** `FirebaseFirestore` viene de `external_module.dart` (ya registrado).
`KvStore` viene de `platform_module.dart` (ya registrado).
Ambos módulos se inicializan antes que `presence_module` en `injection_container.dart`.

---

## Tarea 3 — Test de integración

**Archivo:** `test/contexts/presence/presence_integration_test.dart`

Ejercita el ciclo completo de transiciones usando `FakePresenceRepository` y
`FakePresencePublisher`. Sin dispositivo ni Firestore real.

```
Normal(fine)
  → SetManualStatus('school')  → Normal(currentId: 'school', lastManualId: 'school')
  → EnterSilentMode()          → SilentMode(preSilentId: 'school')
  → ExitSilentMode()           → Normal(currentId: 'school', lastManualId: 'school')
  → RaiseSOS(lat, lng)         → SOSActive(previousId: 'school')
```

Además verifica que `PresenceViewModel.stateStream` emite los estados en orden.

**Gap documentado:** `SetManualStatus(statusId: 'sos')` no está bloqueado a nivel de use
case (el bloqueo de zona activa viene de `StatusService._blockedZoneStatusIds`, que se
migra en Sem 4). Se cubre en el test solo para confirmar que el path compila y devuelve
`Success` — el significado semántico del bloqueo es deuda de Sem 4.

---

## Tarea 4 — Verificar `injection_container.dart`

Confirmar que `registerPresenceModule` se llama en la secuencia correcta:

```
registerExternalModule  (SharedPreferences, FirebaseAuth, FirebaseFirestore)
registerPlatformModule  (KvStore, DomainEventBus)
registerPresenceModule  (PresenceRepository, use cases, PresenceViewModel)
...
```

Si el orden no es correcto, o si `presence_module` no está en la lista, agregarlo.

---

## Tarea 5 — Cierre de semana

### 5.1 Tests
```
flutter test
```
Todos en verde. El número sube respecto al baseline por los tests nuevos de Sem 2.

### 5.2 Analyzer
```
flutter analyze
```
0 warnings nuevos vs. baseline 394 issues.

### 5.3 Git
```
git add ...
git commit -m "refactor(presence): PresenceViewModel + DI wiring + Sem 2 close"
gh pr create ...
gh pr merge ...
git tag refactor-sem2-done
git push origin refactor-sem2-done
```

### 5.4 Entregables de documentación
- `memory/project_refactor_sem2_done.md` — memoria de cierre
- `docs/dev/refactor-arch-2026-q2/03-semana-3-native-bridge.md` — borrador Sem 3

---

## Archivos afectados

| Archivo | Tipo | Cambio |
|---------|------|--------|
| `lib/contexts/presence/presentation/view_models/presence_view_model.dart` | Nuevo | ViewModel sin widget |
| `lib/app/di/modules/presence_module.dart` | Modificado | placeholder → registro completo |
| `test/contexts/presence/presence_integration_test.dart` | Nuevo | ciclo completo de transiciones |

**Archivos de producción activa no modificados** (criterio de Sem 2): `StatusService`,
`SilentFunctionalityCoordinator`, `in_circle_view.dart`, ni ningún widget.

---

## Criterios de done

| Criterio | Verificación |
|----------|-------------|
| `PresenceViewModel` registrado en DI | `registerPresenceModule` compila, app arranca |
| App funciona idéntico al baseline | Smoke test 6 pasos en device físico |
| `flutter test` en verde | Salida del comando |
| `flutter analyze` 0 warnings nuevos | Salida del comando vs. baseline 394 |
| Test de integración ciclo completo verde | `flutter test test/contexts/presence/presence_integration_test.dart` |
| Tag `refactor-sem2-done` en remoto | `git tag -l refactor-sem2-done` |
| Memoria de cierre publicada | Archivo en `memory/` |
| Borrador Sem 3 publicado | Archivo en `docs/dev/refactor-arch-2026-q2/` |

---

**Pendiente post-Sem 2 (no bloquea el cierre):**
- `fake_cloud_firestore` en dev_dependencies para activar los 2 tests en skip de
  `FirestorePresencePublisher`. Proponer al desarrollador al inicio de Sem 3.
- `PresenceViewModel.init()` debe llamarse post-login. Se documenta como deuda; el
  call real se hace en Sem 5 cuando la UI consume el VM.
