# Limpieza de Procesos Dart/Flutter

Scripts para solucionar problemas comunes de procesos huérfanos y cache corrupto.

## Scripts disponibles

### `clean_dart_processes.ps1`
Limpia procesos de Dart/Flutter huérfanos y reconstruye el cache.

**Uso:**
```powershell
.\docs\tec\clean\clean_dart_processes.ps1
```

**Qué hace:**
1. ✅ Lista procesos Dart/Flutter activos
2. 🛑 Detiene todos los procesos (dart, dartaotruntime, dartvm, flutter)
3. 🧹 Ejecuta `flutter clean` (elimina .dart_tool y build)
4. 📦 Ejecuta `flutter pub get` (restaura dependencias)

**Cuándo usar:**
- ❌ Flutter Daemon terminado inesperadamente
- ⚠️ Widget Preview falla
- 🐌 VSCode/Flutter muy lento
- 🔄 Antes de `flutter clean` manual
- 🌿 Al cambiar de rama con cambios grandes
- 🔧 Después de actualizar Flutter SDK

## Problemas comunes

### "The Flutter Daemon has terminated"
**Causa:** Procesos huérfanos del Dart Analysis Server o Flutter Daemon

**Solución:**
```powershell
.\docs\tec\clean\clean_dart_processes.ps1
# Luego en VSCode: Ctrl+Shift+P → "Reload Window"
```

### "Failed to remove .dart_tool"
**Causa:** Procesos tienen archivos bloqueados en `.dart_tool/`

**Solución:**
```powershell
.\docs\tec\clean\clean_dart_processes.ps1
# El script detiene procesos ANTES de flutter clean
```

### VSCode lento o autocompletado no funciona
**Causa:** Dart Analysis Server procesando archivos corruptos

**Solución:**
```powershell
.\docs\tec\clean\clean_dart_processes.ps1
# Reconstruye el cache de análisis
```

## Prevención

### Cerrar correctamente procesos en desarrollo

**Antes de cerrar VSCode:**
```powershell
# Si tienes flutter run activo
Ctrl+C en terminal

# Si tienes build_runner watch
Ctrl+C en terminal
```

**Antes de cambiar de rama:**
```powershell
.\docs\tec\clean\clean_dart_processes.ps1
git checkout otra-rama
```

### Buenas prácticas

1. **No cierres VSCode con procesos activos** - Detén `flutter run` primero
2. **Usa el script antes de `flutter clean`** - Evita errores de bloqueo
3. **Recarga VSCode después del script** - Ctrl+Shift+P → "Reload Window"
4. **Si persiste, reinicia VSCode** - Cierra y abre completamente

## Troubleshooting

### El script no detiene todos los procesos
```powershell
# Fuerza detención con PID específico
taskkill /F /PID <pid>
```

### Error: "flutter: command not found"
```powershell
# Verifica que Flutter esté en PATH
flutter --version

# Si no está, agrega a PATH o usa ruta completa:
C:\src\flutter\bin\flutter.bat clean
```

### Procesos se vuelven a crear inmediatamente
- Cierra VSCode completamente antes de ejecutar el script
- Puede ser que VSCode los esté recreando

---

**Última actualización:** Noviembre 28, 2025
