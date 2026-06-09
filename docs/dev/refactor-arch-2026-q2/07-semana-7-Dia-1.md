# Sem 7 · Día 1 (PR A) — Eliminar sync prematuro en `main.dart`

> **Estado:** Listo para ejecutar (PA95C)
> **Confianza:** 99%
> **Modelo:** Sonnet 4.6
> **Rama:** `refactor/sem7-emoji-cache-race`
> **Duración estimada:** 30 min
> **Prerrequisito:** PR #218 (NkDialog) mergeado · `main` verde · árbol limpio

---

## Problema

`lib/main.dart` llama a `EmojiCacheService.syncEmojisToNativeCache()` durante la inicialización de la app, antes de que Firebase Auth haya completado y antes de que el `circleId` del usuario sea conocido.

Cuando ese sync se ejecuta sin círculo activo, escribe `configured_zone_types = []` en las SharedPrefs nativas. `EmojiDialogActivity.kt` lee esa lista al abrirse — y si está vacía, no muestra las zonas configuradas del círculo.

Este es el **cold-start race** documentado en los bugs de la fase 4/5.

---

## Causa raíz confirmada

`InCircleView.initState()` ya llama al mismo `EmojiCacheService.syncEmojisToNativeCache()` **después** de que:
1. Firebase Auth ha completado (el widget solo se monta si el usuario está autenticado).
2. El `Circle` object está disponible (se pasa como parámetro al widget).

La llamada en `main.dart` es redundante y nociva.

---

## Call graph (estado actual)

```
main.dart::_initializeServices()
  │
  ├─ EmojiCacheService.syncEmojisToNativeCache()   ← ELIMINAR
  │     │
  │     └─ SharedPrefs.setStringList("flutter.configured_zone_types", [...])
  │           Auth puede ser null aquí → writes [] al nativo
  │
  └─ ... (resto de init)

InCircleView.initState()                            ← KEEPER
  │
  └─ EmojiCacheService.syncEmojisToNativeCache()
        Auth garantizado ✅ · Circle disponible ✅
```

---

## Paso 0 — Prerequisito

```bash
git status          # debe estar limpio
git pull origin main
git checkout -b refactor/sem7-emoji-cache-race
```

---

## Paso 1 — Identificar la línea exacta

```bash
grep -n "syncEmojisToNativeCache" lib/main.dart
```

Debería aparecer una línea en la función `_initializeServices()` o similar (aprox. línea 108 según último análisis).

---

## Paso 2 — Eliminar la llamada

**Antes:**
```dart
// En _initializeServices() o initState() de _MyAppState
await EmojiCacheService.syncEmojisToNativeCache();
```

**Después:** línea eliminada.

Si la línea tiene un comentario explicativo, eliminar el comentario también. Si hay un `try/catch` que solo envuelve esa llamada, eliminar el `try/catch` completo.

**Lo que NO se elimina:**
- El import de `EmojiCacheService` si tiene otros usos en `main.dart`.
- Cualquier otra inicialización en la misma función.

---

## Paso 3 — Verificar que el import no queda huérfano

```bash
grep -n "EmojiCacheService" lib/main.dart
```

Si solo aparecía en la línea eliminada → eliminar el import. Si hay otros usos → mantener el import.

---

## Paso 4 — `flutter analyze` + commit

```bash
flutter analyze lib/main.dart
# Esperar: 0 errores nuevos

git add lib/main.dart
git commit -m "refactor(presence): remove premature emoji sync from main.dart init"
```

---

## Paso 5 — PR → merge → cleanup

```bash
gh pr create --title "refactor(presence): remove premature emoji sync from main.dart" \
  --body "Elimina EmojiCacheService.syncEmojisToNativeCache() de main.dart init. \
La misma llamada ya existe en InCircleView.initState() con Auth y Circle garantizados. \
Resuelve cold-start race que escribía configured_zone_types=[] antes de conocer el círculo."

# Tras merge:
git checkout main && git pull origin main
git branch -d refactor/sem7-emoji-cache-race
git push origin --delete refactor/sem7-emoji-cache-race
```

---

## Protocolo de caminos negativos

| Camino | Acción | ¿Reversible? |
|--------|--------|--------------|
| `InCircleView` no se monta (usuario sin círculo) | `syncEmojisToNativeCache` no se llama → `configured_zone_types` queda del último sync válido | ✅ Best-effort |
| Auth completa pero Circle aún no cargó | El sync dentro de `initState` espera el `Circle` object (parámetro) — no puede ejecutarse antes | ✅ Garantizado |
| Primer cold start sin datos en prefs | `EmojiDialogActivity` muestra lista vacía (comportamiento sin cambio vs. antes del bug original) | ✅ Aceptable |

Ningún camino negativo ejecuta `signOut`, `clearCredentials` ni operaciones irreversibles.

---

## Flujos impactados

| Flujo | Antes | Después | Riesgo |
|-------|-------|---------|--------|
| Cold start → App sin círculo | `syncEmojisToNativeCache()` → puede escribir `[]` | No ejecuta sync | ✅ Mejora |
| Cold start → App con círculo | sync prematuro + sync en `initState` (doble) | Solo sync en `initState` | ✅ Elimina redundancia |
| `EmojiDialogActivity` al abrir | puede leer `[]` si sync prematuro corrió primero | Lee datos del sync en `initState` (correcto) | ✅ Corrección directa del bug |

---

## Criterio de done

- [ ] `grep -n "syncEmojisToNativeCache" lib/main.dart` → 0 resultados
- [ ] `flutter analyze lib/main.dart` → 0 errores nuevos
- [ ] Commit limpio en `refactor/sem7-emoji-cache-race`
- [ ] PR mergeado · ramas local y remota eliminadas · `git pull origin main`
- [ ] Continuar con Día 2 (PR B)
