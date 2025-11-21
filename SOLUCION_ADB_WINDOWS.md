# Solución Definitiva: Problemas de ADB en Windows

## 🎯 Problema
El daemon de ADB no puede iniciarse, causando errores como:
```
* daemon not running; starting now at tcp:5037
could not read ok from ADB Server
* failed to start daemon
error: cannot connect to daemon
```

## ✅ Soluciones Permanentes

### 1. **Script Automático** (Recomendado)
```powershell
# Ejecutar antes de cada sesión de desarrollo
.\scripts\fix_adb_windows.ps1
```

### 2. **Configuración del Entorno Windows**

#### A. Asegurar una sola instalación de ADB
**Problema:** Múltiples versiones de ADB causan conflictos.

**Solución:**
1. Verifica ubicaciones comunes:
   ```powershell
   where.exe adb
   ```
2. Mantén solo una versión (recomendado: `C:\Android\platform-tools\`)
3. Agrega al PATH de Windows:
   ```
   Panel de Control → Sistema → Configuración Avanzada → Variables de Entorno
   Agregar: C:\Android\platform-tools
   ```

#### B. Configurar Firewall de Windows
**Problema:** El firewall bloquea el puerto 5037 de ADB.

**Solución (como Administrador):**
```powershell
# Crear regla de firewall para ADB
New-NetFirewallRule -DisplayName "Android ADB" `
  -Direction Inbound `
  -Program "C:\Android\platform-tools\adb.exe" `
  -Action Allow `
  -Profile Any
```

#### C. Evitar conflictos de puerto
**Problema:** Otro programa usa el puerto 5037.

**Solución:**
```powershell
# Verificar qué usa el puerto 5037
netstat -ano | findstr :5037

# Si hay conflicto, matar el proceso (reemplaza PID)
taskkill /PID <PID> /F
```

### 3. **Rutina de Inicio de Desarrollo**

Crea un script `start_dev.ps1`:
```powershell
# 1. Limpiar procesos ADB
taskkill /F /IM adb.exe 2>$null

# 2. Reiniciar servidor
C:\Android\platform-tools\adb.exe kill-server
Start-Sleep -Seconds 2
C:\Android\platform-tools\adb.exe start-server

# 3. Verificar dispositivo
C:\Android\platform-tools\adb.exe devices

# 4. Mensaje
Write-Host "✅ ADB listo. Dispositivos conectados arriba" -ForegroundColor Green
```

Ejecutar SIEMPRE antes de `flutter run`:
```powershell
.\start_dev.ps1
flutter run
```

### 4. **Alternativa: USB Cable Siempre**

**Ventaja:** Evita problemas de red WiFi/WSL2
**Desventaja:** Menos movilidad

Para desarrollo estable en Windows:
- ✅ Usar cable USB siempre
- ❌ Evitar conexión WiFi ADB (requiere más configuración)

## 🔥 Prevención Definitiva

### Agregar al `.gitignore`:
```
# ADB logs (si se crean)
*.adb.log
```

### Crear `pre-dev-check.ps1`:
```powershell
# Ejecutar automáticamente antes de cada sesión
$adbRunning = Get-Process -Name "adb" -ErrorAction SilentlyContinue
if ($adbRunning) {
    Write-Host "⚠️  ADB ya está corriendo. Reiniciando..." -ForegroundColor Yellow
    .\scripts\fix_adb_windows.ps1
} else {
    Write-Host "✅ ADB limpio, iniciando..." -ForegroundColor Green
    C:\Android\platform-tools\adb.exe start-server
}
```

## 📋 Checklist de Configuración Inicial

- [ ] Solo una instalación de ADB en el sistema
- [ ] ADB en PATH de Windows
- [ ] Regla de firewall creada
- [ ] Script `fix_adb_windows.ps1` probado
- [ ] USB Debugging habilitado en el teléfono
- [ ] Cable USB de buena calidad (no todos los cables sirven para datos)

## 🚀 Workflow Recomendado

```powershell
# Cada vez que inicies desarrollo:
1. .\scripts\fix_adb_windows.ps1
2. flutter run

# Si falla durante desarrollo:
1. Ctrl+C para detener Flutter
2. .\scripts\fix_adb_windows.ps1
3. flutter run
```

## 💡 Notas Importantes

1. **WSL2 vs Windows nativo:**
   - Windows nativo tiene menos problemas de ADB
   - Si usas WSL2, considera migrar a PowerShell/CMD para Flutter

2. **Conexión WiFi ADB:**
   - Más problemática que USB
   - Requiere configuración adicional
   - No recomendada para desarrollo diario

3. **Windows Defender/Antivirus:**
   - Puede interferir con ADB
   - Agrega `adb.exe` a excepciones si es necesario
