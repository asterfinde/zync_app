# 🚀 Inicio Rápido - Conexión ADB Estable

## ✅ Configuración Completada

Tu WSL2 está ahora configurado para usar el servidor ADB de Windows de forma estable.

---

## 📋 Comandos Esenciales

### 1. Limpiar ADB (Ejecutar SIEMPRE primero)
```bash
./clean_offline_devices.sh
```
**Qué hace:** Elimina emuladores offline que bloquean la conexión.

### 2. Conectar Dispositivo Android
```bash
# Reemplaza con la IP de tu dispositivo
./fix_adb_connection.sh 192.168.1.50:5555
```
**Qué hace:** Conecta tu dispositivo Android vía WiFi.

### 3. Mantener Conexión Estable (Recomendado)
```bash
# En una terminal separada
./adb_connection_watchdog.sh 192.168.1.50:5555
```
**Qué hace:** Monitorea y reconecta automáticamente si se pierde la conexión.

### 4. Ejecutar Flutter
```bash
flutter run -d 192.168.1.50:5555
```

---

## 🔄 Flujo de Trabajo Diario

### Opción A: Con Watchdog (Recomendado)

**Terminal 1:**
```bash
cd /home/dante/projects/zync_app
./clean_offline_devices.sh
./fix_adb_connection.sh 192.168.1.50:5555
flutter run -d 192.168.1.50:5555
```

**Terminal 2 (mantener abierta):**
```bash
cd /home/dante/projects/zync_app
./adb_connection_watchdog.sh 192.168.1.50:5555
```

### Opción B: Sin Watchdog (Manual)

```bash
cd /home/dante/projects/zync_app
./clean_offline_devices.sh
./fix_adb_connection.sh 192.168.1.50:5555
flutter run -d 192.168.1.50:5555
```

Si se desconecta, ejecuta nuevamente:
```bash
./fix_adb_connection.sh 192.168.1.50:5555
```

---

## 🛠️ Solución Rápida de Problemas

### Problema: "emulator-5554 offline"
```bash
./clean_offline_devices.sh
```

### Problema: Dispositivo no conecta
```bash
./clean_offline_devices.sh
./fix_adb_connection.sh 192.168.1.50:5555
```

### Problema: Conexión se interrumpe
```bash
# Usa el watchdog en una terminal separada
./adb_connection_watchdog.sh 192.168.1.50:5555
```

### Problema: ADB no responde
```bash
source ~/.bashrc
adb kill-server
sleep 2
adb start-server
```

---

## 📊 Verificación

### Ver dispositivos conectados
```bash
adb devices -l
```

**Resultado esperado:**
```
List of devices attached
192.168.1.50:5555      device product:... model:... device:...
```

### Ver dispositivos en Flutter
```bash
flutter devices
```

---

## 🎯 Configuración de WiFi ADB en tu Dispositivo

Si aún no tienes WiFi ADB configurado:

1. Conecta tu dispositivo por USB
2. Habilita "Depuración USB" en Opciones de Desarrollador
3. Ejecuta en tu PC:
   ```bash
   adb tcpip 5555
   ```
4. Desconecta el USB
5. Obtén la IP de tu dispositivo (Configuración → Acerca del teléfono → Estado)
6. Conecta vía WiFi:
   ```bash
   ./fix_adb_connection.sh <TU_IP>:5555
   ```

---

## 📁 Archivos Creados

| Archivo | Propósito |
|---------|-----------|
| `setup_adb_stable.sh` | Configuración inicial (ya ejecutado) |
| `clean_offline_devices.sh` | Limpiar emuladores offline |
| `fix_adb_connection.sh` | Conectar/reconectar dispositivo |
| `adb_connection_watchdog.sh` | Mantener conexión estable |
| `GUIA_CONEXION_ADB_ESTABLE.md` | Documentación completa |
| `INICIO_RAPIDO_ADB.md` | Este archivo |

---

## ⚡ Comandos Útiles Adicionales

### Recargar configuración de terminal
```bash
source ~/.bashrc
```

### Ver logs del watchdog
```bash
tail -f logs/adb_watchdog_*.log
```

### Limpiar build de Flutter
```bash
flutter clean && flutter pub get
```

### Ver logs de Android en tiempo real
```bash
adb logcat | grep flutter
```

---

## 🔑 Puntos Clave

✅ **SIEMPRE** ejecuta `./clean_offline_devices.sh` antes de conectar  
✅ **USA** el watchdog para mantener conexión estable  
✅ **VERIFICA** que no haya emuladores offline: `adb devices`  
✅ **RECUERDA** que usas ADB de Windows, no de WSL2  

❌ **NO** instales `android-tools-adb` en WSL2  
❌ **NO** ignores emuladores offline  
❌ **NO** uses múltiples servidores ADB  

---

## 📞 ¿Necesitas Ayuda?

1. Lee la guía completa: `GUIA_CONEXION_ADB_ESTABLE.md`
2. Revisa logs: `logs/adb_watchdog_*.log`
3. Verifica configuración: `cat ~/.bashrc | grep adb`

---

**Última actualización:** 2025-11-20  
**Estado:** ✅ Configurado y probado
