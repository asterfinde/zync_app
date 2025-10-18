# 📱 Guía de Conexión WiFi ADB para WSL2

## 🎯 Objetivo
Conectar tu dispositivo Android a WSL2 mediante WiFi usando ADB (Android Debug Bridge) para desarrollo con Flutter.

## ✅ Requisitos Previos

- ✅ Dispositivo Android con **Opciones de desarrollador** activadas
- ✅ Depuración USB habilitada
- ✅ PC y Android en la **misma red WiFi**
- ✅ WSL2 instalado con Ubuntu
- ✅ ADB instalado en WSL2 (`sudo apt install adb`)

---

## 🔧 Método 1: Conexión WiFi Directa (Recomendado)

### **Paso 1: Activar Depuración Inalámbrica en Android**

1. Ve a **Ajustes** → **Opciones de desarrollador**
2. Busca **"Depuración inalámbrica"** (Wireless debugging)
3. **Actívala** (toggle ON)
4. Toca en **"Vincular dispositivo con código de vinculación"**

Verás una pantalla con:
```
Dirección IP:Puerto
192.168.1.100:37859

Código de vinculación
482924
```

### **Paso 2: Vincular el dispositivo desde WSL2**

En tu terminal WSL2:

```bash
# Reemplaza con tu IP:Puerto del paso anterior
adb pair 192.168.1.100:37859

# Cuando te pida el código, ingrésalo (ejemplo: 482924)
Enter pairing code: 482924
```

**Salida esperada:**
```
Successfully paired to 192.168.1.100:37859 [guid=adb-R58WXXX-XXXXXX]
```

### **Paso 3: Conectar al dispositivo**

```bash
# Sal de la pantalla de vinculación en el teléfono
# Verás la IP principal en la pantalla de "Depuración inalámbrica"
# Ejemplo: 192.168.1.100:37477

# Conectar usando la IP principal (puerto diferente al de vinculación)
adb connect 192.168.1.100:37477
```

**Salida esperada:**
```
connected to 192.168.1.100:37477
```

### **Paso 4: Verificar la conexión**

```bash
adb devices
```

**Salida esperada:**
```
List of devices attached
192.168.1.100:37477    device
```

---

## 🔌 Método 2: WiFi mediante USB (Alternativo)

Si tienes el dispositivo conectado por USB en Windows:

### **En PowerShell (Windows):**

```powershell
# Ver dispositivos conectados
adb devices

# Habilitar ADB por TCP en el puerto 5555
adb tcpip 5555

# Obtener la IP del dispositivo
adb shell ip addr show wlan0 | findstr inet
```

### **En WSL2:**

```bash
# Conectar usando la IP obtenida (ejemplo: 192.168.1.100)
adb connect 192.168.1.100:5555

# Verificar
adb devices
```

**Ahora puedes desconectar el cable USB.**

---

## 🚀 Ejecutar la App Flutter

Una vez conectado por WiFi:

```bash
# Ver dispositivos disponibles
flutter devices

# Ejecutar la app
flutter run

# O especificar el dispositivo
flutter run -d 192.168.1.100:37477
```

---

## 🔄 Reconexión Automática

El dispositivo se desconectará al:
- Cambiar de red WiFi
- Reiniciar el teléfono
- Desactivar "Depuración inalámbrica"

**Para reconectar rápidamente:**

```bash
# Si ya vinculaste antes, solo reconecta
adb connect 192.168.1.100:37477

# Si cambió la IP o necesitas re-vincular
adb pair <nueva_ip>:<puerto_vinculacion>
# Ingresa el nuevo código
```

---

## 🛠️ Comandos Útiles

### **Desconectar dispositivo WiFi**
```bash
adb disconnect 192.168.1.100:37477
```

### **Ver todos los dispositivos (USB + WiFi)**
```bash
adb devices -l
```

### **Reiniciar servidor ADB**
```bash
adb kill-server
adb start-server
```

### **Ver logs en tiempo real**
```bash
adb logcat
```

### **Instalar APK manualmente**
```bash
adb install -r app.apk
```

---

## ❌ Solución de Problemas

### **Error: "unable to connect"**

**Causas comunes:**
- Firewall bloqueando el puerto 5555 o el puerto personalizado
- PC y teléfono en redes WiFi diferentes
- IP del teléfono cambió (usa DHCP)

**Solución:**
```bash
# 1. Verificar que estén en la misma red
ip addr show | grep inet

# 2. Reiniciar ADB
adb kill-server
adb start-server

# 3. Re-vincular el dispositivo
adb pair <ip>:<puerto>
```

### **Error: "offline" después de conectar**

```bash
# Desconectar y reconectar
adb disconnect 192.168.1.100:37477
adb connect 192.168.1.100:37477
```

### **El dispositivo no aparece en Flutter**

```bash
# Verificar que ADB lo detecta
adb devices

# Reiniciar Flutter daemon
flutter clean
flutter pub get
flutter devices
```

---

## 🎯 Script de Conexión Rápida

Crea un alias en `~/.bashrc` o `~/.zshrc`:

```bash
# Agregar al final del archivo
alias android-connect='adb connect 192.168.1.100:37477 && adb devices'
alias android-disconnect='adb disconnect && adb devices'
```

Luego:
```bash
source ~/.bashrc
android-connect  # Conecta rápidamente
```

---

## 📊 Ventajas de WiFi ADB vs USB

| Aspecto | WiFi | USB |
|---------|------|-----|
| **Configuración inicial** | ⚠️ Requiere vinculación | ✅ Plug & play |
| **Estabilidad en WSL2** | ✅ Muy estable | ❌ Problemas con drivers |
| **Movilidad** | ✅ Sin cables | ❌ Cable conectado |
| **Velocidad** | ⚠️ Depende de WiFi | ✅ Más rápido |
| **Hot Reload** | ✅ Funciona perfectamente | ✅ Funciona |
| **Debugging** | ✅ Completo | ✅ Completo |

---

## 📝 Notas Importantes

1. **Seguridad**: La depuración inalámbrica solo funciona en la red local. No es accesible desde internet.

2. **Batería**: La depuración inalámbrica consume más batería que USB. Mantén el teléfono cargado.

3. **IP Dinámica**: Si tu router usa DHCP, la IP del teléfono puede cambiar. Considera:
   - Asignar IP estática en el router para tu dispositivo
   - O configurar reserva DHCP por MAC address

4. **Múltiples dispositivos**: Puedes tener varios dispositivos conectados simultáneamente:
   ```bash
   adb devices
   # Output:
   # 192.168.1.100:37477    device
   # 192.168.1.101:42333    device
   
   # Ejecutar en dispositivo específico
   flutter run -d 192.168.1.100:37477
   ```

---

## 🔗 Referencias

- [Android Developer - ADB](https://developer.android.com/studio/command-line/adb)
- [Flutter - Dispositivos de prueba](https://docs.flutter.dev/get-started/install/linux#set-up-your-android-device)
- [WSL2 USB/IP](https://learn.microsoft.com/en-us/windows/wsl/connect-usb)

---

**Última actualización:** Octubre 2025  
**Proyecto:** Zync App  
**Branch:** feature/point16-sos-gps
