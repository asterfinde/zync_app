# Sem 7 · Día 2 (PR B) — `quick_actions` + `widget_service` → `SetManualStatus`

> **Estado:** Listo para ejecutar (PA95C)
> **Confianza:** 95%
> **Modelo:** Sonnet 4.6
> **Rama:** `refactor/sem7-quick-actions-set-manual`
> **Duración estimada:** 1h
> **Prerrequisito:** PR A (Día 1) mergeado · `main` verde · árbol limpio

---

## Problema

`quick_actions_handler.dart` y `widget_service.dart` llaman a `StatusService.updateUserStatus()` directamente, bypasseando el use case `SetManualStatus` introducido en Sem 2. Esto significa que las Quick Actions del launcher y el home screen widget de Android no pasan por la state machine de presencia — no registran la transición como "manual", no emiten eventos al `DomainEventBus` y no respetan el guard de Silent Mode.

---

## Causa raíz

Ambos archivos son anteriores al refactor de Sems 1–6. Usan el servicio estático porque era el único punto de entrada de la arquitectura antigua.

`SetManualStatus` ya existe, ya está testeado y ya está registrado en DI:

```dart
// lib/app/di/modules/presence_module.dart
sl.registerFactory<SetManualStatus>(() => SetManualStatus(
  presenceRepository: sl(),
  firestorePublisher: sl(),
));
```

---

## Call graph (estado actual → objetivo)

**Antes:**
```
QuickActionsHandler.handleAction(statusId)
  └─ StatusService.updateUserStatus(statusId, userId, circleId)
       └─ Firestore write directo (sin state machine)

WidgetService.updateStatus(statusId)
  └─ StatusService.updateUserStatus(statusId, userId, circleId)
       └─ Firestore write directo (sin state machine)
```

**Después:**
```
QuickActionsHandler.handleAction(statusId)
  └─ sl<SetManualStatus>().call(statusId, userId, circleId)
       └─ PresenceRepository.setManualStatus()  ← state machine
            └─ DomainEventBus.publish()
            └─ FirestorePresencePublisher.publish()

WidgetService.updateStatus(statusId)
  └─ sl<SetManualStatus>().call(statusId, userId, circleId)
       └─ (mismo flujo)
```

---

## Paso 0 — Prerequisito

```bash
git status
git pull origin main
git checkout -b refactor/sem7-quick-actions-set-manual
```

---

## Paso 1 — Auditar `quick_actions_handler.dart`

```bash
grep -n "StatusService\|updateUserStatus" lib/quick_actions/quick_actions_handler.dart
```

Identificar:
1. Líneas donde se llama a `StatusService`.
2. Cómo se obtiene `userId` y `circleId` en el handler.
3. Si el handler ya tiene acceso a `sl()` o necesita importar `injection_container.dart`.

---

## Paso 2 — Auditar `widget_service.dart`

```bash
grep -n "StatusService\|updateUserStatus" lib/widgets/widget_service.dart
```

Mismo análisis que Paso 1.

---

## Paso 3 — Obtener `userId` y `circleId`

Ambos archivos necesitan `userId` y `circleId` para llamar a `SetManualStatus`.

**Fuentes disponibles (ya existen):**

| Dato | Fuente | API |
|------|--------|-----|
| `userId` | Firebase Auth (siempre disponible cuando se ejecuta la acción) | `FirebaseAuth.instance.currentUser?.uid` |
| `circleId` | KvStore | `sl<KvStore>().getString(StorageKeys.circleId)` |

Si `circleId` es null (usuario sin círculo): early return — no hay acción válida.

---

## Paso 4 — Reemplazar las llamadas

**En `quick_actions_handler.dart`:**

```dart
// Antes
await StatusService.updateUserStatus(statusId, userId, circleId);

// Después
final circleId = sl<KvStore>().getString(StorageKeys.circleId);
if (circleId == null) {
  debugPrint('[QuickActions] circleId nulo — sin acción');
  return;
}
await sl<SetManualStatus>().call(
  SetManualStatusParams(
    statusId: statusId,
    userId: userId,
    circleId: circleId,
  ),
);
```

Ajustar el nombre de los parámetros si `SetManualStatusParams` tiene una firma diferente (verificar en `lib/contexts/presence/application/use_cases/set_manual_status.dart`).

**En `widget_service.dart`:** mismo patrón.

---

## Paso 5 — Actualizar imports

En cada archivo modificado:
- Agregar import de `set_manual_status.dart` (use case).
- Agregar import de `injection_container.dart` si no existe.
- Agregar import de `native_keys.dart` (para `StorageKeys`).
- Eliminar import de `status_service.dart` si ya no tiene otros usos.

---

## Paso 6 — `flutter analyze` + commit

```bash
flutter analyze lib/quick_actions/quick_actions_handler.dart lib/widgets/widget_service.dart
# Esperar: 0 errores nuevos

git add lib/quick_actions/quick_actions_handler.dart lib/widgets/widget_service.dart
git commit -m "refactor(presence): migrate quick_actions and widget_service to SetManualStatus"
```

---

## Paso 7 — PR → merge → cleanup

```bash
gh pr create --title "refactor(presence): quick_actions + widget_service → SetManualStatus" \
  --body "Reemplaza StatusService.updateUserStatus() directo por sl<SetManualStatus>() en \
quick_actions_handler.dart y widget_service.dart. Ambos callers ahora pasan por la state \
machine de presencia (Sem 2) y emiten eventos al DomainEventBus."

# Tras merge:
git checkout main && git pull origin main
git branch -d refactor/sem7-quick-actions-set-manual
```

---

## Protocolo de caminos negativos

| Camino | Acción | ¿Reversible? |
|--------|--------|--------------|
| `circleId` es null (usuario sin círculo activo) | `return` temprano — sin actualización | ✅ Correcto |
| `userId` es null (sesión expirada) | `return` temprano — sin actualización | ✅ Correcto |
| `SetManualStatus` falla (red) | El use case retorna `Left(Failure)` — loguear con `debugPrint` · no hacer `signOut` | ✅ Best-effort |
| `sl<SetManualStatus>()` no registrado | `StateError` en debug — indicaría falla en DI setup | ✅ Detectado en dev |

---

## Flujos impactados

| Flujo | Antes | Después | Riesgo |
|-------|-------|---------|--------|
| Quick Action desde launcher | Firestore write directo | A través de state machine | ✅ Mejora (respeta Silent Mode) |
| Home screen widget tap | Igual | Igual | ✅ Mejora |
| Quick Action durante Silent Mode | StatusService no respeta guard de Silent | `SetManualStatus` con guard en state machine | ✅ Corrección |
| Quick Action con usuario sin círculo | `updateUserStatus` puede fallar silenciosamente | `return` temprano explícito | ✅ Más robusto |

---

## Criterio de done

- [ ] `grep -rn "StatusService.updateUserStatus" lib/quick_actions/` → 0 resultados
- [ ] `grep -rn "StatusService.updateUserStatus" lib/widgets/widget_service.dart` → 0 resultados
- [ ] `flutter analyze` → 0 errores nuevos en archivos modificados
- [ ] Commit limpio · PR mergeado · ramas eliminadas · `git pull origin main`
- [ ] Continuar con Día 3 (PR C — Opus)
