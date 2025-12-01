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

PARTE 2: EMOJIS PERSONALIZADOS
[EMOJI-003] UI: Pantalla de gestión de estados

Prioridad: ALTA
Estimación: 4h

Descripción:
Crear pantalla "Mis Estados" en Configuración.

Layout:

┌─────────────────────────────────────┐
│  ← Mis Estados                      │
├─────────────────────────────────────┤
│                                     │
│  Estados de ZYNC                    │
│  ─────────────────────               │
│  🏠 En casa                         │
│  🏫 En el colegio                   │
│  🚗 En camino                       │
│  ... (mostrar 5)                    │
│  [Ver todos (15)] ▼                 │
│                                     │
│  Mis estados personalizados         │
│  ─────────────────────               │
│  🏊 Natación              [🗑️]      │
│  🎸 Clase de guitarra     [🗑️]      │
│  🏥 Doctor                [🗑️]      │
│                                     │
│  [+ Crear estado personalizado]     │
│                                     │
│  ℹ️ Tu círculo puede usar todos     │
│     estos estados                   │
│                                     │
└─────────────────────────────────────┘

Funcionalidad:
- Ver predefinidos (colapsables si son muchos)
- Ver customs (lista completa)
- Crear nuevo custom
- Borrar custom (solo si lo creaste tú)
- Info tooltip: "Cualquier miembro puede crear estados"

Criterio de aceptación:
✅ Lista predefinidos y customs claramente diferenciados
✅ Botón crear custom visible
✅ Botón borrar solo en customs
✅ UI responsive y clara

Testing:
- Ver pantalla con solo predefinidos → OK
- Agregar 1 custom → Aparece en lista
- Agregar 10 customs → Lista hace scroll
- Intentar borrar predefinido → Botón no existe

[EMOJI-004] Implementar emoji picker del sistema
Prioridad: ALTA
Estimación: 3h

Descripción:
Integrar selector de emojis del sistema operativo.

Opciones técnicas:

OPCIÓN A (Recomendada): Usar package Flutter
Package: emoji_picker_flutter: ^1.6.0

Ventajas:
- ✅ Cross-platform (iOS + Android)
- ✅ Incluye búsqueda
- ✅ Categorías organizadas
- ✅ Skintons support
- ✅ Actualizado con últimos emojis

OPCIÓN B: Native picker
- iOS: textField.inputView = emojiKeyboard
- Android: textField.inputType = TYPE_TEXT_VARIATION_SHORT_MESSAGE

Ventajas:
- ✅ Usa picker nativo (familiar para usuario)
Desventajas:
- ❌ Más complejo de integrar
- ❌ Diferente en iOS vs Android

Recomendación: OPCIÓN A (emoji_picker_flutter)

Implementación:
Al tocar [+ Crear estado personalizado]:

1. Muestra modal:
   ┌─────────────────────────┐
   │  Nuevo Estado           │
   ├─────────────────────────┤
   │  Emoji:                 │
   │  [🏊] ← Tap para elegir │
   │                         │
   │  Nombre:                │
   │  [Natación_______]      │
   │                         │
   │  [Cancelar]  [Guardar]  │
   └─────────────────────────┘

2. Tap en [🏊]:
   → Abre emoji picker (bottom sheet)
   → Usuario selecciona emoji
   → Emoji se muestra en el campo

3. Usuario escribe nombre

4. Tap [Guardar]:
   → Valida (emoji + nombre no vacíos)
   → Guarda en Firestore
   → Vuelve a lista

Validaciones:
- Emoji requerido
- Nombre requerido (2-30 caracteres)
- No duplicar emoji+nombre exacto
- Límite: 10 customs por círculo (freemium)

Criterio de aceptación:
✅ Emoji picker se abre suavemente
✅ Usuario puede buscar emojis
✅ Emoji seleccionado se muestra en campo
✅ Validación funciona
✅ Custom emoji se guarda en Firestore

Testing:
- Abrir picker → Muestra emojis
- Buscar "swim" → Muestra 🏊
- Seleccionar 🏊 → Se muestra en campo
- Guardar sin nombre → Error
- Guardar completo → Aparece en lista
- Intentar crear 11vo custom → Error (límite)

[EMOJI-005] Lógica de compartición en círculo
Prioridad: ALTA
Estimación: 2h

Descripción:
Definir cómo los customs se comparten en el círculo.

Decisión de producto (según lo que definimos):

✅ EMOJIS COMPARTIDOS (todos pueden usar)

Comportamiento:
1. Usuario A crea custom: 🏊 Natación
   → Se guarda en circles/{circleId}/customEmojis/
   → createdBy: userA

2. Usuario B abre selector de estado
   → Ve predefinidos (15)
   → Ve customs del círculo (incluyendo 🏊 Natación)
   → Puede usar 🏊 Natación aunque no lo creó él

3. Usuario B intenta borrar 🏊 Natación
   → Botón 🗑️ está deshabilitado
   → Tooltip: "Solo el creador puede borrar este estado"

4. Usuario A borra 🏊 Natación
   → Se elimina de circles/{circleId}/customEmojis/
   → Todos los miembros dejan de verlo
   → Si alguien lo estaba usando → cambia a ✅ Disponible

Reglas:
- Customs son compartidos (todos ven y usan)
- Solo creador puede borrar
- Si emoji en uso es borrado → estado cambia a default

Criterio de aceptación:
✅ Customs visibles para todo el círculo
✅ Todos pueden usar customs
✅ Solo creador puede borrar
✅ Borrar emoji en uso no rompe estados

Testing:
- Usuario A crea 🏊
- Usuario B ve 🏊 en su lista → OK
- Usuario B usa 🏊 → Estado se actualiza
- Usuario C intenta borrar 🏊 → Botón disabled
- Usuario A borra 🏊 → Desaparece de lista de B y C
- Usuario B tenía estado 🏊 → Cambia a ✅ Disponible

PARTE 3: SELECTOR DE ESTADO (CORE UX)
[EMOJI-006] Modal de selección rápida de estado

Prioridad: CRÍTICA
Estimación: 5h

Descripción:
Este es el corazón del producto.
Modal que aparece cuando usuario quiere cambiar estado.

Trigger points:
1. Tap en botón principal de home
2. Tap en tu propia card de estado
3. Notificación de ZYNC → Tap
4. Quick Actions widget (ya implementado)

Layout del modal:

┌─────────────────────────────────────┐
│  ¿Cómo estás?                       │
├─────────────────────────────────────┤
│                                     │
│  [Últimos usados]                   │
│  🏠    🚗    📚    😴              │
│                                     │
│  [Frecuentes]                       │
│  🏫 Colegio    🍽️ Comiendo         │
│  💤 Durmiendo  👥 Reunión           │
│                                     │
│  [Todos los estados]   [🔍]         │
│                                     │
│  📍 Lugares:                        │
│  🏠 Casa   🏫 Colegio  🏢 Trabajo   │
│                                     │
│  🚗 Transporte:                     │
│  🚗 En camino   🚶 Caminando        │
│                                     │
│  [Tus estados personalizados]       │
│  🏊 Natación   🎸 Guitarra          │
│                                     │
│  [+ Crear personalizado]            │
│                                     │
└─────────────────────────────────────┘

Secciones:

1. ÚLTIMOS USADOS (4 emojis grandes)
   - Tus últimos 4 estados usados
   - Un tap → Cambio inmediato

2. FRECUENTES (4-6 estados)
   - Los que más usas (por usageCount)
   - Calculado por círculo

3. TODOS LOS ESTADOS
   - Agrupados por categoría
   - Scroll vertical
   - Búsqueda 🔍

4. TUS PERSONALIZADOS
   - Destacados al final
   - [+] para crear nuevo

Comportamiento:
- Tap en emoji → Cambio INSTANTÁNEO
  - No requiere confirmación
  - Modal se cierra
  - Estado se actualiza en Firestore
  - Círculo recibe notificación

- [🔍] Buscar:
  - Input aparece arriba
  - Filtra en tiempo real
  - Busca por label ("casa", "colegio")

Smart ordering:
- Primero: Últimos 4 usados
- Segundo: Frecuentes (por usageCount)
- Tercero: Predefinidos por categoría
- Cuarto: Personalizados

Criterio de aceptación:
✅ Modal se abre rápido (<300ms)
✅ Últimos 4 son los correctos
✅ Frecuentes están ordenados por uso
✅ Búsqueda filtra correctamente
✅ Cambio de estado es instantáneo
✅ Animación suave al cambiar

Testing:
- Abrir modal → Muestra correctamente
- Tap en 🏠 → Estado cambia a "En casa"
- Usar 🏊 3 veces → Aparece en frecuentes
- Buscar "cole" → Filtra "🏫 Colegio"
- Cerrar modal sin elegir → No cambia estado

[EMOJI-007] Actualización en tiempo real del estado
Prioridad: CRÍTICA
Estimación: 3h

Descripción:
Cuando usuario cambia estado, toda la app y círculo
debe reflejarlo INMEDIATAMENTE.

Flow completo:

1. Usuario elige emoji en modal
   ↓
2. App actualiza Firestore:
   circles/{circleId}/members/{userId}
   {
     currentState: {
       emojiId: "custom_swimming",
       emoji: "🏊",
       label: "Natación",
       source: "manual",
       priority: 2,
       updatedAt: NOW
     }
   }
   ↓
3. Firestore trigger detecta cambio
   ↓
4. Cloud Function: notifyCircleOnStatusChange()
   → Envía push a todos los miembros
   ↓
5. Apps de miembros:
   → Escuchan Firestore realtime
   → Actualizan UI automáticamente

UI Updates:

En TU app:
- Modal se cierra
- Tu card en home muestra nuevo estado
- Animación de cambio (fade in/out)

En apps del círculo:
- Push notification aparece
- Si app está abierta:
  → Card se actualiza en tiempo real
  → Animación de cambio
- Si app está cerrada:
  → Push notification muestra el cambio

Optimizaciones:
- No notificar si cambias al MISMO estado
- Throttle: Si cambias 3 veces en 10 seg → Solo notifica última
- Offline: Queue cambios, sync cuando hay internet

Criterio de aceptación:
✅ Cambio local es instantáneo (<100ms)
✅ Círculo recibe push en <5 segundos
✅ Apps abiertas actualizan sin refresh
✅ Funciona offline (sync después)

Testing:
- Usuario A cambia a 🏠 → Card actualiza inmediatamente
- Usuario B (en círculo) ve cambio en <5 seg
- Usuario B tiene app abierta → Actualiza sin push
- Usuario A sin internet → Cambio local OK, sync cuando conecta
- Cambiar 5 veces rápido → Solo notifica última vez

PARTE 4: OPTIMIZACIONES & ANALYTICS
[EMOJI-008] Analytics de uso de estados

Prioridad: MEDIA
Estimación: 2h

Descripción:
Trackear qué estados se usan más para:
1. Ordenar por frecuencia
2. Sugerir estados faltantes
3. Mejorar predefinidos en futuras versiones

Eventos a trackear:

1. emoji_used:
   - emojiId
   - emoji
   - label
   - isPredefined: bool
   - circleId
   - userId
   - timestamp

2. emoji_created:
   - emoji
   - label
   - circleId
   - userId

3. emoji_deleted:
   - emoji
   - label
   - circleId

Storage:
- Firestore: circles/{circleId}/emojiStats/{emojiId}
  {
    emojiId: String,
    usageCount: int,
    lastUsed: DateTime,
    createdBy: String (si es custom)
  }

- Incrementar usageCount cada vez que se usa
- Usar esto para ordenar "Frecuentes"

Criterio de aceptación:
✅ Cada uso incrementa counter
✅ lastUsed se actualiza
✅ Frecuentes se ordenan correctamente

Testing:
- Usar 🏠 5 veces → usageCount = 5
- Usar 🏫 10 veces → Aparece primero en frecuentes
- No usar 😴 nunca → No aparece en frecuentes

[EMOJI-009] Límites y validaciones
Prioridad: MEDIA
Estimación: 2h

Descripción:
Implementar límites para evitar abuso/spam.

Límites freemium:
- Máx 10 customs por círculo
- Máx 30 caracteres por label
- No emojis duplicados en mismo círculo

Límites premium (futuro):
- Customs ilimitados

Validaciones al crear:

1. Límite de cantidad:
   if (customEmojis.length >= 10) {
     throw "Has alcanzado el límite de estados personalizados (10).
            Borra alguno o actualiza a Premium.";
   }

2. Emoji + label duplicado:
   if (exists(emoji + label)) {
     throw "Ya existe un estado con ese emoji y nombre";
   }

3. Label apropiado:
   - Min 2 caracteres
   - Max 30 caracteres
   - No solo espacios
   - No caracteres especiales raros

4. Prevención de spam:
   - Max 5 customs creados por usuario en 1 hora
   - Rate limit

Criterio de aceptación:
✅ Límite de 10 se respeta
✅ No se pueden crear duplicados
✅ Validaciones muestran mensajes claros
✅ Rate limit previene spam

Testing:
- Crear 10 customs → OK
- Intentar 11vo → Error con mensaje claro
- Intentar duplicar 🏊 Natación → Error
- Label de 1 caracter → Error
- Label de 50 caracteres → Error
- Crear 6 customs en 1 min → Rate limit

[EMOJI-010] Migración de datos (si ya tienes beta users)
Prioridad: BAJA (solo si ya tienes usuarios)
Estimación: 2h

Descripción:
Si ya tienes usuarios en beta con estados antiguos,
necesitas migrar a nueva estructura.

Script de migración:

1. Para cada círculo:
   - Leer estados actuales de miembros
   - Mapear a nuevos emojiIds
   - Actualizar referencias

2. Agregar predefinidos globales:
   - Crear collection predefinedEmojis
   - Popular con 15 estados base

3. Mantener customs existentes:
   - Migrar a circles/{circleId}/customEmojis/

Rollback plan:
- Backup de Firestore antes de migrar
- Script de rollback si algo falla

Criterio de aceptación:
✅ Todos los estados migran correctamente
✅ No se pierden datos
✅ Backward compatible (versiones viejas siguen funcionando)

Testing:
- Migrar círculo de prueba → OK
- Verificar estados se ven correctos
- Rollback de prueba → Vuelve a estado anterior

TESTING COMPLETO DE ESTADOS
[EMOJI-TEST] Suite de testing

Prioridad: ALTA
Estimación: 3h

Tests críticos:

TEST 1: Crear custom emoji
- Abrir modal crear
- Elegir 🏊
- Escribir "Natación"
- Guardar
- Verificar: Aparece en lista
- Verificar: Se guarda en Firestore
✅ PASS / ❌ FAIL

TEST 2: Usar custom emoji
- Usuario A crea 🏊 Natación
- Usuario B abre selector
- Usuario B ve 🏊 Natación
- Usuario B selecciona 🏊
- Verificar: Estado cambia
- Verificar: Usuario A recibe notificación
✅ PASS / ❌ FAIL

TEST 3: Borrar custom emoji
- Usuario A borra 🏊
- Verificar: Desaparece de su lista
- Verificar: Desaparece de lista de Usuario B
- Verificar: Si B lo estaba usando → cambia a default
✅ PASS / ❌ FAIL

TEST 4: Límite de 10 customs
- Crear 10 customs
- Intentar crear 11vo
- Verificar: Muestra error
✅ PASS / ❌ FAIL

TEST 5: Estados frecuentes
- Usar 🏠 10 veces
- Usar 🏫 5 veces
- Usar 🚗 2 veces
- Abrir selector
- Verificar: Orden es 🏠, 🏫, 🚗
✅ PASS / ❌ FAIL

TEST 6: Búsqueda
- Abrir selector
- Tap 🔍
- Escribir "casa"
- Verificar: Solo muestra 🏠 Casa
✅ PASS / ❌ FAIL

TEST 7: Cambio en tiempo real
- Usuario A cambia a 🏊
- Usuario B tiene app abierta
- Verificar: B ve cambio en <5 segundos sin refresh
✅ PASS / ❌ FAIL

TEST 8: Offline
- Desconectar internet
- Cambiar estado a 😴
- Verificar: Cambio local funciona
- Reconectar
- Verificar: Se sincroniza con Firestore
✅ PASS / ❌ FAIL

TEST 9: Predefinidos no se pueden borrar
- Intentar borrar 🏠 Casa
- Verificar: No hay botón borrar
✅ PASS / ❌ FAIL

TEST 10: Emoji duplicado
- Crear 🏊 Natación
- Intentar crear 🏊 Natación otra vez
- Verificar: Error de duplicado
✅ PASS / ❌ FAIL

---

RESUMEN EJECUTIVO
Decisión de producto:
✅ OPCIÓN B: Predefinidos + Emoji Picker del Sistema
Incluir en MVP:

15-20 emojis predefinidos (esenciales)
Emoji picker del sistema para customs
Límite: 10 customs por círculo (freemium)
Customs compartidos en el círculo
Solo creador puede borrar

NO incluir (postponer):

Biblioteca curada de 200+ emojis
Premium con customs ilimitados
Sugerencias inteligentes de emojis
Sync de emojis entre círculos

---
## ✅ **CHECKLIST FINAL**

☐ 16 emojis predefinidos definidos y guardados
☐ Estructura Firestore para customs implementada
☐ Emoji picker del sistema integrado
☐ Modal selector funcionando
☐ Cambios en tiempo real funcionan
☐ Customs compartidos en círculo
☐ Solo creador puede borrar
☐ Límite de 10 customs se respeta
☐ Búsqueda de emojis funciona
☐ Frecuentes se ordenan correctamente
☐ Tests críticos pasan (80%+)