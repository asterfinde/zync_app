# 📋 BACKLOG: MANTENIMIENTO DE ESTADOS/EMOJIS

**Emojis predefinidos + picker del sistema**

## Contexto

#### Funcionalidad

Usuario ve:

Estados predefinidos:

- 🏠 Casa
- 🏫 Colegio
- ... (15 emojis)

**[+ Agregar personalizado]** → Abre emoji picker del sistema

- Usuario elige: 🏊
- Escribe label: "Natación"

Ahora tiene 16 emojis (15 default + 1 custom)

#### Ventajas

✅ Flexibilidad total  
✅ No necesitas incluir biblioteca de emojis (usa sistema operativo)  
✅ Familias personalizan según sus necesidades  
✅ Feature diferenciadora vs competencia

#### Por qué

**Rápido de implementar**

Flutter tiene emoji_picker_flutter package  
O simplemente usas el picker nativo del sistema  
2-3 horas de desarrollo

**Máxima flexibilidad**

Familias peruanas tendrán necesidades que NO puedes predecir  
Ejemplo:  
- Familia con hijo nadador → 🏊  
- Familia con hijo con terapia → 🏥  
- Familia religiosa → ⛪

#### Feature diferenciadora

Life360 NO tiene esto  
"ZYNC se adapta a TU familia, no al revés"

#### Emojis inapropiados

Problema de emojis inapropiados es menor de lo que piensas

Es un círculo FAMILIAR (papá, mamá, hijos)  
Nadie va a poner 🍆 porque su familia lo verá  
Autorregulación natural


#### Implementación híbrida

|                                    |
|------------------------------------|
| **Selecciona tu estado**           |
|                                    |
| **Estados frecuentes** ← Tus últimos 4 |
| 🏠 🚗 😴 📚                     |
|                                    |
| **Estados predefinidos** ← 15-20 defaults |
| 🏠 Casa                            |
| 🏫 Colegio                         |
| 🚗 En camino                       |
| 😴 Durmiendo                       |
| ... (más)                          |
|                                    |
| **Tus estados personalizados** ← Custom del usuario |
| 🏊 Natación                        |
| 🎸 Guitarra                        |
|                                    |
| **[+ Crear estado personalizado]** |
|                                    |

**Al tocar [+ Crear personalizado]:**  
→ Abre emoji picker del sistema  
→ Usuario elige emoji  
→ Escribe label  
→ Se agrega a "Tus estados personalizados"

**Esto cubre el 100% de casos de uso.**

---

## BACKLOG

### PARTE 1: ESTADOS PREDEFINIDOS
**[EMOJI-001] Definir y crear/revisar estados predefinidos**

Prioridad: CRÍTICA
Estimación: 2h

Descripción:
Crear/revisar la lista atual de la app de los emojis/estados predefinidos que TODA app incluye por default.
Agruparlos por tipo

Estados esenciales (**14 mínimo**s):

📍 UBICACIÓN:
- 🏠 En casa
- 🏫 En el colegio
- 🏢 En el trabajo
- 🏥 En consulta médica
- 🏪 De compras
...

🚗 TRANSPORTE:
- 🚗 En camino
- 🚶 Caminando
- 🚌 En transporte público
...

💤 ACTIVIDAD:
- 😴 Durmiendo
- 📚 Estudiando
- 🍽️ Comiendo
- 💪 Ejercicio
...

✅ DISPONIBILIDAD:
- ✅ Disponible
- 🔴 No molestar
- 👥 En reunión
...

Estructura de datos:
{
  id: "predefined_home",
  emoji: "🏠",
  label_es: "En casa",
  label_en: "At home", // Para futuro
  category: "location",
  isPredefined: true,
  canDelete: false,
  order: 1
}

Guardar en:
- assets/predefined_emojis.json
- O Firestore collection "predefinedEmojis" (global)

Criterio de aceptación:
- ✅ Lista de 14-16 emojis/estados definida
- ✅ Traducible (preparado para internacionalización)
- ✅ Categorizada
- ✅ Ordenada por relevancia

Testing:
- ¿Falta algún estado obvio?

---

**[EMOJI-002] Modelo de datos para estados**

Prioridad: CRÍTICA
Estimación: 3h

Descripción:
Definir estructura de datos completa para estados.

Entidades:

1. PredefinedEmoji (global, mismo para todos):
{
  id: String,
  emoji: String,
  labelEs: String,
  labelEn: String,
  category: String, // location, transport, activity, availability
  isPredefined: true,
  canDelete: false,
  order: int
}

2. CustomEmoji (por círculo):
{
  id: String,
  circleId: String,
  emoji: String, // Del picker del sistema
  label: String, // Usuario escribe
  createdBy: String, // userId
  createdAt: DateTime,
  isPredefined: false,
  canDelete: true,
  usageCount: int, // Para ordenar por frecuencia
  lastUsed: DateTime
}

3. UserCurrentState (estado actual del usuario):
{
  userId: String,
  circleId: String,
  emojiId: String, // Ref a PredefinedEmoji o CustomEmoji
  emoji: String, // Duplicado para query rápido
  label: String, // Duplicado
  source: String, // "manual", "geofence", "scheduled"
  priority: int, // 1=sos, 2=manual, 3=scheduled, 4=geofence
  updatedAt: DateTime,
  scheduledUntil: DateTime? // null si no es scheduled
}

Firestore structure:
/predefinedEmojis/{emojiId} (global)
/circles/{circleId}/customEmojis/{emojiId}
/circles/{circleId}/members/{userId} (incluye currentState)

Criterio de aceptación:
- ✅ Estructura soporta predefinidos + custom
- ✅ Estructura soporta múltiples círculos (futuro)
- ✅ Queries eficientes
- ✅ No duplica data innecesariamente

Testing:
- Crear emoji predefinido → Leer OK
- Crear emoji custom → Leer OK
- Cambiar estado → Actualiza correctamente
- Query: Estados de un círculo → Devuelve predefinidos + customs

---

### PARTE 2: EMOJIS PERSONALIZADOS

en proceso...