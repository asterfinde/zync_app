# PA95C — Re-autenticación Proactiva en Resume

> **Confianza:** 97%
> **Archivo afectado:** `lib/main.dart` — un solo bloque (líneas ~303-316)
> **Rama:** `fix/proactive-reauth-on-resume`
> **Modelo:** Sonnet 4.6
> **Prerequisito:** main en `4f0caee`, árbol limpio

---

## Objetivo

Convertir el refresh del token Firebase de **reactivo** (se dispara cuando el primer write falla)
a **proactivo** (se dispara en `onResume` antes de que el usuario toque nada), condicionado
a que el background haya durado > 50 minutos.

---

## Estado actual vs. estado objetivo

| | Actual | Objetivo |
|--|--------|----------|
| Threshold `tokenLikelyInvalid` | > 5 min | > 50 min |
| `_refreshTokenWithRetry` llamado | **en todo resume** (incluso tras 30 s de background) | solo cuando background > 50 min |
| Network call en resume corto | `getIdToken(true)` siempre → red → 200-500 ms innecesarios | ninguno — token en caché Firebase SDK |
| Network call en resume largo | ✅ ya existe | ✅ sin cambio de mecanismo |

---

## Hallazgo clave (pre-auditoría)

`_refreshTokenWithRetry` ya hace exactamente lo que el diagrama propone — sin signOut:

```dart
// main.dart línea 188
user.getIdToken(true)           // getIdToken(forceRefresh=true) → nuevo token
  .then((_) async {
    StatusService.tokenLikelyInvalid = false;
    await FirebaseFirestore.instance.disableNetwork();
    await FirebaseFirestore.instance.enableNetwork(); // Firestore reconectado
  })
  .catchError((_) => _refreshTokenWithRetry(...));  // retry 0→5→15→30s
// Si todos fallan → _trySilentReauthFromKeystore() → signIn silencioso desde Keystore
```

El problema actual no es que falte el mecanismo — es que se ejecuta en **todo resume**,
incluso tras 10 segundos de background donde el token tiene 58 minutos de vida útil restantes.
Eso genera una llamada de red innecesaria (`securetoken.googleapis.com`) cada vez que el
usuario cambia de app.

---

## Call graph (estado actual → cambio)

```
AppLifecycleState.resumed
  │
  ├─ bg != null && diff > 5min  →  tokenLikelyInvalid = true       ← cambiar a 50min
  │
  ├─ _backgroundedAt = null
  │
  └─ resumeUser != null  →  _refreshTokenWithRetry(user)           ← condicionar a >50min
       │
       ├─ getIdToken(true) OK  →  tokenLikelyInvalid = false + Firestore reconect
       ├─ falla (red)          →  retry 5s → 15s → 30s
       └─ reintentos agotados  →  _trySilentReauthFromKeystore()
            ├─ Keystore vacío       →  log + return (sesión intacta)
            ├─ signIn OK            →  tokenLikelyInvalid = false
            └─ signIn falla (red)   →  log + return (sesión intacta)
                                       tokenLikelyInvalid queda true
                                       → primer write → getIdToken(force) → chain normal
```

---

## Cambio propuesto — `lib/main.dart` líneas ~303-316

**Antes:**
```dart
final bg = _backgroundedAt;
if (bg != null && DateTime.now().difference(bg) > const Duration(minutes: 5)) {
  StatusService.tokenLikelyInvalid = true;
  debugPrint('[App] ⚠️ Background > 5min — próximo write usará forceRefresh=true');
}
_backgroundedAt = null;

final resumeUser = FirebaseAuth.instance.currentUser;
if (resumeUser != null) {
  _refreshTokenWithRetry(resumeUser, context: 'resume');
}
```

**Después:**
```dart
final bg = _backgroundedAt;
_backgroundedAt = null;

final bgDuration = bg != null ? DateTime.now().difference(bg) : Duration.zero;
final longBackground = bgDuration > const Duration(minutes: 50);

if (longBackground) {
  StatusService.tokenLikelyInvalid = true;
  debugPrint('[App] ⚠️ Background > 50min (${bgDuration.inMinutes}min) — proactive token refresh');
}

final resumeUser = FirebaseAuth.instance.currentUser;
if (resumeUser != null && longBackground) {
  _refreshTokenWithRetry(resumeUser, context: 'resume-${bgDuration.inMinutes}min');
}
```

**Diferencias:**
1. Umbral: `5min` → `50min`
2. `_refreshTokenWithRetry` condicionado: solo si `longBackground == true`
3. `_backgroundedAt = null` sube una línea (antes de usar `bg` en `bgDuration`) → misma semántica
4. Log más informativo: incluye los minutos reales de background

---

## Protocolo de caminos negativos (CLAUDE.md §2)

| Camino | Acción | ¿Reversible? | ¿Correcto? |
|--------|--------|--------------|------------|
| `bgDuration ≤ 50min` | no llama `_refreshTokenWithRetry` | — | ✅ Token válido, sin red |
| `getIdToken(true)` falla por red (Doze) | retry 5→15→30s → `_trySilentReauthFromKeystore()` | sí | ✅ Best-effort, no destructivo |
| Keystore vacío en `_trySilentReauthFromKeystore` | log + return | — | ✅ Sesión Firebase intacta |
| `signIn` desde Keystore falla por red | log + return, `tokenLikelyInvalid` queda `true` | — | ✅ Primer write reintentará |
| `signIn` desde Keystore falla por auth | log + return | — | ✅ `_handleSessionExpired()` se activa en el primer write confirmado |

Ningún camino negativo en esta función ejecuta acciones irreversibles (`signOut`, `clearCredentials`).
Las acciones irreversibles permanecen exclusivamente en `StatusService._handleSessionExpired()`
cuando un write **confirmado** (no de red) falla — invariante existente, no modificado.

---

## Flujos impactados

| Flujo | Antes | Después | Riesgo |
|-------|-------|---------|--------|
| Resume corto (< 50min) — Normal | `getIdToken(true)` → red | ninguna llamada de red | ✅ Mejora performance |
| Resume corto (< 50min) — Silent | igual | igual | ✅ Ninguno |
| Resume largo (> 50min) — Normal | ✅ ya funcionaba (T6 PASS) | igual mecanismo | ✅ Sin cambio |
| Resume largo (> 50min) — Silent | ✅ ya funcionaba (T5 PASS) | igual mecanismo | ✅ Sin cambio |
| Primer write post-resume corto | `tokenLikelyInvalid=false` → `getIdToken(false)` (caché) | igual | ✅ Sin cambio |
| Primer write post-resume largo | `tokenLikelyInvalid=true` → `getIdToken(true)` como safety net | igual | ✅ Sin cambio |

**Flujo que NO cambia:** `StatusService.updateUserStatus` y toda su cadena de manejo de token — permanece intacto como safety net de segundo nivel.

---

## Smoke test post-implementación

Ejecutar los tests soaked que cubren el escenario objetivo:

| Test | Escenario | Criterio |
|------|-----------|----------|
| T5 | Silent Mode > 1h → reabre → emoji | Firestore actualiza, sin SnackBar rojo |
| T6 | Normal Mode > 1h → reabre → emoji | Igual que T5 |
| T7 | > 1h → reabre → tap antes de que refresh complete | ~300ms extra, Firestore actualiza |
| T4 | Interacciones rápidas < 50min | Sin degradación — **NO** debe haber llamada de red en resume |

T4 es el test de regresión clave: confirma que resume corto ya no genera llamada de red innecesaria.

---

## Criterio de done

- [ ] `lib/main.dart` modificado — solo las líneas del bloque `AppLifecycleState.resumed`
- [ ] `flutter analyze` → 0 errores nuevos
- [ ] T5, T6, T7 PASS en dispositivo físico
- [ ] T4 PASS (sin degradación en resume corto)
- [ ] Commit en rama `fix/proactive-reauth-on-resume`
- [ ] PR → merge → rama eliminada → pull en main

---

## Lo que NO se toca

- `_refreshTokenWithRetry()` — lógica interna sin cambios
- `_trySilentReauthFromKeystore()` — sin cambios
- `StatusService._trySilentReauth()` — sin cambios
- `StatusService.updateUserStatus()` — sin cambios
- `status_service.dart` — sin cambios
- Cualquier archivo fuera de `main.dart`
