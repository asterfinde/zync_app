# Sem 7 · Día 3 (PR C) — `notification_status_selector.dart` (Opus)

> **Estado:** Listo para ejecutar (PA95C)
> **Confianza:** 92%
> **Modelo:** ⚠️ Opus 4.7 — obligatorio (486 líneas, lógica de BN + Silent compleja)
> **Rama:** `refactor/sem7-notification-selector`
> **Duración estimada:** 2–3h
> **Prerrequisito:** PR B (Día 2) mergeado · `main` verde · árbol limpio
> **Smoke test:** obligatorio antes de PR D (Día 4)

---

## Problema

`notification_status_selector.dart` (486 líneas) es el modal que aparece en la notificación persistente cuando el usuario recibe un estado BN (Background Notification). Tiene dos defectos estructurales:

1. **Emojis hardcodeados:** usa `StatusType.fallbackPredefined` — una lista estática que no refleja los emojis personalizados del círculo. El modal siempre muestra los mismos 5 emojis de fábrica.

2. **Update por vía estática:** llama a `StatusService.updateUserStatus()` directamente, bypasseando la state machine y el `DomainEventBus`.

---

## Alcance — qué cambia, qué NO cambia

| | Cambia | No cambia |
|--|--------|-----------|
| Fuente de emojis | `fallbackPredefined` → `EmojiService.getAllEmojisForCircle(circleId)` | ✅ Lógica de qué emojis resaltar (activo/BN) |
| Caller de update | `StatusService.updateUserStatus()` → `sl<SetManualStatus>()` | ✅ Lógica de cuándo mostrar/ocultar el modal |
| Estado visual | Sin cambios | ✅ Layout, animaciones, colores |
| Comportamiento BN vs Silent | Sin cambios | ✅ No se toca la lógica de modos |

---

## Paso 0 — Prerequisito

```bash
git status
git pull origin main
git checkout -b refactor/sem7-notification-selector
```

---

## Paso 1 — Leer el archivo completo

```dart
// Leer lib/widgets/notification_status_selector.dart completo (486 líneas)
```

Catalogar:
- Líneas donde aparece `StatusType.fallbackPredefined` (fuente de emojis).
- Líneas donde aparece `StatusService.updateUserStatus`.
- Cómo se inicializa el widget: parámetros recibidos, estado que mantiene.
- Si ya recibe `circleId` como parámetro o si lo obtiene internamente.

---

## Paso 2 — Verificar firma de `EmojiService.getAllEmojisForCircle`

```bash
grep -n "getAllEmojisForCircle" lib/core/services/emoji_service.dart
```

Confirmar:
- Tipo de retorno (probablemente `Future<List<StatusType>>` o `Future<List<UserStatus>>`).
- Parámetros requeridos.
- Si es async o síncrono.

---

## Paso 3 — Identificar cómo se obtiene `circleId`

Opciones en orden de preferencia:
1. Ya viene como parámetro del widget → usarlo directamente.
2. No viene → leerlo de `sl<KvStore>().getString(StorageKeys.circleId)`.

Si `circleId` es null: mostrar `StatusType.fallbackPredefined` como fallback (mantiene funcionalidad mínima; no romper el modal).

---

## Paso 4 — Reemplazar la fuente de emojis

**Antes (en `initState` o `build`):**
```dart
final emojis = StatusType.fallbackPredefined;
```

**Después:**
```dart
// En initState / estado async del widget
Future<void> _loadEmojis() async {
  final circleId = sl<KvStore>().getString(StorageKeys.circleId);
  if (circleId == null) {
    setState(() => _emojis = StatusType.fallbackPredefined);
    return;
  }
  final emojis = await EmojiService.getAllEmojisForCircle(circleId);
  if (mounted) setState(() => _emojis = emojis);
}
```

El widget pasa de usar una lista estática a una lista cargada async. El estado de carga (loading spinner) debe ser invisible al usuario o usar la lista fallback hasta que cargue — NO bloquear el modal.

---

## Paso 5 — Reemplazar el caller de update

Mismo patrón que PR B:

```dart
// Antes
await StatusService.updateUserStatus(statusId, userId, circleId);

// Después
await sl<SetManualStatus>().call(
  SetManualStatusParams(
    statusId: statusId,
    userId: userId,
    circleId: circleId,
  ),
);
```

---

## Paso 6 — Actualizar imports

- Agregar: `emoji_service.dart`, `set_manual_status.dart`, `injection_container.dart`, `native_keys.dart`.
- Eliminar: `status_service.dart` y el import de `StatusType` si solo se usaba para `fallbackPredefined` y el tipo ya está disponible por otra vía.

---

## Paso 7 — `flutter analyze` + commit

```bash
flutter analyze lib/widgets/notification_status_selector.dart
# Esperar: 0 errores nuevos

git add lib/widgets/notification_status_selector.dart
git commit -m "refactor(presence): notification_status_selector → real circle emojis + SetManualStatus"
```

---

## Paso 8 — Smoke test en device (obligatorio antes de PR D)

| Paso | Escenario | Criterio de PASS |
|------|-----------|------------------|
| 1 | Login → Circle visible | ✅ App funcional |
| 2 | Otro miembro envía estado BN | Modal de barra aparece |
| 3 | Modal muestra emojis | Lista incluye emojis personalizados del círculo (no solo los 5 predefinidos) |
| 4 | Seleccionar emoji en modal | Estado actualiza en Firestore · miembros ven cambio |
| 5 | Activar Silent Mode → otro miembro envía BN | Modal sigue apareciendo y funcionando |
| 6 | Seleccionar emoji durante Silent | Estado actualiza sin romper el modo |

Si algún paso falla: **NO continuar a PR D**. Diagnosticar y corregir primero.

---

## Paso 9 — PR → merge → cleanup (solo tras smoke test PASS)

```bash
gh pr create --title "refactor(presence): notification_status_selector → real emojis + SetManualStatus" \
  --body "Reemplaza StatusType.fallbackPredefined por EmojiService.getAllEmojisForCircle(circleId). \
Reemplaza StatusService.updateUserStatus() por sl<SetManualStatus>(). \
El modal de notificación BN ahora muestra y usa los emojis reales del círculo. \
Smoke test PASS en device físico."

# Tras merge:
git checkout main && git pull origin main
git branch -d refactor/sem7-notification-selector
```

---

## Protocolo de caminos negativos

| Camino | Acción | ¿Reversible? |
|--------|--------|--------------|
| `getAllEmojisForCircle` falla por red | Mostrar `StatusType.fallbackPredefined` como fallback — log, no crash | ✅ Best-effort |
| `circleId` null | Mostrar fallback predefined — modal funciona con lista básica | ✅ Degradación graceful |
| `SetManualStatus` falla | `Left(Failure)` → `debugPrint` · modal se cierra normalmente | ✅ No destructivo |
| Widget desmontado antes de que `getAllEmojisForCircle` complete | Guard `if (mounted)` antes de `setState` | ✅ Estándar Flutter |

Ningún camino negativo ejecuta `signOut` ni acciones irreversibles.

---

## Flujos impactados

| Flujo | Antes | Después | Riesgo |
|-------|-------|---------|--------|
| Modal BN recibe notificación | Muestra 5 emojis hardcodeados | Muestra emojis del círculo | ✅ Mejora funcional |
| Usuario selecciona emoji en modal BN | `StatusService` estático | `SetManualStatus` con state machine | ✅ Mejora arquitectural |
| Silent Mode activo + BN llega | Modal aparece (comportamiento no cambia) | Igual | ✅ Sin cambio |
| `circleId` no disponible en frío | Lista hardcodeada | Mismo fallback que antes | ✅ Sin regresión |

---

## Criterio de done

- [ ] `grep -rn "fallbackPredefined" lib/widgets/notification_status_selector.dart` → 0 resultados
- [ ] `grep -rn "StatusService.updateUserStatus" lib/widgets/notification_status_selector.dart` → 0 resultados
- [ ] Smoke test 6 pasos PASS en device físico
- [ ] `flutter analyze` → 0 errores nuevos
- [ ] Commit limpio · PR mergeado · ramas eliminadas · `git pull origin main`
- [ ] Continuar con Día 4 (PR D)

---

## Por qué Opus en este PR

`notification_status_selector.dart` tiene:
- 486 líneas de lógica de estado UI compleja (BN vs Silent vs Normal).
- Estado async que se carga al montar el widget y puede actualizarse mientras el modal está abierto.
- Interacción con el lifecycle de la notificación nativa (el widget puede desmontarse en cualquier momento).
- Dos cambios estructurales simultáneos (fuente de emojis + caller de update) que interactúan.

Sonnet puede ejecutar el cambio pero el riesgo de perder un caso edge en el manejo de estado es mayor. Opus reduce ese riesgo.
