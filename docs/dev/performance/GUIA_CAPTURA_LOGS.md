# 🎯 GUÍA RÁPIDA: Capturar Logs de Performance Min/Max

## ❌ Problema: El script automático no funciona

El script `capture_minmax_logs.sh` requiere que `flutter logs` esté disponible, pero eso no siempre funciona bien.

---

## ✅ SOLUCIÓN SIMPLE: Capturar desde Debug Console de VSCode

### **Método 1: Desde Debug Console (MÁS FÁCIL)**

#### **Paso 1: Ejecutar app en modo debug**
```bash
flutter run
```

#### **Paso 2: Reproducir el problema**
1. ✅ Haz login en la app
2. ✅ Ve a HomePage (lista de miembros del círculo)
3. ✅ **MINIMIZA la app** (botón Home de Android)
4. ✅ Espera **5-10 segundos**
5. ✅ **MAXIMIZA la app** (toca el ícono de Zync)

#### **Paso 3: Buscar logs en Debug Console**

En VSCode, ve a la pestaña **"Debug Console"** (abajo) y busca:

**LOGS CRÍTICOS A BUSCAR**:
```
📱 [App] Went to background - Guardando cache...
⏸️ [APP] Minimizada a las ...

(aquí minimizaste y esperaste)

📱 [App] Resumed from background - Midiendo performance...
▶️ [APP] Restaurada después de Xs
⏱️ [START] App Maximization
...
🔴 [END] App Maximization - XXXXms

📊 === REPORTE DE RENDIMIENTO ===
...
=================================
```

#### **Paso 4: Copiar TODO el output**

Desde `📱 [App] Went to background` hasta `=================================`

---

## ✅ MÉTODO 2: Captura Manual con grep (Terminal)

### **Paso 1: Terminal 1 - Ejecutar app**
```bash
flutter run
```

### **Paso 2: Terminal 2 - Filtrar logs en tiempo real**
```bash
# En OTRA terminal (nueva pestaña de VSCode)
adb logcat | grep -E "MainActivity|App\]|PerformanceTracker|START|END|📊|⏱️|Firebase|DI Init|Cache Init"
```

### **Paso 3: Reproducir problema** (igual que Método 1)
1. Minimizar app
2. Esperar 5 segundos
3. Maximizar app

### **Paso 4: Copiar logs del Terminal 2**

---

## 🔍 LOGS ESPECÍFICOS A BUSCAR

### **LOGS CRÍTICOS que indican PROBLEMA**:

#### **A. Activity se destruye (PROBLEMA GRAVE)**:
```
I/MainActivity: onCreate() - App iniciada     ← MAL! No debería aparecer al maximizar
I/MainActivity: onCreate() - Estado: false    ← Confirma que se recrea desde cero
```

#### **B. Activity se preserva (BIEN)**:
```
I/MainActivity: onPause() - App minimizada    ← Bien, se pausa
I/MainActivity: onResume() - App maximizada   ← Bien, se resume SIN onCreate
```

### **LOGS DE PERFORMANCE**:

```
⏱️ [START] App Maximization
✅ [END] Firebase Init - XXms
✅ [END] DI Init - XXms
✅ [END] Cache Init - XXms
🔴 [END] App Maximization - XXXXms   ← ESTE es el número crítico

📊 === REPORTE DE RENDIMIENTO ===

🔴 App Maximization: XXXXms          ← Tiempo TOTAL
🟡 Alguna operación: XXms
🟢 Otra operación: XXms

=================================
```

---

## 📋 CHECKLIST: ¿Qué copiar?

Copia TODOS los logs que contengan:

- [ ] `MainActivity` (onCreate, onResume, onPause, onDestroy)
- [ ] `📱 [App]` (Went to background, Resumed)
- [ ] `⏱️ [START]` (inicio de mediciones)
- [ ] `✅ [END]` o `🔴 [END]` (fin de mediciones)
- [ ] `📊 === REPORTE DE RENDIMIENTO ===`
- [ ] El bloque completo del reporte hasta `=================================`

---

## 🎯 EJEMPLO DE LOGS BUENOS (para que sepas qué esperar)

### **Escenario A: Activity se DESTRUYE (PROBLEMA)**
```
📱 [App] Went to background - Guardando cache...
⏸️ [APP] Minimizada a las 2024-10-23T16:15:30.123
I/MainActivity: onPause() - App minimizada
I/MainActivity: onSaveInstanceState() - Guardando estado
I/MainActivity: onDestroy() - Activity destruida      ← PROBLEMA!

(espera 5 segundos)

I/MainActivity: onCreate() - App iniciada              ← PROBLEMA! Se recrea
I/MainActivity: onCreate() - Estado: false
⏱️ [START] Firebase Init
✅ [END] Firebase Init - 250ms
⏱️ [START] DI Init
✅ [END] DI Init - 180ms
⏱️ [START] Cache Init
✅ [END] Cache Init - 45ms
📱 [App] Resumed from background - Midiendo performance...
⏱️ [START] App Maximization
🔴 [END] App Maximization - 4850ms

📊 === REPORTE DE RENDIMIENTO ===

🔴 App Maximization: 4850ms
🟢 Firebase Init: 250ms
🟢 DI Init: 180ms
🟢 Cache Init: 45ms

=================================
```

### **Escenario B: Activity se PRESERVA (BIEN)**
```
📱 [App] Went to background - Guardando cache...
⏸️ [APP] Minimizada a las 2024-10-23T16:15:30.123
I/MainActivity: onPause() - App minimizada
I/MainActivity: onSaveInstanceState() - Guardando estado

(espera 5 segundos)

I/MainActivity: onResume() - App maximizada            ← BIEN! Solo resume
📱 [App] Resumed from background - Midiendo performance...
⏱️ [START] App Maximization
✅ [END] App Maximization - 420ms                     ← RÁPIDO!

📊 === REPORTE DE RENDIMIENTO ===

🟢 App Maximization: 420ms

=================================
```

---

## 🚀 ACCIÓN INMEDIATA

1. **Ejecuta**: `flutter run` (si no está corriendo)
2. **Abre**: Debug Console en VSCode
3. **Reproduce**: Minimizar → Esperar → Maximizar
4. **Busca**: Los logs mencionados arriba
5. **Copia**: TODO el output relevante
6. **Pega**: Aquí en el chat para que pueda analizarlos

---

## 💡 TIPS

### **Si ves muchos logs y no encuentras los importantes**:

**En Debug Console de VSCode**:
- Presiona `Ctrl + F` (buscar)
- Busca: `App Maximization`
- Copia desde 10 líneas ANTES hasta el reporte completo

### **Si NO ves logs de PerformanceTracker**:

Verifica que `lib/main.dart` tenga:
```dart
import 'package:zync_app/core/utils/performance_tracker.dart';
```

Y que estés corriendo la app con `flutter run` (NO `flutter run -t lib/main_test.dart`)

---

## 📞 Si tienes problemas

Comparte:
1. ❓ ¿Ves ALGÚN log en Debug Console?
2. ❓ ¿La app corre correctamente?
3. ❓ ¿Puedes hacer login?
4. ❓ ¿Aparece el HomePage con la lista de miembros?

Y te ayudo a diagnosticar por qué no aparecen los logs.
