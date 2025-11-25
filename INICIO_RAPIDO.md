# 🚀 Inicio Rápido - Post Restauración

## ⚡ Setup Automático (RECOMENDADO)

Ejecuta este comando para configurar todo automáticamente:

```bash
./setup_post_restauracion.sh
```

Este script configurará:
- ✅ Permisos de ejecución
- ✅ ADB de Windows
- ✅ Dependencias de Flutter
- ✅ Verificación del sistema

---

## 📋 Checklist Manual (si prefieres hacerlo paso a paso)

### 1️⃣ Configurar Windsurf para WSL2

**Abrir el workspace:**
1. En Windsurf: `File > Open Workspace from File...`
2. Selecciona: `zync_app.code-workspace`
3. Verifica en el footer: debe mostrar `WSL: Ubuntu-24.04`

### 2️⃣ Configurar ADB de Windows

```bash
# Dar permisos
chmod +x configure_adb_windows.sh

# Ejecutar configuración
./configure_adb_windows.sh

# Recargar shell
source ~/.bashrc

# Verificar
which adb
# Debe mostrar: /mnt/c/platform-tools/adb.exe
```

### 3️⃣ Instalar Dependencias

```bash
# Con FVM (recomendado)
fvm flutter pub get

# O con Flutter directo
flutter pub get
```

### 4️⃣ Verificar Setup

```bash
./verify_setup.sh
```

---

## 🔌 Conectar Dispositivo Android

### Opción A: USB (requiere PowerShell como Admin)

```powershell
# En PowerShell (Administrador)
./connect_android_daily.ps1
```

### Opción B: WiFi (MÁS ESTABLE - RECOMENDADO)

```bash
# En WSL2
./fix_adb_connection.sh 192.168.1.50:5555
```

**Cómo obtener la IP de tu dispositivo:**
1. Configuración → Acerca del teléfono → Estado
2. Busca "Dirección IP"

---

## ✅ Verificar Conexión

```bash
# Ver dispositivos conectados
adb devices -l

# Ver dispositivos en Flutter
flutter devices
```

---

## 🎯 Iniciar Desarrollo

### Inicio del Día

```bash
./start_day.sh
```

### Ejecutar App

```bash
# Opción 1: Con función helper
flutter_run 192.168.1.50:5555

# Opción 2: Comando directo
flutter run -d 192.168.1.50:5555

# Opción 3: Dejar que Flutter elija
flutter run
```

### Fin del Día

```bash
./end_day.sh
```

---

## 🆘 Problemas Comunes

### ❌ ADB no encuentra dispositivos

```bash
# Reiniciar ADB
adb kill-server && sleep 2 && adb start-server

# Reconectar WiFi
./fix_adb_connection.sh 192.168.1.50:5555
```

### ❌ Windsurf no muestra WSL2

1. Cierra Windsurf completamente
2. Abre el workspace: `zync_app.code-workspace`
3. Verifica el footer

### ❌ Flutter no encuentra SDK

```bash
# Verificar FVM
fvm flutter --version

# Si falla, reinstalar
dart pub global activate fvm
fvm install stable
fvm use stable
```

### ❌ Scripts sin permisos

```bash
chmod +x *.sh
chmod +x scripts/*.sh
```

---

## 📚 Documentación Completa

- **Guía detallada:** `SOLUCION_WSL2_ADB.md`
- **Verificación:** `./verify_setup.sh`
- **Configuración WSL2:** `.wslconfig.example`

---

## 🎨 Comandos Útiles

```bash
# Estado del sistema
./verify_setup.sh

# Ver logs de Flutter
adb logcat | grep flutter

# Limpiar build
flutter clean && flutter pub get

# Ver dispositivos
flutter devices

# Ejecutar tests
flutter test

# Generar build
flutter build apk
```

---

## 🔄 Flujo de Trabajo Diario

```bash
# 1. Conectar dispositivo (PowerShell Admin)
./connect_android_daily.ps1

# 2. Iniciar sesión (WSL2)
./start_day.sh

# 3. Desarrollar
flutter run

# 4. Finalizar sesión (WSL2)
./end_day.sh

# 5. Desconectar dispositivo (PowerShell Admin)
./disconnect_android_daily.ps1
```

---

## ⚙️ Configuración Opcional WSL2

Para mejor rendimiento:

1. Copia `.wslconfig.example` a `C:\Users\<tu-usuario>\.wslconfig`
2. Edita los valores según tu hardware
3. Ejecuta: `wsl --shutdown` (PowerShell)
4. Espera 10 segundos
5. Vuelve a abrir WSL2

---

## 🎯 Resumen de Archivos Creados

| Archivo | Propósito |
|---------|-----------|
| `zync_app.code-workspace` | Configuración de Windsurf/VSCode |
| `configure_adb_windows.sh` | Configurar ADB de Windows |
| `verify_setup.sh` | Verificar configuración |
| `setup_post_restauracion.sh` | Setup automático completo |
| `SOLUCION_WSL2_ADB.md` | Documentación completa |
| `INICIO_RAPIDO.md` | Esta guía |

---

## 💡 Tips

- **Usa WiFi ADB** en lugar de USB para mayor estabilidad
- **Ejecuta `./end_day.sh`** antes de apagar la PC
- **Mantén backups** con `./backup_critical_files.sh`
- **Verifica el setup** regularmente con `./verify_setup.sh`

---

**¿Necesitas ayuda?** Revisa `SOLUCION_WSL2_ADB.md` para troubleshooting detallado.

**¡Listo para desarrollar! 🚀**
