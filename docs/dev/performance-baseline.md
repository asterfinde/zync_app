# Performance Baseline — Nunakin App

> Fecha de medición: 2026-05-27
> Tag de referencia: `refactor-sem5-done` (commit `d2cb2a7`)
> Dispositivo: Samsung Galaxy (ID: R58W315389R) — Android
> Modo de medición: debug build con `flutter run` + logcat `[PERF]` filter
> Instrumentación: `debugPrint('[PERF] ...')` con `kDebugMode` guard — no-op en release

---

## Resultados

### Cold Start

**Definición:** app completamente cerrada (forzar detención) → grid de miembros con emojis visible.

| Run | cold_start_begin | circle_loaded | Delta |
|-----|-----------------|---------------|-------|
| #1 (PID 27170) | 1779912783099 | 1779912789508 | **6409ms** |
| #2 (PID 28808) | 1779913077297 | 1779913083787 | **6490ms** |
| #3 (PID 29217) | 1779913125359 | 1779913131587 | **6228ms** |
| #4 (PID 29471) | 1779913159297 | 1779913165387 | **6090ms** |
| **Promedio** | — | — | **6304ms (~6.3s)** |

> **Nota release:** debug mode incluye overhead del debugger (~30-40%). En release build se espera ~3.8–4.4s.

---

### App Resume

**Definición:** app en background >5 min → UI retoma estado correcto.

| Caso | Comportamiento | Tiempo |
|------|---------------|--------|
| Background < 50 min | Token Firebase válido en caché — sin llamada de red | < 1s (subjetivo) |
| Background > 50 min | Token refresh + reconexión Firestore | No medido (requiere instrumentación adicional) |

> **Medición del 2026-05-27:** `resume_begin` capturado (15:35:36, >5 min background). Sin log de fin — `circle_loaded` no se dispara en resume porque el widget ya está inicializado. La UI retomó estado visualmente en <1s (debug mode).
>
> **Deuda de instrumentación:** agregar `[PERF] resume_ready` tras completar reconexión Firestore para medir el caso >50 min background.

---

### Login → Círculo

**Definición:** tap en "Entrar" → grid de miembros con emojis visible.

| Run | login_begin | circle_loaded | Delta |
|-----|------------|---------------|-------|
| #1 (medición limpia) | 1779914288837 | 1779914296113 | **7276ms (~7.3s)** |

> n=1 — suficiente para baseline de referencia. Medir nuevamente en Sem 10 con más repeticiones.
>
> **Nota release:** se espera ~4.4–5.1s en release build.

---

## Comparación vs mvp-baseline-20260506

No hay números instrumentados del baseline anterior (tag `mvp-baseline-20260506`, commit `9c3518e`). La comparación es subjetiva basada en observación durante pruebas manuales de los PRs #141–#200.

| Métrica | mvp-baseline (subjetivo) | Sem 5 done (medido) |
|---------|--------------------------|---------------------|
| Cold start | ~8-10s (estimado) | **6304ms** |
| Resume <50min | Inmediato | < 1s ✅ |
| Login→Círculo | ~8-12s (estimado) | **7276ms** |

> La reducción en cold start se atribuye principalmente a: cache-first en `MemberDataRepository` (Sem 5), eliminación de race con `disableNetwork` (PR #200), y DI modular (Sem 1).

---

## Referencia de instrumentación

Los logs `[PERF]` están en 3 archivos (solo activos en debug mode):

| Archivo | Log | Evento |
|---------|-----|--------|
| `lib/main.dart:41` | `cold_start_begin` | `main()` arranca |
| `lib/main.dart:303` | `resume_begin` | `AppLifecycleState.resumed` |
| `lib/contexts/identity/presentation/pages/auth_final_page.dart:83` | `login_begin` | tap "Entrar" |
| `lib/features/circle/presentation/widgets/in_circle_view.dart:274` | `circle_loaded` | `_loadFromCache()` con datos |

**Comando para capturar en tiempo real:**
```powershell
adb -s R58W315389R logcat -c
adb -s R58W315389R logcat | Select-String "\[PERF\]"
```

---

## Próxima medición

**Cuándo:** Sem 10 (Launch Readiness), con release build.
**Metas:**

| Métrica | Baseline debug | Meta release Sem 10 |
|---------|---------------|---------------------|
| Cold start | 6304ms | < 4000ms |
| Resume <50min | < 1s | < 1s |
| Login→Círculo | 7276ms | < 5000ms |
