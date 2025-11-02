# Point 20 - Guía de Testing Cache-First

## Objetivo
Validar que la implementación Cache-First resuelve el problema de delay de 5 segundos cuando se maximiza la app.

## Performance Targets
- ✅ **Warm Resume**: <100ms (InMemoryCache)
- ✅ **Cold Start**: <500ms (PersistentCache)
- ✅ **Percepción usuario**: INSTANTÁNEO

---

## Test Plan

### Test 1: Warm Resume (App en Memoria)
**Scenario**: Usuario minimiza la app y la maximiza inmediatamente

**Steps**:
1. Abrir app y entrar a un círculo con varios miembros
2. Esperar a que se carguen todos los nicknames y estados
3. Minimizar la app (botón Home)
4. **INMEDIATAMENTE** maximizar la app (botón Recent Apps)
5. Observar en logs:
   ```
   ⚡ [InCircleView] Cargando desde cache...
   ✅ [InCircleView] Cache en memoria encontrado (X nicknames)
   ```

**Expected Result**:
- UI se muestra **INSTANTÁNEAMENTE** (<100ms)
- Todos los nicknames y estados visibles desde el frame 1
- No hay pantallas de loading
- Background refresh se ejecuta después

**Validation**:
- [ ] UI instantánea (0ms percibido)
- [ ] Datos correctos mostrados
- [ ] Logs confirman InMemoryCache hit

---

### Test 2: Cold Start (App Cerrada por Android)
**Scenario**: Android mata la app por falta de memoria

**Steps**:
1. Abrir app y entrar a un círculo
2. Esperar a que se carguen todos los datos
3. Minimizar la app
4. **IMPORTANTE**: Abrir 5-10 apps pesadas (YouTube, Chrome, Maps, etc.)
5. Android matará la app de Zync por memoria
6. Maximizar Zync desde Recent Apps
7. Observar en logs:
   ```
   ⚡ [InCircleView] Cargando desde cache...
   ❌ [InCircleView] No hay cache en memoria
   ✅ [InCircleView] Cache en disco encontrado (X nicknames)
   ```

**Expected Result**:
- UI se muestra en ~100-500ms (lectura de disco)
- Todos los nicknames y estados visibles desde cache
- No hay delay de 5 segundos
- Background refresh actualiza después

**Validation**:
- [ ] UI visible en <500ms
- [ ] Datos correctos desde disco
- [ ] Logs confirman PersistentCache hit
- [ ] No hay delay de 5s

---

### Test 3: Primera Apertura (Sin Cache)
**Scenario**: Primera vez que se entra al círculo o cache limpiado

**Steps**:
1. Limpiar app data (Settings → Apps → Zync → Clear Data)
2. Login y entrar a un círculo
3. Observar en logs:
   ```
   ⚡ [InCircleView] Cargando desde cache...
   ❌ [InCircleView] No hay cache disponible, esperando Firebase...
   🔄 [InCircleView] Refrescando datos en background...
   ✅ [InCircleView] Nicknames actualizados (X items)
   ```

**Expected Result**:
- UI muestra skeleton/loading inicialmente
- Firebase trae datos en 1-2 segundos
- Datos se guardan en ambos caches
- Próxima apertura será instantánea

**Validation**:
- [ ] Loading state visible
- [ ] Datos llegan desde Firebase
- [ ] Cache se guarda correctamente

---

### Test 4: Actualización en Tiempo Real
**Scenario**: Otro usuario cambia su estado mientras la app está abierta

**Steps**:
1. Abrir app en 2 dispositivos con el mismo círculo
2. En dispositivo A, cambiar estado de usuario
3. En dispositivo B, observar actualización
4. Verificar logs en dispositivo B:
   ```
   ✅ [InCircleView] Cache actualizado con nuevos estados
   ```

**Expected Result**:
- Dispositivo B ve el cambio en tiempo real
- Cache se actualiza automáticamente
- Próxima apertura mostrará estado actualizado

**Validation**:
- [ ] Actualización en tiempo real funciona
- [ ] Cache se actualiza con listener
- [ ] InMemoryCache y PersistentCache sincronizados

---

### Test 5: Verificación de Guardado en Dispose
**Scenario**: App se cierra y debe guardar estado

**Steps**:
1. Abrir app y entrar a círculo
2. Esperar a que cargue todo
3. Minimizar app
4. Verificar logs:
   ```
   💾 [InCircleView] Guardando estado a cache...
   ✅ [InCircleView] Estado guardado (X nicknames, Y members)
   ```

**Expected Result**:
- Estado se guarda automáticamente en dispose()
- Ambos caches actualizados
- Próxima apertura tendrá datos frescos

**Validation**:
- [ ] Logs confirman guardado
- [ ] Estado persistido correctamente

---

## Debugging Tools

### 1. Ver Logs en Tiempo Real
```bash
# Android
adb logcat -s flutter

# Filtrar solo cache logs
adb logcat -s flutter | grep -E "InCircleView|Cache|💾|✅|❌"
```

### 2. Verificar SharedPreferences
```bash
# Android - Ver archivos de cache
adb shell run-as com.example.zync_app ls -la /data/data/com.example.zync_app/shared_prefs/
adb shell run-as com.example.zync_app cat /data/data/com.example.zync_app/shared_prefs/FlutterSharedPreferences.xml
```

### 3. Forzar Cold Start
```bash
# Matar app manualmente
adb shell am force-stop com.example.zync_app

# Limpiar cache
adb shell pm clear com.example.zync_app
```

### 4. Medir Tiempos
Agregar temporalmente en `_loadFromCache()`:
```dart
final stopwatch = Stopwatch()..start();
// ... código ...
print('⏱️ Cache load time: ${stopwatch.elapsedMilliseconds}ms');
```

---

## Success Criteria

### Must Have (MVP)
- ✅ Warm Resume: <100ms (InMemoryCache)
- ✅ Cold Start: <500ms (PersistentCache)
- ✅ Actualización en tiempo real funciona
- ✅ No hay delay de 5 segundos

### Nice to Have (Optimizaciones)
- ⚡ Warm Resume: <50ms
- ⚡ Cold Start: <200ms
- ⚡ Cache TTL (Time To Live) para invalidar datos viejos
- ⚡ Cache compression para reducir espacio

---

## Troubleshooting

### Problema: UI sigue tardando 5 segundos
**Diagnóstico**:
1. Verificar logs - ¿Se está usando el cache?
2. Verificar `await PersistentCache.init()` en main.dart
3. Verificar que dispose() se llama y guarda cache

**Solución**:
- Revisar orden de inicialización en main.dart
- Verificar que `_loadFromCache()` se llama PRIMERO en initState

### Problema: Cache no se guarda
**Diagnóstico**:
1. Verificar logs de dispose()
2. Verificar SharedPreferences.init()

**Solución**:
- Asegurar que PersistentCache.init() se llama en main()
- Verificar permisos de escritura en Android

### Problema: Datos desactualizados en cache
**Diagnóstico**:
1. Verificar listener en `_listenToStatusChanges()`
2. Verificar actualización de caches en listener

**Solución**:
- Confirmar que listener actualiza ambos caches
- Verificar que `_refreshDataInBackground()` se ejecuta

---

## Next Steps

Después de validar estos tests:
1. ✅ Optimizar tiempos si no cumplen targets
2. ✅ Agregar métricas de performance (Firebase Performance Monitoring)
3. ✅ Implementar TTL (Time To Live) para cache
4. ✅ Agregar indicador visual cuando se actualiza desde cache vs Firebase
5. ✅ Documentar performance real en production

---

## References
- `docs/dev/point21-cache-first-strategy.md` - Estrategia completa
- `lib/core/cache/in_memory_cache.dart` - Cache en memoria
- `lib/core/cache/persistent_cache.dart` - Cache en disco
- `lib/features/circle/presentation/widgets/in_circle_view.dart` - Implementación
