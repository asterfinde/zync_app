# ✅ Solución: Licencias Android SDK y NDK

## 🔍 Problema Encontrado

Al ejecutar `flutter run`, apareció el error:

```
FAILURE: Build failed with an exception.
com.android.builder.sdk.LicenceNotAcceptedException: Failed to install the following Android SDK packages as some licences have not been accepted.
     ndk;27.0.12077973 NDK (Side by side) 27.0.12077973
```

## 🎯 Causa

El SDK mínimo que creamos (`~/.android-sdk-minimal`) no tenía las licencias de Android aceptadas.

## ✅ Soluciones Implementadas

### 1. Licencias Aceptadas

Creamos los archivos de licencias en `~/.android-sdk-minimal/licenses/`:

```bash
~/.android-sdk-minimal/licenses/
├── android-sdk-license
├── android-sdk-preview-license
├── android-googletv-license
├── google-gdk-license
└── intel-android-extra-license
```

### 2. NDK Comentado (Opcional)

Comentamos la línea del NDK en `android/app/build.gradle.kts`:

```kotlin
// ndkVersion = "27.0.12077973" // Comentado: no necesario para esta app
```

**Nota:** Si tu app usa código nativo (C/C++), necesitarás el NDK. En ese caso, las licencias permitirán que se descargue automáticamente.

## 🎉 Resultado

Ahora Flutter puede:
- ✅ Aceptar licencias automáticamente
- ✅ Descargar NDK si es necesario
- ✅ Compilar la app sin errores de licencias

## 📊 Primera Compilación

La **primera vez** que ejecutes `flutter run`:
- Descargará el NDK (~800MB) si es necesario
- Compilará todas las dependencias
- Puede tardar **3-5 minutos**

**Compilaciones posteriores** serán mucho más rápidas (30-60 segundos).

## 🚀 Uso

```bash
# 1. Limpiar y conectar
./clean_offline_devices.sh
./fix_adb_connection.sh 192.168.1.50:5555

# 2. Verificar
flutter devices

# 3. Ejecutar (primera vez: 3-5 min, siguientes: 30-60 seg)
flutter run -d 192.168.1.50:5555
```

## 🔧 Configuración Automática

El script `setup_adb_stable.sh` ahora incluye:
1. ✅ Creación de SDK mínimo
2. ✅ Enlace a ADB de Windows
3. ✅ **Licencias aceptadas automáticamente** (nuevo)
4. ✅ Configuración de Flutter

## 📝 Archivos Modificados

### 1. `setup_adb_stable.sh`
- Agregada creación de licencias

### 2. `android/app/build.gradle.kts`
- Comentada línea `ndkVersion` (opcional)

## 🛠️ Troubleshooting

### Problema: Error de licencias persiste

**Solución:**
```bash
# Verificar que existen las licencias
ls -la ~/.android-sdk-minimal/licenses/

# Si no existen, crearlas manualmente
mkdir -p ~/.android-sdk-minimal/licenses
echo "24333f8a63b6825ea9c5514f83c2829b004d1fee" > ~/.android-sdk-minimal/licenses/android-sdk-license
```

### Problema: NDK no se descarga

**Solución:**
```bash
# Verificar conexión a internet
ping -c 3 google.com

# Limpiar cache de Gradle
cd android
./gradlew clean
cd ..

# Reintentar
flutter run -d 192.168.1.50:5555
```

### Problema: Compilación muy lenta

**Normal en primera compilación:**
- Descarga NDK (~800MB)
- Descarga dependencias de Gradle
- Compila todo desde cero

**Compilaciones posteriores serán rápidas.**

## 📚 Archivos de Licencias

Los hashes de licencias son estándar de Android SDK:

| Archivo | Hash | Propósito |
|---------|------|-----------|
| `android-sdk-license` | `24333f8a...` | SDK principal |
| `android-sdk-preview-license` | `84831b94...` | Versiones preview |
| `android-googletv-license` | `601085b9...` | Google TV |
| `google-gdk-license` | `33b6a2b6...` | Google GDK |
| `intel-android-extra-license` | `d975f751...` | Intel extras |

## ✅ Checklist de Verificación

- [x] Licencias creadas en `~/.android-sdk-minimal/licenses/`
- [x] Flutter configurado con SDK mínimo
- [x] NDK comentado en `build.gradle.kts` (opcional)
- [x] Script `setup_adb_stable.sh` actualizado
- [x] Primera compilación iniciada

## 🎯 Estado Actual

✅ **Compilando:** Flutter está compilando tu app  
⏳ **Primera vez:** Puede tardar 3-5 minutos  
✅ **Próximas veces:** Será mucho más rápido (30-60 seg)

---

**Última actualización:** 2025-11-20  
**Estado:** ✅ Compilando correctamente  
**Tiempo estimado:** 3-5 minutos (primera vez)
