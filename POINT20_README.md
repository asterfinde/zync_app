# 🚨 POINT 20 - BUG DE MINIMIZACIÓN

**Estado:** ⚠️ BLOQUEADO - Necesita validación urgente  
**Última actualización:** 01/11/2025  
**Tiempo para resolver:** 1-2 horas

---

## 🎯 SITUACIÓN ACTUAL

### ✅ LO QUE TENEMOS
- Solución completa implementada (`SessionCache` + `UI Optimista`)
- App de pruebas lista con timer automático (`main_minimal_test.dart`)
- Documentación completa del plan de acción

### ❌ LO QUE FALTA
- **Validar que la solución funciona** ejecutando la app de pruebas
- Capturar métricas reales de performance
- Aplicar mejoras al `main.dart` original

### 🚨 EL PROBLEMA
**Estamos varios días bloqueados porque NO hemos validado si la solución implementada realmente funciona.**

---

## 🚀 CÓMO DESBLOQUEAR (10 minutos)

### Paso 1: Ejecutar App de Pruebas
```bash
flutter run -t lib/main_minimal_test.dart
```

### Paso 2: Minimizar y Maximizar
1. Presionar HOME
2. Esperar 5 segundos
3. Volver a abrir la app

### Paso 3: Capturar Métricas
Buscar en los logs:
```
⏱️ [TEST] Cache Restore: XXms
⏱️ [TEST] Total Resume: XXms  ← CRÍTICO
```

### Paso 4: Decidir
- Si Total Resume <500ms → ✅ Aplicar al main.dart
- Si Total Resume >1000ms → ❌ Optimizar más
- Si MainActivity no se destruye → ✅ No es bug

---

## 📁 DOCUMENTACIÓN

### Instrucciones Rápidas (LEER PRIMERO)
- `EJECUTAR_POINT20.txt` - Paso a paso visual

### Documentación Detallada
- `docs/dev/point20_plan_011125.md` - Plan completo
- `docs/dev/point20_resumen_ejecutivo.md` - Resumen ejecutivo
- `docs/dev/point20_estado_actual.md` - Estado y progreso
- `docs/dev/BACKLOG.md` (línea 219) - Point 20 en backlog

---

## 🎯 ARCHIVOS CLAVE

### Para Testing AHORA
```
lib/main_minimal_test.dart          ← EJECUTAR ESTE
```

### Para Aplicar DESPUÉS (si funciona)
```
lib/main.dart                       ← Aplicar mejoras aquí
lib/features/auth/presentation/pages/auth_wrapper.dart
```

### Servicios Implementados
```
lib/core/services/session_cache_service.dart  ← Solución FASE 2B
```

---

## 💡 RESUMEN EJECUTIVO

**Problema:** App se reinicia al minimizar/maximizar  
**Causa:** Android destruye MainActivity para liberar RAM  
**Solución:** SessionCache + UI Optimista (restaura instantáneamente)  
**Estado:** Implementado pero NO validado  
**Bloqueo:** Necesitamos ejecutar pruebas para confirmar que funciona  

---

## 🚀 ACCIÓN INMEDIATA

```bash
# EJECUTAR AHORA:
flutter run -t lib/main_minimal_test.dart

# LUEGO:
# 1. Minimizar (HOME)
# 2. Esperar 5s
# 3. Maximizar
# 4. Revisar logs
# 5. Decidir siguiente paso
```

---

## ✅ CRITERIO DE ÉXITO

Point 20 se resuelve cuando:
- ✅ Total Resume <500ms (medido)
- ✅ Usuario no percibe reinicio
- ✅ Solución aplicada al main.dart
- ✅ Point 20 cerrado en BACKLOG

---

**PRÓXIMO PASO:** Lee `EJECUTAR_POINT20.txt` y ejecuta las pruebas 🚀
