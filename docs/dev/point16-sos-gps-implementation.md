# Point 16: SOS con GPS - Documentación Técnica

## 📋 Objetivo
Implementar funcionalidad GPS que automáticamente capture y envíe la ubicación del usuario cuando selecciona el estado SOS (🆘), permitiendo a otros miembros del círculo ver la ubicación y abrir Google Maps.

## 🔧 Componentes Implementados

### 1. GPSService (`lib/core/services/gps_service.dart`)
**Funcionalidades:**
- ✅ `getCurrentLocation()`: Obtiene coordenadas GPS con precisión alta
- ✅ `hasLocationPermissions()`: Verifica permisos de ubicación
- ✅ `generateGoogleMapsUrl()`: Crea URL de Google Maps
- ✅ `generateSOSLocationUrl()`: URL especial para SOS con etiqueta

**Configuración GPS:**
- Precisión: `LocationAccuracy.high`
- Timeout: 10 segundos (optimizado para emergencias)
- Manejo automático de permisos

### 2. StatusService Actualizado
**Nueva Funcionalidad:**
- ✅ Detección automática de estado SOS
- ✅ Captura GPS solo para estados SOS
- ✅ Almacenamiento de coordenadas en Firestore
- ✅ `StatusUpdateResult` incluye coordenadas GPS

**Estructura Firestore:**
```json
{
  "memberStatus": {
    "userId": {
      "statusType": "sos",
      "timestamp": "2025-10-10T...",
      "coordinates": {
        "latitude": -12.0464,
        "longitude": -77.0428
      }
    }
  }
}
```

### 3. InCircleView UI Actualizada
**Funcionalidades Visuales:**
- ✅ Indicador GPS rojo en emoji SOS
- ✅ Card especial para miembros con SOS + GPS
- ✅ "Toca para ver ubicación SOS"
- ✅ Integración con Google Maps al tocar

**Flujo de Interacción:**
1. Miembro selecciona estado SOS 🆘
2. GPS captura ubicación automáticamente
3. Otros miembros ven indicador GPS rojo
4. Toque abre Google Maps con ubicación exacta

### 4. EmojiModal con Feedback GPS
**Mensajes Especiales:**
- ✅ SOS + GPS: "🆘 SOS enviado con ubicación GPS a tu círculo"
- ✅ SOS sin GPS: "🆘 SOS enviado (sin ubicación GPS disponible)"
- ✅ Feedback visual diferenciado (rojo vs naranja)

## 🔒 Permisos Requeridos

### Android (`android/app/src/main/AndroidManifest.xml`)
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
```

### Dependencias (`pubspec.yaml`)
```yaml
dependencies:
  geolocator: ^14.0.2    # GPS/ubicación
  url_launcher: ^6.3.0   # Google Maps
```

## 🎯 Casos de Uso

### Caso 1: SOS con GPS Exitoso
1. Usuario selecciona estado SOS
2. GPS obtiene ubicación en <10s
3. Coordenadas se envían a Firestore
4. Otros miembros ven indicador GPS
5. Toque abre Google Maps con ubicación

### Caso 2: SOS sin GPS (Fallback)
1. Usuario selecciona estado SOS
2. GPS falla (permisos/señal/timeout)
3. Estado SOS se envía sin coordenadas
4. Mensaje: "SOS enviado (sin ubicación GPS disponible)"
5. Funcionalidad básica de SOS se mantiene

### Caso 3: Visualización de SOS GPS
1. Miembro recibe notificación de cambio de estado
2. Ve emoji SOS con indicador GPS rojo
3. Card especial con botón "ver ubicación"
4. Toque abre Google Maps con coordenadas exactas

## 📱 Experiencia de Usuario

### Emisor de SOS:
- Selección normal de estado SOS
- Feedback inmediato con/sin GPS
- No requiere configuración adicional

### Receptor de SOS:
- Indicador visual claro (GPS rojo)
- Card destacada para SOS con ubicación
- Un toque para ver ubicación en Maps

## 🔄 Integración con Sistema Existente

### Compatibilidad:
- ✅ No rompe funcionalidad existente
- ✅ Estados no-SOS funcionan igual
- ✅ Fallback graceful si GPS falla
- ✅ Integración con StatusService existente

### Rendimiento:
- GPS solo se activa para SOS
- Timeout de 10s evita bloqueos
- Coordenadas almacenadas eficientemente

## 🧪 Testing

### Escenarios de Prueba:
1. SOS con GPS habilitado ✅
2. SOS con GPS deshabilitado ✅
3. SOS con permisos denegados ✅
4. SOS con timeout GPS ✅
5. Visualización de SOS de otros ✅
6. Apertura de Google Maps ✅

### Estados de Error Manejados:
- Permisos de ubicación denegados
- Servicios de ubicación deshabilitados
- Timeout de GPS (10s)
- Error de red Firestore
- Google Maps no disponible

## 📊 Métricas de Éxito

### Funcional:
- ✅ GPS capturado en <10s para SOS
- ✅ 100% de estados SOS almacenan intento GPS
- ✅ UI responsiva con indicadores claros
- ✅ Google Maps abre correctamente

### No Funcional:
- ✅ No afecta rendimiento para estados no-SOS
- ✅ Fallback graceful en todos los casos de error
- ✅ UX consistente con patrón de aplicación

## 🚀 Próximos Pasos
- [ ] Analytics para uso de GPS en SOS
- [ ] Optimización de precisión GPS
- [ ] Integración con notificaciones push especiales para SOS
- [ ] Configuración de timeout GPS por usuario