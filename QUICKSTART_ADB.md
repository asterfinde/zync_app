# 🎯 Prevención de Problemas ADB en Windows - Guía Rápida

## ✅ SIEMPRE Ejecutar Antes de Desarrollar

```powershell
# Opción 1: Script automatizado (RECOMENDADO)
.\start_dev.ps1

# Opción 2: Manual
.\scripts\fix_adb_windows.ps1
```

## 🚨 Si Fallas Durante Desarrollo

```powershell
# 1. Detén Flutter (Ctrl+C)
# 2. Ejecuta:
taskkill /F /IM adb.exe
C:\Android\platform-tools\adb.exe kill-server
C:\Android\platform-tools\adb.exe start-server
adb devices

# 3. Re-ejecuta Flutter
flutter run -d R58W315389R
```

## 📋 Configuración Única (Primera Vez)

### 1. Verificar Ruta de ADB
```powershell
where.exe adb
# Debe mostrar: C:\Android\platform-tools\adb.exe
# Si muestra múltiples rutas, elimina las extras
```

### 2. Agregar al PATH
```
Panel de Control → Sistema → Configuración Avanzada del Sistema 
→ Variables de Entorno → Path → Agregar:
C:\Android\platform-tools
```

### 3. Configurar Firewall (Administrador)
```powershell
New-NetFirewallRule -DisplayName "Android ADB" `
  -Direction Inbound `
  -Program "C:\Android\platform-tools\adb.exe" `
  -Action Allow -Profile Any
```

## 💡 Workflow Diario

```powershell
# 🌅 MAÑANA (al llegar al trabajo):
1. Conecta el cable USB a tu Android
2. .\start_dev.ps1              # Limpia e inicia ADB automáticamente
3. flutter run -d R58W315389R   # O trabaja normalmente en VS Code

# 💼 DURANTE EL DÍA:
# Si aparece error de ADB mientras desarrollas:
4. Ctrl+C                       # Detén Flutter
5. taskkill /F /IM adb.exe      # Matar procesos ADB
6. adb kill-server              # Reiniciar servidor
7. adb start-server
8. flutter run -d R58W315389R   # Reintentar

# 🌙 NOCHE (al salir del trabajo):
9. .\stop_dev.ps1               # Limpia procesos y libera puerto 5037
10. Desconecta el cable USB del Android
11. Cierra VS Code con seguridad

# ⚡ ATAJO RÁPIDO (si tienes prisa):
# Simplemente desconecta el USB y cierra todo
# Windows limpiará los procesos automáticamente
# Pero .\stop_dev.ps1 evita procesos zombies
```

## 🔍 Diagnóstico Rápido

```powershell
# ¿ADB está corriendo?
tasklist | findstr adb

# ¿Qué dispositivos ve ADB?
adb devices

# ¿Qué dispositivos ve Flutter?
flutter devices

# ¿Qué usa el puerto 5037?
netstat -ano | findstr :5037
```

## ⚠️ Causas Comunes de Problemas

1. **Múltiples instalaciones de ADB** → Mantener solo una
2. **Firewall bloqueando** → Crear regla de excepción
3. **Procesos ADB zombies** → Matar con `taskkill`
4. **Puerto 5037 ocupado** → Verificar con `netstat`
5. **WSL2 interfiriendo** → Usar solo Windows nativo para Flutter

## 📚 Más Información

Ver: `SOLUCION_ADB_WINDOWS.md` para detalles completos.
