# Guía de Conexión ADB Estable - Post-Reinstalación WSL2

## 🎯 Objetivo
Mantener una conexión ADB estable usando el servidor de Windows (no WSL2) para evitar interrupciones durante el desarrollo.

---

## 🚀 Configuración Inicial (Solo una vez)

### Paso 1: Ejecutar Setup
```bash
cd /home/dante/projects/zync_app
chmod +x setup_adb_stable.sh
./setup_adb_stable.sh
```

### Paso 2: Recargar Terminal
```bash
source ~/.bashrc
# O cierra y abre una nueva terminal
```

### Paso 3: Verificar Configuración
```bash
# Debe mostrar: /mnt/c/platform-tools/adb.exe
which adb

# Debe mostrar la versión de ADB
adb version
```

---

## 🔧 Uso Diario

### Limpieza Inicial (Recomendado)
Cada vez que inicies, limpia emuladores offline:
```bash
./clean_offline_devices.sh
```

### Conectar Dispositivo
```bash
# Opción 1: WiFi ADB (Recomendado - Más estable)
./fix_adb_connection.sh 192.168.1.50:5555

# Opción 2: USB (Requiere PowerShell como Admin en Windows)
# En PowerShell: .\connect_android_daily.ps1
```

### Mantener Conexión Estable (Watchdog)
Ejecuta en una terminal separada:
```bash
# Monitorea cada 30 segundos (por defecto)
./adb_connection_watchdog.sh 192.168.1.50:5555

# O personaliza el intervalo (en segundos)
./adb_connection_watchdog.sh 192.168.1.50:5555 60
```

El watchdog:
- ✅ Detecta desconexiones automáticamente
- ✅ Limpia emuladores offline
- ✅ Reconecta el dispositivo
- ✅ Genera logs en `logs/adb_watchdog_*.log`
- ✅ Muestra estadísticas cada 20 ciclos

### Ejecutar Flutter
```bash
# Opción 1: Usar helper
flutter_run 192.168.1.50:5555

# Opción 2: Comando directo
flutter run -d 192.168.1.50:5555
```

---

## 🛠️ Solución de Problemas

### Problema: Emulador offline aparece
```bash
./clean_offline_devices.sh
```

### Problema: Dispositivo no conecta
```bash
# Paso 1: Limpiar
./clean_offline_devices.sh

# Paso 2: Reconectar
./fix_adb_connection.sh 192.168.1.50:5555

# Paso 3: Verificar
adb devices -l
```

### Problema: Conexión se interrumpe constantemente
```bash
# Inicia el watchdog en una terminal separada
./adb_connection_watchdog.sh 192.168.1.50:5555 30
```

### Problema: ADB no responde
```bash
# Usar helper de limpieza
adb_clean

# O manualmente
adb kill-server
sleep 2
adb start-server
```

---

## 📊 Comandos Útiles

### Verificación
```bash
# Ver dispositivos conectados
adb devices -l

# Ver dispositivos en Flutter
flutter devices

# Estado de Flutter
flutter doctor

# Logs del watchdog
tail -f logs/adb_watchdog_*.log
```

### Limpieza
```bash
# Limpiar ADB
adb_clean

# Limpiar build de Flutter
flutter clean && flutter pub get

# Limpiar emuladores offline
./clean_offline_devices.sh
```

---

## 🎯 Flujo de Trabajo Recomendado

### Al Iniciar el Día
1. **Terminal 1** - Desarrollo principal:
   ```bash
   cd /home/dante/projects/zync_app
   ./clean_offline_devices.sh
   ./fix_adb_connection.sh 192.168.1.50:5555
   ```

2. **Terminal 2** - Watchdog (mantiene conexión):
   ```bash
   cd /home/dante/projects/zync_app
   ./adb_connection_watchdog.sh 192.168.1.50:5555
   ```

3. **Terminal 1** - Ejecutar Flutter:
   ```bash
   flutter_run 192.168.1.50:5555
   ```

### Durante el Desarrollo
- El watchdog mantiene la conexión automáticamente
- Si hay desconexión, el watchdog reconecta
- Puedes ver el estado en la Terminal 2

### Al Finalizar el Día
- Presiona `Ctrl+C` en la Terminal 2 (watchdog)
- Cierra Flutter en Terminal 1
- Opcionalmente: `adb disconnect 192.168.1.50:5555`

---

## 📝 Scripts Disponibles

| Script | Propósito | Uso |
|--------|-----------|-----|
| `setup_adb_stable.sh` | Configuración inicial | Una vez después de reinstalar WSL2 |
| `clean_offline_devices.sh` | Limpiar emuladores offline | Cuando aparezca `emulator-5554 offline` |
| `fix_adb_connection.sh` | Conectar/reconectar dispositivo | Para conectar o solucionar problemas |
| `adb_connection_watchdog.sh` | Mantener conexión estable | Ejecutar en terminal separada |
| `configure_adb_windows.sh` | Configuración alternativa | Similar a setup_adb_stable.sh |
| `keep_adb_alive.sh` | Watchdog simple | Alternativa más simple al watchdog |

---

## ⚠️ Importante

### ✅ Hacer
- **SIEMPRE** usar ADB de Windows (`/mnt/c/platform-tools/adb.exe`)
- Limpiar emuladores offline regularmente
- Usar WiFi ADB para mayor estabilidad
- Mantener el watchdog corriendo durante desarrollo
- Verificar logs si hay problemas: `logs/adb_watchdog_*.log`

### ❌ NO Hacer
- **NUNCA** instalar `android-tools-adb` en WSL2
- No usar múltiples servidores ADB simultáneamente
- No ignorar emuladores offline (causan conflictos)
- No cerrar el watchdog durante desarrollo activo

---

## 🔍 Verificación de Estado

### Estado Saludable
```bash
$ adb devices -l
List of devices attached
192.168.1.50:5555      device product:a14x model:SM_A145M device:a14x transport_id:1
```

### Estado con Problemas
```bash
$ adb devices -l
List of devices attached
emulator-5554          offline
192.168.1.50:5555      offline
```
**Solución:** `./clean_offline_devices.sh`

---

## 📚 Recursos Adicionales

- **Documentación completa:** `SOLUCION_WSL2_ADB.md`
- **Configuración WiFi ADB:** `docs/dev/wifi-adb-connection-guide.md` (si existe)
- **Firewall USBIPD:** `FIX_USBIPD_FIREWALL_GUIDE.md`
- **Logs del watchdog:** `logs/adb_watchdog_*.log`

---

## 🆘 Soporte

Si los scripts no funcionan:

1. Verifica que ADB de Windows existe:
   ```bash
   ls -la /mnt/c/platform-tools/adb.exe
   ```

2. Verifica configuración:
   ```bash
   cat ~/.bashrc | grep adb
   ```

3. Recarga configuración:
   ```bash
   source ~/.bashrc
   ```

4. Revisa logs:
   ```bash
   tail -f logs/adb_watchdog_*.log
   ```

---

**Última actualización:** 2025-11-20  
**Versión:** 1.0  
**Estado:** Activo
