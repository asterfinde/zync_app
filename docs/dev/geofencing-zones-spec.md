# Especificación: Sistema de Zonas con Actualización Automática

**Fecha:** 11 de Diciembre, 2025  
**Branch:** `feature/geofencing-phase0-mvp`  
**Versión:** 2.0 (Rediseño completo)

---

## 🎯 Filosofía Central

> **"ZYNC informa DÓNDE o QUÉ hace el usuario. NO ambos simultáneamente."**

**NO ES:** "Leonardo está en Casa Y estudiando"  
**ES:** "Leonardo está en Casa" (punto final)

---

## 📍 Sistema de Zonas (2 Tipos)

### **1. Zonas Predefinidas (Opcionales)**

```dart
enum PredefinedZone {
  home('home', '🏠', 'Casa'),
  school('school', '🏫', 'Colegio'),
  university('university', '🎓', 'Universidad'),
  work('work', '💼', 'Trabajo')
}
```

**Características:**
- **Total:** 4 zonas predefinidas
- **Configuración:** Opcional durante setup inicial
- **Emoji fijo:** Cada una tiene emoji específico (🏠🏫🎓💼)
- **Geofencing:** Se activa SOLO si usuario configura ubicación
- **Estado automático:** Cambia según tipo de zona
- **Límite:** Máximo 1 de cada tipo

**Comportamiento:**

**Sin configurar:**
```
Usuario NO configura ubicación de "Casa"
→ Puede usar estado manual 🏠 "En casa" (modo estándar)
→ Sin geofencing
```

**Configurada:**
```
Usuario SÍ configura ubicación de "Casa"
→ Geofencing detecta entrada automática
→ Dashboard: 🏠 "En Casa" + "Desde 10:10 AM"
→ Estado manual 🏠 se OCULTA del selector (evita conflicto)
```

---

### **2. Zonas Personalizadas**

**Características:**
- **Emoji único:** 📍 para todas
- **Nombres:** Descriptivos (Mall, Cine, Estadio, Iglesia, etc.)
- **Límite:** Máximo 6 zonas personalizadas
- **Estado:** Genérico `'available'` (o mantiene último manual)
- **Total sistema:** 4 predefinidas + 6 personalizadas = **10 zonas máximo**

**Ejemplos:**
```
📍 Jockey Plaza Mall
📍 Cine Planet
📍 Estadio Nacional
📍 Iglesia San Pedro
📍 Casa de Abuela
📍 Oficina Cliente X
```

---

## 🎨 Visualización en Dashboard

### **Caso 1: Zona Predefinida (Automática)**
```
┌─────────────────────────────┐
│ 🏠 Leonardo                 │
│ En Casa                     │
│ Desde 10:10 AM              │
└─────────────────────────────┘
```
- **Emoji:** Del tipo de zona (🏠🏫🎓💼)
- **Texto:** "En [Nombre Zona]"
- **Timestamp:** "Desde HH:MM AM/PM" (hora de entrada)
- **Badge:** Ninguno (es automático verificado)

---

### **Caso 2: Zona Personalizada (Automática)**
```
┌─────────────────────────────┐
│ 📍 Leonardo                 │
│ En Torre Real               │
│ Desde 11:30 AM              │
└─────────────────────────────┘
```
- **Emoji:** 📍 (único para todas)
- **Texto:** "En [Nombre descriptivo]"
- **Timestamp:** "Desde HH:MM AM/PM" (hora de entrada)
- **Badge:** Ninguno (es automático verificado)

---

### **Caso 3: Salida de Zona (Automática)**
```
┌─────────────────────────────┐
│ 🚗 Leonardo                 │
│ En camino                   │
│ Desde 11:30 AM              │
└─────────────────────────────┘
```
- **Emoji:** 🚗 (fijo para salidas)
- **Texto:** "En camino"
- **Timestamp:** "Desde HH:MM AM/PM" (hora de salida)
- **Badge:** Ninguno (es automático)

---

### **Caso 4: Estado Manual (Sin Zona)**
```
┌─────────────────────────────┐
│ 📚 Mauricio                 │
│ Estudiando                  │
│ Hace 15 min                 │
│ ✋ Manual                    │
│ ❓ Ubicación desconocida    │
└─────────────────────────────┘
```
- **Emoji:** Del estado elegido (😴📚💼🏃 etc.)
- **Texto:** Label del estado ("Estudiando", "Cansado", etc.)
- **Timestamp:** "Hace X min/horas" (relativo)
- **Badge 1:** ✋ Manual (obligatorio)
- **Badge 2:** ❓ Ubicación desconocida (si no hay zona activa)

---

### **Caso 5: Estado Manual (Con Última Zona)**
```
┌─────────────────────────────┐
│ 📚 Mauricio                 │
│ Estudiando                  │
│ Hace 15 min                 │
│ ✋ Manual                    │
│ 📍 Última: Casa (hace 20m)  │
└─────────────────────────────┘
```
- **Igual que Caso 4 PERO:**
- **Badge 2:** 📍 Última zona verificada + tiempo transcurrido

---

## ⚙️ Reglas de Negocio

### **1. Prioridad de Estados**

```
Geofencing > Estado Manual
```

**Si usuario está físicamente en zona configurada:**
- Geofencing tiene prioridad ABSOLUTA
- Usuario NO puede cambiar a estado manual mientras esté en zona
- Debe salir físicamente de la zona para cambiar estado

**Excepción:** Estado SOS siempre disponible (emergencias)

---

### **2. Conflicto Zonas-Estados**

**Si zona predefinida está configurada:**
```dart
// Estado manual equivalente se OCULTA del selector
if (homeZoneConfigured) {
  // Usuario NO puede seleccionar manualmente 🏠 "En casa"
  // Solo geofencing puede activar 🏠
}
```

**Estados que se ocultan según zonas configuradas:**
- Casa configurada → Oculta 🏠 "En casa"
- Colegio configurado → Oculta 🏫 "En el colegio"
- Universidad configurada → Oculta 🎓 "En la universidad"
- Trabajo configurado → Oculta 💼 "En el trabajo"

---

### **3. Timestamps Diferentes**

```
Zonas (automáticas):    "Desde 10:30 PM"  (hora absoluta de entrada)
Estados (manuales):     "Hace 15 min"      (tiempo relativo desde cambio)
```

**Razón:** Diferenciación clara entre automático y manual

---

### **4. Transparencia Obligatoria**

**Todo estado manual DEBE mostrar:**
1. ✋ Badge "Manual" (siempre visible)
2. ❓ "Ubicación desconocida" (si no hay zona activa)
3. 📍 "Última: [Zona]" (si hubo zona previa en últimos 30 min)

**No se puede ocultar que fue cambio manual**

---

## 🖥️ UI: Mantenimiento de Zonas

### **Pantalla: Lista de Zonas**

```
┌────────────────────────────────┐
│  ← ZONAS GEOGRÁFICAS           │
│                          🐛     │ ← Debug (solo dev)
├────────────────────────────────┤
│                                │
│  📍 4 de 10 zonas              │
│                                │
│  ┌──────────────────────────┐ │
│  │ 🏠 Casa                   │ │
│  │ Jaus - 150m              │ │
│  │ ✏️  🗑️                   │ │
│  └──────────────────────────┘ │
│                                │
│  ┌──────────────────────────┐ │
│  │ 📍 Torre Real             │ │
│  │ Av. Larco 1234 - 200m   │ │
│  │ ✏️  🗑️                   │ │
│  └──────────────────────────┘ │
│                                │
│  [+ CREAR ZONA]                │
│                                │
└────────────────────────────────┘
```

**Funcionalidad:**
- Botón ✏️ → Editar zona
- Botón 🗑️ → Eliminar con confirmación
- [+ CREAR ZONA] → Abre formulario de creación
- 🐛 → Debug widget (solo desarrollo)

---

### **Pantalla: Crear/Editar Zona**

```
┌────────────────────────────────┐
│  ← CREAR ZONA                  │
├────────────────────────────────┤
│  ┌──────────────────────────┐ │
│  │                          │ │
│  │      MAPA GOOGLE         │ │
│  │      (tap para pin)      │ │
│  │          📍              │ │
│  │                          │ │
│  └──────────────────────────┘ │
│                                │
│  🔍 Buscar dirección           │
│  ┌──────────────────────────┐ │
│  │ Av. Larco 1234...        │ │
│  └──────────────────────────┘ │
│                                │
│  Nombre de la zona             │
│  ┌──────────────────────────┐ │
│  │ Casa de Abuela           │ │
│  └──────────────────────────┘ │
│                                │
│  Radio de detección            │
│  🔴─────────●──────────🟢      │
│  50m       150m        500m    │
│                                │
│  [CREAR ZONA]                  │
│                                │
└────────────────────────────────┘
```

**Flujo de Uso:**

1. **Ubicar en Mapa:**
   - Usuario escribe dirección en buscador
   - Mapa se mueve a esa ubicación
   - Usuario arrastra pin 📍 a ubicación exacta
   - O hace tap en mapa para colocar pin

2. **Ingresar Nombre:**
   - Campo de texto obligatorio
   - Validación: No vacío, mínimo 2 caracteres
   - Permite espacios: "Casa de Abuela" ✅
   - No permite solo espacios: "   " ❌

3. **Ajustar Radio:**
   - Slider de 50m a 500m
   - Default: 150m
   - Círculo se actualiza en mapa en tiempo real

4. **Crear Zona:**
   - Validar que no exceda límite (10 total)
   - Guardar en Firestore
   - Volver a lista de zonas

**Validaciones:**
```dart
// Nombre
if (value == null || value.trim().isEmpty) {
  return 'Ingresa un nombre';
}
if (value.trim().length < 2) {
  return 'Mínimo 2 caracteres';
}

// Límite de zonas
if (existingZones.length >= 10) {
  throw 'Máximo 10 zonas alcanzado';
}

// Radio
if (radius < 50 || radius > 500) {
  throw 'Radio entre 50m y 500m';
}
```

---

## 🗄️ Estructura Firestore

### **Zonas:**

```javascript
/circles/{circleId}/zones/{zoneId}
{
  name: "Jaus",
  type: "home",              // home | school | university | work | custom
  isPredefined: true,        // true para las 4 predefinidas
  emoji: "🏠",               // Emoji asociado
  latitude: -12.046374,
  longitude: -77.042793,
  radiusMeters: 150,
  circleId: "circle123",
  createdBy: "user456",
  createdAt: Timestamp
}
```

### **Estados de Usuario (memberStatus):**

```javascript
/circles/{circleId}
{
  memberStatus: {
    "user123": {
      // CASO 1: Zona automática
      statusType: "available",        // Fallback
      customEmoji: "🏠",              // Emoji de zona
      zoneName: "Jaus",               // Nombre de zona
      zoneId: "zone789",              // ID de zona activa
      autoUpdated: true,              // Flag automático
      timestamp: Timestamp,           // Hora de entrada
      
      // CASO 2: Estado manual
      statusType: "studying",         // Estado elegido
      customEmoji: null,              // Sin emoji de zona
      zoneName: null,                 // Sin zona
      zoneId: null,                   // Sin zona activa
      autoUpdated: false,             // Manual
      lastKnownZone: "zone789",       // Última zona verificada (opcional)
      lastKnownZoneTime: Timestamp,   // Cuándo salió de última zona
      timestamp: Timestamp            // Hora de cambio manual
    }
  }
}
```

---

## 🔧 Lógica de Detección

### **GeofencingService (Actualizado)**

```dart
Future<void> _updateUserStatusByZoneEvent({
  required bool isEntry,
  Zone? zone,
}) async {
  final Map<String, dynamic> statusData = {
    'timestamp': FieldValue.serverTimestamp(),
  };

  if (isEntry && zone != null) {
    // ENTRADA A ZONA
    if (zone.isPredefined) {
      // Zona predefinida: emoji específico
      statusData['customEmoji'] = zone.emoji;  // 🏠🏫🎓💼
      statusData['statusType'] = _getStatusFromZoneType(zone.type);
    } else {
      // Zona personalizada: emoji genérico
      statusData['customEmoji'] = '📍';
      statusData['statusType'] = 'available';
    }
    
    statusData['zoneName'] = zone.name;
    statusData['zoneId'] = zone.id;
    statusData['autoUpdated'] = true;
    
  } else {
    // SALIDA DE ZONA
    statusData['statusType'] = 'driving';
    statusData['customEmoji'] = '🚗';
    statusData['zoneName'] = 'En camino';
    statusData['zoneId'] = null;
    statusData['autoUpdated'] = true;
    
    // Guardar última zona conocida
    if (_currentZoneId != null) {
      statusData['lastKnownZone'] = _currentZoneId;
      statusData['lastKnownZoneTime'] = FieldValue.serverTimestamp();
    }
  }

  await FirebaseFirestore.instance
      .collection('circles')
      .doc(_currentCircleId)
      .update({
    'memberStatus.${user.uid}': statusData,
  });
}

String _getStatusFromZoneType(String type) {
  switch (type) {
    case 'home':
      return 'available';   // 🟢 Disponible
    case 'school':
      return 'studying';    // 📚 Estudiando
    case 'university':
      return 'studying';    // 📚 Estudiando
    case 'work':
      return 'busy';        // 🔴 Ocupado
    default:
      return 'available';
  }
}
```

---

## 📱 InCircleView (Renderizado)

### **Lógica de Parseo:**

```dart
Map<String, dynamic> _parseMemberData(Map<String, dynamic> statusData) {
  final statusType = statusData['statusType'] as String?;
  final customEmoji = statusData['customEmoji'] as String?;
  final zoneName = statusData['zoneName'] as String?;
  final autoUpdated = statusData['autoUpdated'] as bool? ?? false;
  final lastKnownZone = statusData['lastKnownZone'] as String?;
  final lastKnownZoneTime = statusData['lastKnownZoneTime'] as Timestamp?;
  
  String emoji;
  String? displayText;
  String? badgeText;
  String? locationInfo;
  
  if (autoUpdated && customEmoji != null) {
    // CASO: Zona automática
    emoji = customEmoji;           // 🏠 o 📍 o 🚗
    displayText = zoneName;        // "En Jaus" o "En Torre Real"
    badgeText = null;              // Sin badge (es automático)
    locationInfo = null;
    
  } else {
    // CASO: Estado manual
    emoji = _getPredefinedEmoji(statusType);  // 😴📚💼 etc.
    displayText = _getStatusLabel(statusType); // "Cansado", "Estudiando"
    badgeText = '✋ Manual';                   // Badge obligatorio
    
    // Ubicación desconocida o última zona
    if (lastKnownZone != null && lastKnownZoneTime != null) {
      final elapsed = DateTime.now().difference(lastKnownZoneTime.toDate());
      if (elapsed.inMinutes < 30) {
        locationInfo = '📍 Última: ${_getZoneName(lastKnownZone)} (hace ${_formatDuration(elapsed)})';
      } else {
        locationInfo = '❓ Ubicación desconocida';
      }
    } else {
      locationInfo = '❓ Ubicación desconocida';
    }
  }
  
  return {
    'emoji': emoji,
    'displayText': displayText,
    'badgeText': badgeText,
    'locationInfo': locationInfo,
    'autoUpdated': autoUpdated,
    'lastUpdate': statusData['timestamp'],
  };
}
```

### **Renderizado UI:**

```dart
Widget _buildMemberCard(Map<String, dynamic> data) {
  final emoji = data['emoji'] as String;
  final displayText = data['displayText'] as String?;
  final badgeText = data['badgeText'] as String?;
  final locationInfo = data['locationInfo'] as String?;
  final autoUpdated = data['autoUpdated'] as bool;
  final lastUpdate = data['lastUpdate'] as Timestamp?;
  
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Text(emoji, style: TextStyle(fontSize: 32)),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nickname, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                if (displayText != null)
                  Text(displayText, style: TextStyle(fontSize: 14, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
      SizedBox(height: 8),
      
      // Timestamp
      if (lastUpdate != null)
        Text(
          autoUpdated 
            ? 'Desde ${_formatAbsoluteTime(lastUpdate)}'  // "Desde 10:30 PM"
            : 'Hace ${_formatRelativeTime(lastUpdate)}',  // "Hace 15 min"
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      
      // Badges (solo para manual)
      if (badgeText != null) ...[
        SizedBox(height: 4),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(badgeText, style: TextStyle(fontSize: 11)),
        ),
      ],
      
      // Ubicación (solo para manual)
      if (locationInfo != null) ...[
        SizedBox(height: 4),
        Text(locationInfo, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
      ],
    ],
  );
}
```

---

## 🎯 Setup Inicial (Primera Vez)

### **Flujo Onboarding:**

```
┌────────────────────────────────┐
│  Configurar Zonas Automáticas  │
│                                │
│  Las zonas te permiten saber   │
│  automáticamente cuándo llegan │
│  tus familiares a lugares      │
│  importantes                   │
│                                │
│  [Configurar ahora]            │
│  [Omitir por ahora]            │
└────────────────────────────────┘

Si elige [Configurar ahora]:

┌────────────────────────────────┐
│  🏠 Casa (Obligatoria)         │
│                                │
│  [Configurar ubicación]        │
└────────────────────────────────┘

┌────────────────────────────────┐
│  🏫 Colegio (Opcional)         │
│                                │
│  [Configurar ubicación]        │
│  [Omitir]                      │
└────────────────────────────────┘

┌────────────────────────────────┐
│  🎓 Universidad (Opcional)     │
│                                │
│  [Configurar ubicación]        │
│  [Omitir]                      │
└────────────────────────────────┘

┌────────────────────────────────┐
│  💼 Trabajo (Opcional)         │
│                                │
│  [Configurar ubicación]        │
│  [Omitir]                      │
└────────────────────────────────┘

┌────────────────────────────────┐
│  ✅ Configuración completada   │
│                                │
│  Podrás agregar más zonas      │
│  personalizadas después desde  │
│  Configuración                 │
│                                │
│  [Comenzar a usar ZYNC]        │
└────────────────────────────────┘
```

---

## ✅ Checklist de Implementación

### **Fase 1: Estructura Base**
- [ ] Actualizar `Zone` entity con `isPredefined` y `emoji`
- [ ] Agregar `university` a `ZoneType` enum
- [ ] Eliminar o renombrar `other` → `custom`
- [ ] Actualizar Firestore structure para `memberStatus`
- [ ] Agregar campos `lastKnownZone` y `lastKnownZoneTime`

### **Fase 2: UI Zonas**
- [ ] Actualizar `ZoneForm` (sin selector de tipo)
- [ ] Mejorar buscador de dirección en mapa
- [ ] Validación de nombres (espacios permitidos)
- [ ] Mostrar emoji en lista según `isPredefined`

### **Fase 3: Lógica Geofencing**
- [ ] Actualizar `GeofencingService._updateUserStatusByZoneEvent()`
- [ ] Implementar guardado de última zona conocida
- [ ] Mapeo de tipos a estados correctos
- [ ] Manejo de emoji 📍 para zonas personalizadas

### **Fase 4: Renderizado Dashboard**
- [ ] Actualizar `InCircleView._parseMemberData()`
- [ ] Implementar badges ✋ Manual
- [ ] Mostrar "❓ Ubicación desconocida"
- [ ] Mostrar "📍 Última: [Zona]"
- [ ] Timestamps: "Desde HH:MM" vs "Hace X min"

### **Fase 5: Conflicto Estados**
- [ ] Ocultar estados manuales si zona configurada
- [ ] Validar en selector de estados
- [ ] Mostrar mensaje informativo si intenta cambiar desde zona

### **Fase 6: Setup Inicial**
- [ ] Pantalla onboarding zonas predefinidas
- [ ] Flujo obligatorio Casa, opcionales resto
- [ ] Permitir omitir setup completo

### **Fase 7: Testing**
- [ ] Test entrada zona predefinida → emoji correcto
- [ ] Test entrada zona personalizada → 📍
- [ ] Test salida zona → 🚗 En camino
- [ ] Test estado manual → badges ✋ + ❓
- [ ] Test última zona conocida → 📍 Última
- [ ] Test límite 10 zonas

---

## 🎯 Resultado Final Esperado

### **Dashboard Típico:**

```
┌─────────────────────────────────────┐
│  CÍRCULO: Familia López             │
├─────────────────────────────────────┤
│  🏠 Leonardo                        │
│  En Casa                            │
│  Desde 10:10 AM                     │
├─────────────────────────────────────┤
│  🏫 Sebastián                       │
│  En Colegio San Agustín             │
│  Desde 7:45 AM                      │
├─────────────────────────────────────┤
│  📍 Mauricio                        │
│  En Torre Real                      │
│  Desde 9:00 AM                      │
├─────────────────────────────────────┤
│  📚 María                           │
│  Estudiando                         │
│  Hace 15 min                        │
│  ✋ Manual                           │
│  📍 Última: Casa (hace 20m)         │
└─────────────────────────────────────┘
```

**Transparencia lograda:**
- ✅ Zonas automáticas claramente identificadas
- ✅ Estados manuales con badge obligatorio
- ✅ Última ubicación conocida cuando relevante
- ✅ Privacidad respetada (no ubicación exacta en manual)
- ✅ Honestidad forzada (no puede ocultar que fue manual)

---

**FIN DE ESPECIFICACIÓN**
