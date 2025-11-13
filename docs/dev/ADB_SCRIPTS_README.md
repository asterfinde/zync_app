# Scripts de Gestión ADB - Zync App

## 📋 Descripción

Suite de scripts profesionales para gestionar la conexión ADB WiFi de manera robusta y prevenir desconexiones durante el desarrollo.

---

## 🛠️ Scripts Disponibles

### 1. `fix_adb_connection.sh` - Script de Sanación

**Propósito:** Resolver automáticamente problemas de conexión ADB WiFi.

**Uso:**
```bash
./fix_adb_connection.sh [IP:PORT]
```

**Ejemplos:**
```bash
# Usar dispositivo por defecto (192.168.1.50:5555)
./fix_adb_connection.sh

# Especificar dispositivo diferente
./fix_adb_connection.sh 192.168.1.100:5555
```

**Lo que hace:**
1. ✅ Mata todos los procesos ADB conflictivos (Windows + Linux)
2. ✅ Detiene el servidor ADB
3. ✅ Inicia servidor ADB limpio
4. ✅ Conecta al dispositivo especificado
5. ✅ Elimina dispositivos offline/emuladores fantasma
6. ✅ Verifica visibilidad en Flutter

**Cuándo usarlo:**
- ❌ Error: `cannot bind listener`
- ❌ Error: `protocol fault`
- ❌ Dispositivo aparece como `offline`
- ❌ Emuladores fantasma (`emulator-5554 offline`)
- ❌ `flutter devices` no muestra el dispositivo
- ❌ Cualquier problema de conexión ADB

---

### 2. `keep_adb_alive.sh` - Mantenimiento Preventivo

**Propósito:** Mantener la conexión ADB WiFi activa mediante pings periódicos.

**Uso:**
```bash
./keep_adb_alive.sh [IP:PORT] [INTERVAL_SECONDS]
```

**Ejemplos:**
```bash
# Ping cada 60 segundos (default)
./keep_adb_alive.sh

# Ping cada 30 segundos
./keep_adb_alive.sh 192.168.1.50:5555 30

# Ping cada 2 minutos
./keep_adb_alive.sh 192.168.1.50:5555 120
```

**Lo que hace:**
- 🔄 Hace ping al dispositivo cada N segundos
- 📊 Reporta estado de conexión en tiempo real
- 🚨 Detecta fallos consecutivos (máximo 3)
- 🔧 Auto-reconecta usando `fix_adb_connection.sh`
- 💚 Mantiene conexión estable durante sesiones largas

**Cuándo usarlo:**
- ✅ Antes de comenzar sesión de desarrollo larga
- ✅ Durante compilaciones que tardan mucho
- ✅ Cuando el WiFi es inestable
- ✅ Para evitar interrupciones en Hot Reload

**Cómo detenerlo:**
- Presiona `Ctrl+C` en la terminal

---

## 🚀 Flujo de Trabajo Recomendado

### Inicio de Sesión de Desarrollo

```bash
# 1. Sanear conexión ADB
./fix_adb_connection.sh

# 2. (Opcional) Iniciar mantenimiento en segundo plano
./keep_adb_alive.sh &

# 3. Iniciar Flutter
flutter run -d 192.168.1.50:5555
```

### Cuando Hay Problemas Durante Desarrollo

```bash
# 1. Detener flutter run (q + Enter)

# 2. Ejecutar script de sanación
./fix_adb_connection.sh

# 3. Reiniciar Flutter
flutter run -d 192.168.1.50:5555
```

---

## 🔍 Diagnóstico de Problemas Comunes

### Problema: "cannot bind listener"
**Causa:** Puerto TCP en conflicto  
**Solución:**
```bash
./fix_adb_connection.sh
```

### Problema: "emulator-5554 offline"
**Causa:** Emulador fantasma en lista de dispositivos  
**Solución:**
```bash
./fix_adb_connection.sh  # Limpia automáticamente
```

### Problema: Desconexiones frecuentes
**Causa:** Timeout de conexión WiFi  
**Solución:**
```bash
./keep_adb_alive.sh 192.168.1.50:5555 30  # Ping cada 30s
```

### Problema: "flutter devices" no muestra dispositivo
**Causa:** ADB no sincronizado con Flutter  
**Solución:**
```bash
./fix_adb_connection.sh
flutter devices  # Verificar
```

---

## 📝 Configuración

### Cambiar IP/Puerto por Defecto

Edita los scripts y cambia:
```bash
DEFAULT_DEVICE="192.168.1.50:5555"
```

### Cambiar Intervalo de Ping por Defecto

En `keep_adb_alive.sh`:
```bash
DEFAULT_INTERVAL=60  # segundos
```

---

## 🎯 Tips para Minimizar Desconexiones

1. **Usa router 5GHz** si es posible (menos interferencia)
2. **Mantén el dispositivo cerca del router** durante desarrollo
3. **Ejecuta `keep_adb_alive.sh`** en sesiones largas
4. **Evita que el dispositivo entre en modo ahorro de energía**:
   - Configuración → Opciones de desarrollador → Permanecer activo
5. **Usa cable USB cuando WiFi sea muy inestable** (último recurso)

---

## 🐛 Troubleshooting

### El script no encuentra `adb.exe`
**Solución:** Verifica que `/mnt/c/platform-tools/adb.exe` exista:
```bash
ls -la /mnt/c/platform-tools/adb.exe
```

Si no existe, actualiza la variable `ADB_PATH` en los scripts.

### Permiso denegado al ejecutar scripts
**Solución:**
```bash
chmod +x fix_adb_connection.sh keep_adb_alive.sh
```

### PowerShell no disponible
**Solución:** Los scripts funcionarán sin PowerShell, pero con menor efectividad en la limpieza de procesos Windows.

---

## 📊 Logs y Monitoreo

### Ver conexiones activas en tiempo real
```bash
watch -n 2 '/mnt/c/platform-tools/adb.exe devices'
```

### Ver logs de ADB
```bash
/mnt/c/platform-tools/adb.exe logcat | grep "adb"
```

### Verificar puerto ADB
```bash
netstat -ano | grep 5037
```

---

## 🔗 Enlaces Útiles

- [ADB Official Docs](https://developer.android.com/tools/adb)
- [Flutter Device Setup](https://flutter.dev/docs/get-started/install)
- [WSL2 + Android Development](https://docs.microsoft.com/en-us/windows/wsl/tutorials/wsl-android)

---

## 📄 Licencia

Scripts internos para desarrollo de Zync App.

---

**Última actualización:** 2025-11-13  
**Mantenedor:** Equipo Zync App
