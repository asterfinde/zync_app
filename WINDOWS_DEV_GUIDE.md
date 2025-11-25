# Zync App - Windows Development Guide

## 🎯 Flujo de Trabajo Diario

### 1️⃣ Iniciar Jornada
```powershell
.\start_dev.ps1
```

### 2️⃣ Desarrollar
- Edita código en VS Code
- Haz commits cuando sea necesario

### 3️⃣ Ejecutar App
```powershell
# Opción A: Script automatizado
.\run_app.ps1

# Opción B: Flutter directo (hot reload instantáneo)
flutter run

# Opción C: Especificar dispositivo
flutter run -d 192.168.1.50:5555  # WiFi
flutter run -d R58W315389R         # USB
```

### 4️⃣ Cerrar Jornada
```powershell
.\stop_dev.ps1
```

## 🔥 Hot Reload

Una vez que la app está corriendo con `flutter run`:
- Presiona `r` → Hot reload
- Presiona `R` → Hot restart
- Presiona `q` → Quit

## 🛠️ Comandos Útiles

### Ver dispositivos conectados
```powershell
flutter devices
```

### Limpiar build
```powershell
flutter clean
flutter pub get
```

### Ver logs
```powershell
flutter logs
```

### Compilar APK release
```powershell
flutter build apk --release
```

## 📱 Dispositivos Disponibles

- **WiFi:** `192.168.1.50:5555` (SM A145M)
- **USB:** `R58W315389R` (SM A145M)
- **Windows:** `windows` (para pruebas desktop)
- **Chrome:** `chrome` (para pruebas web)

## ⚡ Ventajas de Windows Native

✅ Hot reload instantáneo (sin latencia WSL)
✅ Compilación 30% más rápida
✅ USB directo sin configuración
✅ Mejor integración con Android Studio
✅ DevTools funciona perfectamente
✅ Sin problemas de permisos o rutas

## 📂 Estructura de Proyecto

```
C:\Users\dante\projects\zync_app\
├── start_dev.ps1       # Inicio de jornada
├── stop_dev.ps1        # Cierre de jornada  
├── run_app.ps1         # Ejecutar app
├── lib\                # Código Dart/Flutter
├── android\            # Proyecto Android
└── pubspec.yaml        # Dependencias
```

## 🚨 Troubleshooting

### Dispositivo no detectado
```powershell
# Reconectar WiFi
cd C:\platform-tools
.\adb.exe connect 192.168.1.50:5555

# O usar USB directamente (más confiable)
flutter run -d R58W315389R
```

### Hot reload no funciona
```powershell
# Presiona R (hot restart completo)
# O reinicia la app:
flutter run
```

### Errores de compilación
```powershell
flutter clean
flutter pub get
flutter run
```
