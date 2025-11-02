# Fase 1 - Instrucciones de Prueba
**Fecha**: 2025-11-02  
**Objetivo**: Validar keep-alive nativo + persistencia SQLite Room

---

## 🎯 Qué Hemos Implementado

### ✅ Componentes Creados

1. **`UserStateEntity.kt`** - Entidad Room para SQLite
2. **`UserStateDao.kt`** - DAO con operaciones de base de datos
3. **`AppDatabase.kt`** - Room Database singleton
4. **`NativeStateManager.kt`** - Servicio de persistencia nativo
5. **`MainActivity.kt`** (modificado) - Keep-alive nativo en `onPause()`
6. **`NativeStateBridge.dart`** - Servicio Flutter para comunicación
7. **`main_minimal_test.dart`** (modificado) - Sincronización con Kotlin

### 🔄 Cambios Clave

#### Antes (Flutter manejaba keep-alive):
```dart
@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (state == AppLifecycleState.paused) {
    KeepAliveService.start(); // ❌ Muy tarde
  }
}
```

#### Después (Kotlin maneja keep-alive):
```kotlin
override fun onPause() {
    super.onPause()
    Log.d(TAG, "🟢 onPause() - Iniciando keep-alive NATIVO")
    KeepAliveService.start(this) // ✅ INMEDIATO
    
    // Guardar estado en SQLite
    currentUserId?.let {
        lifecycleScope.launch {
            NativeStateManager.saveUserState(this@MainActivity, it)
        }
    }
}
```

---

## 📱 Pasos de Prueba

### Prerequisito: Build Completado
El comando `flutter run -t lib/main_minimal_test.dart` debe haber completado y la app debe estar corriendo.

---

### 🧪 PRUEBA 1: Keep-Alive Nativo (CRÍTICO)

**Objetivo**: Verificar que el servicio keep-alive inicia INMEDIATAMENTE al minimizar

#### Pasos:
1. **Abrir terminal de logcat**:
   ```bash
   adb logcat | grep -E "(MainActivity|KeepAliveService|🟢|❌)" --color=always
   ```

2. **Minimizar la app** (swipe izquierda desde borde)

3. **Verificar logs** - Deberías ver:
   ```
   🟢 onPause() - Iniciando keep-alive NATIVO
   KeepAliveService: Servicio iniciado
   ```

4. **Esperar 5 segundos** (Android intenta matar proceso)

5. **Swipe arriba** (recientes) y seleccionar Zync

#### ✅ Resultado Esperado:
- App **NO reinicia** (sin "onCreate() - Primer lanzamiento")
- App **resume instantáneamente** (<500ms)
- Logs muestran: `onResume() - App retomada`

#### ❌ Fallo:
- Logs muestran: `onCreate() - Primer lanzamiento`
- App muestra splash "Cargando..." por 5s
- Significa: Android mató el proceso (keep-alive falló)

---

### 🧪 PRUEBA 2: Persistencia SQLite Room

**Objetivo**: Verificar que userId se guarda en SQLite nativo

#### Pasos:
1. **Login en la app** (asegúrate de estar autenticado)

2. **Verificar sincronización Flutter → Kotlin**:
   ```bash
   adb logcat | grep "NativeStateBridge" --color=always
   ```
   
   Deberías ver:
   ```
   [NativeStateBridge] 📤 Enviando a Kotlin: <userId>
   [NativeStateBridge] ✅ Kotlin actualizado
   ```

3. **Verificar guardado en SQLite**:
   ```bash
   adb logcat | grep "NativeStateManager" --color=always
   ```
   
   Deberías ver:
   ```
   NativeStateManager: ✅ Estado guardado en <X>ms: <userId>
   ```

4. **Minimizar y maximizar** (swipe izquierda → swipe arriba)

5. **Verificar restauración**:
   ```bash
   adb logcat | grep "MainActivity|NativeState" --color=always
   ```
   
   Deberías ver:
   ```
   MainActivity: ✅ Estado nativo encontrado: <userId>
   ```

#### ✅ Resultado Esperado:
- userId se guarda en SQLite en <10ms
- Estado persiste incluso si Android mata proceso
- Restauración instantánea desde SQLite

#### ❌ Fallo:
- No se ve log de "Estado guardado"
- userId es null al restaurar
- Significa: Sincronización Flutter → Kotlin falló

---

### 🧪 PRUEBA 3: Integración Completa

**Objetivo**: Simular escenario real de usuario

#### Escenario:
Usuario hace login → minimiza app → Android mata proceso → regresa a app

#### Pasos:
1. **Login en la app**
   - Verificar que aparece home screen con círculos

2. **Minimizar** (swipe izquierda)
   - Verificar logs: keep-alive inicia
   - Verificar logs: estado guardado en SQLite

3. **Esperar 10 segundos**
   - Android debería intentar matar proceso
   - Keep-alive debería mantener vivo

4. **Forzar kill del proceso** (para probar worst case):
   ```bash
   adb shell am force-stop com.datainfers.zync
   ```

5. **Re-abrir app desde launcher**
   - Click en ícono Zync

#### ✅ Resultado Esperado:
- Después de minimizar: app regresa instantáneamente
- Después de force-stop: app restaura userId desde SQLite
- Login NO es necesario de nuevo
- Total time to resume: <1 segundo

#### ❌ Fallo:
- App pide login de nuevo
- Estado perdido
- Significa: Persistencia SQLite no funciona

---

## 📊 Métricas a Medir

### Time to Resume (onPause → onResume)
```bash
adb logcat | grep -E "onPause|onResume" --color=always
```

**Target**: <500ms  
**Medición**: Diferencia entre timestamps

### Persistencia SQLite
```bash
adb logcat | grep "Estado guardado" --color=always
```

**Target**: <10ms  
**Medición**: Valor en log "guardado en Xms"

### Supervivencia de Proceso
```bash
adb logcat | grep "onCreate" --color=always
```

**Target**: NO ver "Primer lanzamiento"  
**Medición**: Ausencia de log después de minimizar

---

## 🐛 Debugging

### Si Keep-Alive NO inicia:
```bash
# Verificar que KeepAliveService está registrado
adb shell dumpsys activity services | grep KeepAlive

# Verificar permisos
adb shell dumpsys package com.datainfers.zync | grep FOREGROUND_SERVICE
```

### Si SQLite NO persiste:
```bash
# Verificar base de datos creada
adb shell run-as com.datainfers.zync ls -la databases/

# Ver contenido de DB (requiere root o debuggable app)
adb shell run-as com.datainfers.zync sqlite3 databases/zync_database \
  "SELECT * FROM user_state;"
```

### Si Proceso es Matado:
```bash
# Ver memoria disponible
adb shell dumpsys meminfo com.datainfers.zync

# Ver prioridad de proceso
adb shell ps -A | grep zync
```

---

## ✅ Criterios de Éxito

| Criterio | Target | Medición |
|----------|--------|----------|
| Keep-alive inicia | Inmediato | Log "🟢 onPause()" |
| Persistencia SQLite | <10ms | Log "guardado en Xms" |
| Supervivencia proceso | >95% | Sin "Primer lanzamiento" |
| Time to Resume | <500ms | Diferencia timestamps |

---

## 🚀 Siguiente Paso

Si todas las pruebas pasan:
- ✅ **Fase 1 COMPLETADA**
- 🔄 Continuar con **Fase 2**: Integrar con app real (no test)

Si alguna prueba falla:
- 🐛 Debuggear usando comandos de la sección "Debugging"
- 📝 Reportar logs específicos del fallo
- 🔧 Ajustar código según el problema

---

## 📝 Template de Reporte

```markdown
## Resultado Fase 1

### PRUEBA 1: Keep-Alive Nativo
- ✅/❌ Keep-alive inicia en onPause()
- ✅/❌ Proceso sobrevive 10s
- ✅/❌ Resume instantáneo
- **Logs relevantes**: [pegar aquí]

### PRUEBA 2: Persistencia SQLite
- ✅/❌ userId sincronizado a Kotlin
- ✅/❌ Guardado en SQLite en <10ms
- ✅/❌ Restauración exitosa
- **Logs relevantes**: [pegar aquí]

### PRUEBA 3: Integración Completa
- ✅/❌ Escenario normal (minimizar/maximizar)
- ✅/❌ Escenario force-stop
- **Time to Resume**: XXXms
- **Logs relevantes**: [pegar aquí]

### Conclusión
- [ ] Fase 1 EXITOSA - Continuar con Fase 2
- [ ] Fase 1 CON PROBLEMAS - Debuggear [describir problema]
```
