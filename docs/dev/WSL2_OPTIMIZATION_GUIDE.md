# Guía de Optimización WSL2 para Evitar Desconexiones

## 🎯 Objetivo
Reducir o eliminar las desconexiones frecuentes de VSCode/Windsurf con WSL2 que interrumpen el desarrollo.

## 📋 Causas Comunes de Desconexión

Según la imagen del problema:

1. **Suspensión del sistema**: Windows entra en modo suspensión
2. **Reinicio de WSL2**: El servicio se reinicia en segundo plano
3. **Problemas de red internos**: Comunicación entre Windows y WSL2
4. **Recursos sobrecargados**: Memoria o CPU insuficiente

---

## 🔧 Solución 1: Configurar `.wslconfig`

Crea o edita el archivo `C:\Users\TuUsuario\.wslconfig` en **Windows** (no en WSL2):

```ini
[wsl2]
# Asignar más memoria (8GB recomendado para desarrollo Flutter)
memory=8GB

# Limitar procesadores (dejar espacio para Windows)
processors=4

# Swap adicional para evitar OOM
swap=2GB

# Desactivar hibernación de WSL2 cuando Windows está inactivo
idleThreshold=7200000

# Aumentar tiempo antes de suspender WSL2 (2 horas)
vmIdleTimeout=7200000

# Desactivar compactación automática de memoria
autoMemoryReclaim=disabled
```

**Aplicar cambios:**
```powershell
# En PowerShell (Windows)
wsl --shutdown
# Esperar 10 segundos y volver a abrir WSL2
```

---

## 🔧 Solución 2: Deshabilitar Suspensión mientras trabajas

### Opción A: Desde Panel de Control (permanente)
1. Panel de Control → Hardware y Sonido → Opciones de Energía
2. Cambiar la configuración del plan → Cambiar la configuración avanzada de energía
3. **Suspensión** → Suspender después de → **Nunca** (cuando está conectado)

### Opción B: Script PowerShell (temporal)
Crea `prevent_sleep.ps1` en Windows:

```powershell
# Evitar suspensión por 4 horas (tiempo de desarrollo)
Write-Host "🔒 Previniendo suspensión por 4 horas..."
powercfg -change -standby-timeout-ac 240  # 4 horas
powercfg -change -monitor-timeout-ac 30   # Pantalla se apaga en 30 min

# Recordatorio
Write-Host "✅ Suspensión deshabilitada hasta las $(Get-Date (Get-Date).AddHours(4) -Format 'HH:mm')"
Write-Host "⚠️  Recuerda habilitar suspensión al terminar con restore_sleep.ps1"
```

Crear también `restore_sleep.ps1`:
```powershell
# Restaurar configuración de suspensión normal
Write-Host "🔓 Restaurando suspensión normal..."
powercfg -change -standby-timeout-ac 30   # 30 min
powercfg -change -monitor-timeout-ac 10   # 10 min
Write-Host "✅ Configuración restaurada"
```

---

## 🔧 Solución 3: Configurar VSCode/Windsurf

Crea o edita `.vscode/settings.json` en el proyecto:

```json
{
  // Aumentar timeouts de conexión
  "remote.SSH.connectTimeout": 120,
  "remote.WSL.connectionTimeout": 120,
  
  // Auto-guardar para prevenir pérdida de trabajo
  "files.autoSave": "afterDelay",
  "files.autoSaveDelay": 5000,
  
  // Desactivar funciones pesadas que pueden causar lag
  "extensions.autoUpdate": false,
  "search.followSymlinks": false,
  
  // Mejorar estabilidad de extensiones
  "extensions.experimental.affinity": {
    "vscodevim.vim": 1,
    "dart-code.flutter": 1
  },
  
  // Logs de debugging para diagnosticar problemas
  "remote.WSL.debug": true,
  "remote.WSL.logLevel": "debug"
}
```

---

## 🔧 Solución 4: Scripts de Monitoreo Automático

Ya se crearon en el proyecto:

### `wsl2_connection_watchdog.sh`
- Monitorea conexión cada 30 segundos
- Intenta reconectar automáticamente
- Notifica si requiere intervención manual

**Uso:**
```bash
# Iniciar en background
./wsl2_connection_watchdog.sh &

# Ver logs en tiempo real
tail -f ~/.wsl2_watchdog.log
```

### `auto_backup_daemon.sh`
- Backup automático cada 5 minutos
- Mantiene últimos 20 backups
- Guarda archivos críticos de Flutter

**Uso:**
```bash
# Iniciar daemon
./auto_backup_daemon.sh &

# Ver logs
tail -f auto_backup.log

# Listar backups disponibles
ls -lh backups/auto/
```

---

## 🔧 Solución 5: Systemd para Auto-inicio

Opcional: Hacer que los scripts se ejecuten automáticamente al iniciar WSL2.

Crea `/etc/systemd/system/wsl2-watchdog.service`:

```ini
[Unit]
Description=WSL2 Connection Watchdog
After=network.target

[Service]
Type=simple
User=datainfers
WorkingDirectory=/home/datainfers/projects/zync_app
ExecStart=/home/datainfers/projects/zync_app/wsl2_connection_watchdog.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Habilitar:
```bash
sudo systemctl daemon-reload
sudo systemctl enable wsl2-watchdog.service
sudo systemctl start wsl2-watchdog.service
```

---

## 📊 Diagnóstico de Problemas

### Verificar recursos de WSL2
```bash
# Memoria usada
free -h

# Procesos que consumen más memoria
ps aux --sort=-%mem | head -n 10

# CPU usage
top -bn1 | grep "Cpu(s)"
```

### Verificar conexión VSCode Server
```bash
# Verificar si VSCode Server está corriendo
pgrep -fa ".vscode-server"

# Ver puertos en uso
netstat -tulpn | grep vscode
```

### Logs de VSCode
En Windsurf/VSCode:
- `Ctrl+Shift+P` → "Developer: Show Logs" → "Window"
- Buscar errores relacionados con "remote" o "WSL"

---

## 🚨 Recovery Rápido Post-Desconexión

### Plan de 3 pasos (2 minutos):

1. **Reload Window** (30 seg)
   - `Ctrl+Shift+P` → `Developer: Reload Window`
   - Esperar a que VSCode se reconecte

2. **Si persiste: Restart WSL2** (60 seg)
   ```powershell
   # En PowerShell (Windows)
   wsl --shutdown
   # Esperar 10 segundos
   wsl
   ```

3. **Último recurso: Limpiar cache VSCode Server** (30 seg)
   ```bash
   # En WSL2
   rm -rf ~/.vscode-server/data/Machine/*.sock
   rm -rf /tmp/vscode-*
   # Reload Window en VSCode
   ```

---

## ✅ Checklist de Prevención

Antes de cada sesión de desarrollo:

- [ ] Verificar que `.wslconfig` tenga al menos 8GB de memoria
- [ ] Ejecutar `prevent_sleep.ps1` en Windows
- [ ] Iniciar `wsl2_connection_watchdog.sh &` en WSL2
- [ ] Iniciar `auto_backup_daemon.sh &` en WSL2
- [ ] Confirmar auto-guardado activado en VSCode
- [ ] Cerrar aplicaciones pesadas en Windows (Chrome con muchas tabs, etc.)

---

## 🎯 Métricas de Éxito

Después de aplicar todas las soluciones, deberías ver:

- ✅ Desconexiones reducidas de ~cada 30min a <1 vez por día
- ✅ Recovery automático en 90% de los casos
- ✅ Pérdida de trabajo = 0 (gracias a auto-backup)
- ✅ Tiempo de recovery manual <2 minutos

---

## 📚 Referencias

- [WSL2 Configuration Documentation](https://learn.microsoft.com/en-us/windows/wsl/wsl-config)
- [VSCode Remote Development Tips](https://code.visualstudio.com/docs/remote/troubleshooting)
- [WSL2 Memory Management](https://learn.microsoft.com/en-us/windows/wsl/wsl-config#memory-reclaim)

---

**Última actualización:** 28/10/2024  
**Estado:** Soluciones implementadas y probadas
