# 🔥 Fix USBIPD Firewall - Guía Rápida

## 🎯 Problema

Al conectar dispositivo Android a WSL2 con `usbipd`, aparece este warning:

```
usbipd: warning: A firewall appears to be blocking the connection; ensure TCP port 3240 is allowed.
```

## ✅ Solución Rápida

### Opción 1: Usar el script automatizado (RECOMENDADO)

1. **Copia el archivo `fix_usbipd_firewall.ps1` a tu PC Windows**
   
2. **Abre PowerShell como Administrador:**
   - Click derecho en el menú inicio → "Windows PowerShell (Administrador)"
   - O busca "PowerShell" → Click derecho → "Ejecutar como administrador"

3. **Navega a la carpeta del script:**
   ```powershell
   cd "C:\ruta\donde\guardaste\el\script"
   ```

4. **Ejecuta el script:**
   ```powershell
   .\fix_usbipd_firewall.ps1
   ```

5. **Espera a que termine** (mostrará checkmarks ✅ verdes cuando complete cada paso)

6. **Ejecuta tu script de conexión nuevamente:**
   ```powershell
   .\conectar_android.ps1
   ```

---

### Opción 2: Comandos manuales (si prefieres control total)

Ejecutar en PowerShell como Administrador:

#### 1. Verificar servicio usbipd
```powershell
Get-Service usbipd | Format-Table -AutoSize
```

#### 2. Crear regla de firewall principal
```powershell
New-NetFirewallRule -DisplayName "Allow usbipd TCP 3240 (WSL2)" `
  -Direction Inbound -Action Allow -Protocol TCP -LocalPort 3240 `
  -Profile Private,Domain -Description "Allow usbipd attach communication for WSL2"
```

#### 3. Verificar regla creada
```powershell
Get-NetFirewallRule -DisplayName "Allow usbipd*" | Format-Table -AutoSize
```

#### 4. Reiniciar servicio usbipd
```powershell
Restart-Service usbipd -Force
```

#### 5. Probar conexión
```powershell
# Obtener BUSID de tu dispositivo
usbipd list

# Conectar (reemplaza 1-2 con tu BUSID)
usbipd wsl attach --busid 1-2
```

---

## 🔍 Verificación en WSL

Después de conectar, verifica dentro de WSL (Ubuntu-24.04):

```bash
# Instalar herramientas si no están
sudo apt update
sudo apt install -y usbutils android-tools-adb

# Ver dispositivos USB conectados
lsusb

# Verificar con adb (Android Debug Bridge)
adb kill-server
adb start-server
adb devices
```

**Deberías ver:**
- `lsusb` muestra tu dispositivo Android
- `adb devices` lista el dispositivo con estado "device" o "unauthorized"

---

## 🆘 Troubleshooting

### El warning persiste después de crear la regla

**Causas comunes:**

1. **Antivirus de terceros bloqueando:**
   - Windows Defender
   - Bitdefender, ESET, McAfee, Norton, Kaspersky
   - **Solución:** Agrega excepción para `usbipd.exe` o puerto TCP 3240

2. **Firewall corporativo:**
   - Si estás en una red empresarial, puede haber políticas restrictivas
   - **Solución:** Contacta IT o usa VPN que permita el tráfico local

3. **Perfil de red incorrecto:**
   - La regla solo aplica a perfiles Private/Domain
   - Si tu red está en perfil "Public", no aplicará
   - **Solución:** Cambia perfil de red a "Private" en Configuración → Red

**Verificar perfil de red actual:**
```powershell
Get-NetConnectionProfile | Format-Table -AutoSize
```

**Cambiar a Private si está en Public:**
```powershell
Set-NetConnectionProfile -InterfaceAlias "Ethernet" -NetworkCategory Private
# O para Wi-Fi:
Set-NetConnectionProfile -InterfaceAlias "Wi-Fi" -NetworkCategory Private
```

### Debugging avanzado

**Ver logs detallados de usbipd:**
```powershell
usbipd wsl attach --busid 1-2 --log-level debug
```

**Ver procesos escuchando en puerto 3240:**
```powershell
netstat -ano | Select-String ":3240"
Get-CimInstance Win32_Process -Filter "ProcessId=<PID>" | Select-Object ProcessId,Name,ExecutablePath
```

**Test de conectividad desde WSL hacia Windows (puerto 3240):**
```bash
# Dentro de WSL
nc -zv 172.25.0.1 3240
# o
telnet 172.25.0.1 3240
```

---

## 🗑️ Deshacer cambios

Si necesitas eliminar las reglas de firewall creadas:

```powershell
# Eliminar todas las reglas relacionadas con usbipd
Remove-NetFirewallRule -DisplayName "Allow usbipd*"

# O eliminar regla específica
Remove-NetFirewallRule -DisplayName "Allow usbipd TCP 3240 (WSL2)"
```

---

## 📋 Reglas creadas por el script

El script `fix_usbipd_firewall.ps1` crea **3 reglas** para máxima compatibilidad:

1. **Regla por puerto (principal):**
   - Puerto: TCP 3240
   - Perfiles: Private, Domain
   - Dirección: Inbound

2. **Regla por programa (adicional):**
   - Programa: `C:\Program Files\usbipd-win\usbipd.exe` (o la ruta detectada)
   - Perfiles: Private, Domain

3. **Regla restringida a WSL NAT (más segura):**
   - Puerto: TCP 3240
   - RemoteAddress: 172.25.0.0/16 (solo WSL puede conectar)
   - Perfiles: Private, Domain

---

## 💡 Consejos de seguridad

✅ **Buenas prácticas:**
- Solo abre el puerto en perfiles Private/Domain (nunca Public)
- Usa la regla NAT si quieres máxima restricción
- Desactiva las reglas cuando no uses WSL con dispositivos USB

❌ **Evitar:**
- Abrir el puerto globalmente (`-Profile Any`)
- Permitir conexiones desde cualquier IP (`-RemoteAddress Any`)
- Dejar reglas activas en redes públicas (hoteles, cafeterías, aeropuertos)

---

## 🔗 Enlaces útiles

- [usbipd-win GitHub](https://github.com/dorssel/usbipd-win)
- [WSL USB Device Documentation](https://learn.microsoft.com/en-us/windows/wsl/connect-usb)
- [Windows Firewall Rules](https://learn.microsoft.com/en-us/powershell/module/netsecurity/new-netfirewallrule)

---

## ✅ Checklist de verificación

Después de ejecutar el script, verifica:

- [ ] Servicio usbipd está corriendo
- [ ] Puerto 3240 tiene listener activo (netstat)
- [ ] Reglas de firewall creadas y habilitadas
- [ ] `usbipd wsl attach` completa sin warning de firewall
- [ ] `lsusb` en WSL muestra el dispositivo Android
- [ ] `adb devices` lista el dispositivo correctamente
- [ ] `flutter devices` detecta el dispositivo (si usas Flutter)

---

**Creado para resolver problemas de conexión Android-WSL2 con usbipd 🚀**
