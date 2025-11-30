# Manual Seed: Predefined Emojis to Firestore

## IMPORTANTE: El SDK de Flutter está corrupto

Debido a errores masivos en el SDK (`SemanticsAction isn't a type`, etc.), **NO PODEMOS** ejecutar scripts Dart en este momento.

## Solución Temporal: Seed Manual vía Firebase Console

### Paso 1: Ir a Firebase Console
1. Abrir: https://console.firebase.google.com/project/zync-app-a2712/firestore
2. Crear collection: `predefinedEmojis`

### Paso 2: Copiar/Pegar estos 16 documentos

#### Document ID: `available`
```json
{
  "id": "available",
  "emoji": "🟢",
  "label": "Disponible",
  "shortLabel": "Disponible",
  "category": "availability",
  "order": 0
}
```

#### Document ID: `busy`
```json
{
  "id": "busy",
  "emoji": "🔴",
  "label": "Ocupado",
  "shortLabel": "Ocupado",
  "category": "availability",
  "order": 1
}
```

#### Document ID: `away`
```json
{
  "id": "away",
  "emoji": "🟡",
  "label": "Ausente",
  "shortLabel": "Ausente",
  "category": "availability",
  "order": 2
}
```

#### Document ID: `do_not_disturb`
```json
{
  "id": "do_not_disturb",
  "emoji": "🔕",
  "label": "No molestar",
  "shortLabel": "No molestar",
  "category": "availability",
  "order": 3
}
```

#### Document ID: `home`
```json
{
  "id": "home",
  "emoji": "🏠",
  "label": "En casa",
  "shortLabel": "Casa",
  "category": "location",
  "order": 4
}
```

#### Document ID: `school`
```json
{
  "id": "school",
  "emoji": "🏫",
  "label": "En la escuela",
  "shortLabel": "Escuela",
  "category": "location",
  "order": 5
}
```

#### Document ID: `work`
```json
{
  "id": "work",
  "emoji": "🏢",
  "label": "En el trabajo",
  "shortLabel": "Trabajo",
  "category": "location",
  "order": 6
}
```

#### Document ID: `medical`
```json
{
  "id": "medical",
  "emoji": "🏥",
  "label": "En el médico",
  "shortLabel": "Médico",
  "category": "location",
  "order": 7
}
```

#### Document ID: `meeting`
```json
{
  "id": "meeting",
  "emoji": "👥",
  "label": "En reunión",
  "shortLabel": "Reunión",
  "category": "activity",
  "order": 8
}
```

#### Document ID: `studying`
```json
{
  "id": "studying",
  "emoji": "📚",
  "label": "Estudiando",
  "shortLabel": "Estudiando",
  "category": "activity",
  "order": 9
}
```

#### Document ID: `eating`
```json
{
  "id": "eating",
  "emoji": "🍽️",
  "label": "Comiendo",
  "shortLabel": "Comiendo",
  "category": "activity",
  "order": 10
}
```

#### Document ID: `exercising`
```json
{
  "id": "exercising",
  "emoji": "💪",
  "label": "Haciendo ejercicio",
  "shortLabel": "Ejercicio",
  "category": "activity",
  "order": 11
}
```

#### Document ID: `driving`
```json
{
  "id": "driving",
  "emoji": "🚗",
  "label": "Conduciendo",
  "shortLabel": "Conduciendo",
  "category": "transport",
  "order": 12
}
```

#### Document ID: `walking`
```json
{
  "id": "walking",
  "emoji": "🚶",
  "label": "Caminando",
  "shortLabel": "Caminando",
  "category": "transport",
  "order": 13
}
```

#### Document ID: `public_transport`
```json
{
  "id": "public_transport",
  "emoji": "🚌",
  "label": "En transporte público",
  "shortLabel": "Transporte",
  "category": "transport",
  "order": 14
}
```

#### Document ID: `sos`
```json
{
  "id": "sos",
  "emoji": "🆘",
  "label": "Emergencia",
  "shortLabel": "SOS",
  "category": "transport",
  "order": 15
}
```

## Verificación

Después de agregar los 16 documentos:

1. Verificar que la collection `predefinedEmojis` tenga 16 documentos
2. Cada documento debe tener campos: `id`, `emoji`, `label`, `shortLabel`, `category`, `order`
3. Los `order` deben ir de 0 a 15

## Next Steps (después del seed manual)

1. **Arreglar el SDK de Flutter** (probablemente necesite `flutter upgrade` o reinstalación)
2. **Actualizar archivos dependientes** que usan el enum `StatusType`
3. **Probar el flujo completo** con Firebase

## Estructura de Grid 4x4

```
🟢 Disponible    🔴 Ocupado        🟡 Ausente         🔕 No molestar
🏠 Casa          🏫 Escuela        🏢 Trabajo         🏥 Médico
👥 Reunión       📚 Estudiando     🍽️ Comiendo       💪 Ejercicio
🚗 Conduciendo   🚶 Caminando      🚌 Transporte      🆘 SOS
```

## Troubleshooting SDK Flutter

Si los errores persisten:

```powershell
# Opción 1: Upgrade
flutter upgrade --force

# Opción 2: Channel switch
flutter channel stable
flutter upgrade

# Opción 3: Reinstall (última opción)
# Descargar Flutter desde https://flutter.dev/docs/get-started/install/windows
```

Los errores indican que `dart:ui` no está expuesto correctamente. Esto es un problema serio del SDK.
