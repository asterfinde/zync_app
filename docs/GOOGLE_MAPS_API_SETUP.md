# Configuración Segura de Google Maps API Key

## ✅ Configuración Completada

Este proyecto utiliza un sistema seguro para manejar la Google Maps API Key sin exponerla en el código fuente.

---

## Paso a Paso para Nuevos Desarrolladores

### 1. Crear API Key en Google Cloud Console

1. Ve a [Google Cloud Console](https://console.cloud.google.com/)
2. Selecciona el proyecto **ZYNC** (o créalo)
3. **Habilita las APIs necesarias:**
   - Ve a "APIs & Services" > "Library"
   - Busca y habilita las siguientes APIs (TODAS son necesarias para ZYNC):
     - **Maps SDK for Android** (OBLIGATORIO - para mostrar mapas)
     - **Geocoding API** (OBLIGATORIO - para convertir direcciones a coordenadas en geofencing)
     - **Geolocation API** (RECOMENDADO - para mejorar precisión de ubicación)

4. Crea la API Key:
   - Ve a "APIs & Services" > "Credentials"
   - Click "Create Credentials" > "API Key"
   - Copia la key generada

5. **Restringe la API Key (IMPORTANTE):**
   - Click en la key para editarla
   - **Application restrictions:**
     - Selecciona "Android apps"
     - Package name: `com.datainfers.zync`
     - SHA-1: Obtén ejecutando `cd android && ./gradlew signingReport`
   - **API restrictions:**
     - Marca solo las APIs necesarias
   - Click "Save"

### 2. Configurar en Desarrollo Local

**Edita el archivo:** `android/local.properties`

**Agrega al final:**
```properties
# Google Maps API Key (NO COMMITEAR - protegido por .gitignore)
GOOGLE_MAPS_API_KEY=TU_API_KEY_AQUI
```

**⚠️ IMPORTANTE:** Este archivo está protegido por `.gitignore` y **NUNCA** debe commitearse.

### 3. Verificar Configuración

Ejecuta la app:
```bash
flutter run
```

Si ves errores de API Key, verifica:
1. ✅ `android/local.properties` tiene la key correcta
2. ✅ La API Key está habilitada en Google Cloud Console
3. ✅ Las restricciones de la API Key permiten tu package name

---

## 🚀 Configuración para CI/CD (GitHub Actions, etc.)

### Configurar Variable de Entorno

En tu plataforma de CI/CD, configura la variable de entorno:

**Variable:** `GOOGLE_MAPS_API_KEY`  
**Valor:** Tu API Key de producción

#### GitHub Actions

1. Ve a tu repositorio > Settings > Secrets and variables > Actions
2. Click "New repository secret"
3. Name: `GOOGLE_MAPS_API_KEY`
4. Value: Tu API Key
5. Click "Add secret"

#### Ejemplo de workflow (`.github/workflows/build.yml`):

```yaml
name: Build Android

on:
  push:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Java
        uses: actions/setup-java@v3
        with:
          distribution: 'zulu'
          java-version: '11'
      
      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.x'
      
      - name: Build APK
        env:
          GOOGLE_MAPS_API_KEY: ${{ secrets.GOOGLE_MAPS_API_KEY }}
        run: |
          flutter pub get
          flutter build apk --release
```

---

## 🔒 Seguridad

### ✅ Qué está protegido:

- ✅ `android/local.properties` está en `.gitignore`
- ✅ API Key se lee desde archivo local o variable de entorno
- ✅ AndroidManifest.xml usa placeholder `${GOOGLE_MAPS_API_KEY}`
- ✅ build.gradle.kts inyecta la key en tiempo de compilación

### ❌ Nunca hagas esto:

- ❌ Hardcodear la API Key en AndroidManifest.xml
- ❌ Commitear `local.properties` al repositorio
- ❌ Compartir la API Key en chats o documentación pública

---

## 🔧 Arquitectura Técnica

### Flujo de Configuración:

```
1. local.properties (desarrollo) o ENV (CI/CD)
   ↓
2. build.gradle.kts lee la key
   ↓
3. Inyecta como manifestPlaceholder
   ↓
4. AndroidManifest.xml usa ${GOOGLE_MAPS_API_KEY}
   ↓
5. App compilada con key segura
```

### Archivos Modificados:

- **`android/app/build.gradle.kts`**: Lee la key y la inyecta
- **`android/app/src/main/AndroidManifest.xml`**: Usa placeholder
- **`.gitignore`**: Protege `local.properties`

---

## 🆘 Troubleshooting

### Error: "API Key not found"

**Solución:**
1. Verifica que `android/local.properties` existe y tiene la key
2. Asegúrate de que el formato es: `GOOGLE_MAPS_API_KEY=tu_key_aqui`
3. Limpia y reconstruye: `flutter clean && flutter run`

### Error: "This API key is not authorized"

**Solución:**
1. Ve a Google Cloud Console
2. Verifica que la API Key tiene las restricciones correctas
3. Asegúrate de que el package name es `com.datainfers.zync`
4. Agrega tu SHA-1 fingerprint

### Error en CI/CD

**Solución:**
1. Verifica que la variable de entorno `GOOGLE_MAPS_API_KEY` está configurada
2. Revisa los logs del build para ver si la key se está leyendo correctamente

---

## 📝 Notas Adicionales

- La API Key de desarrollo puede ser diferente a la de producción
- Considera usar diferentes keys para debug y release builds
- Revisa regularmente el uso de la API en Google Cloud Console
- Configura alertas de cuota en Google Cloud Console

---

**Última actualización:** Diciembre 2025  
**Responsable:** Equipo Zync
