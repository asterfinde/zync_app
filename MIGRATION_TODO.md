# Migration TODO: Enum → Firebase StatusType

**Branch:** `feature/emoji-system-refactor`  
**Backup commit:** [último commit en GitHub]  
**Fecha inicio:** 2025-11-29

## 🎯 Objetivo
Migrar de `enum StatusType` hardcoded a `class StatusType` cargada desde Firebase.

## ✅ Completado

### Core Architecture
- [x] `lib/core/models/user_status.dart` - Reescrito como clase
- [x] `lib/core/services/emoji_service.dart` - Creado servicio Firebase
- [x] `lib/core/services/status_service.dart` - Actualizado para usar IDs
- [x] `lib/core/services/quick_actions_preferences_service.dart` - Actualizado para Firebase
- [x] `lib/core/widgets/emoji_modal.dart` - Actualizado para cargar async
- [x] `backups/user_status_enum_backup_20251129.dart` - Backup del enum original
- [x] `backups/quick_actions_preferences_service_backup_20251129.dart` - Backup
- [x] `backups/emoji_modal_backup_20251129.dart` - Backup
- [x] `scripts/seed_predefined_emojis.dart` - Script de seed (no ejecutado)
- [x] `SEED_FIRESTORE_MANUAL.md` - Instrucciones para seed manual

### Migration Phase 1 (6 archivos críticos - 65 errores)
- [x] `lib/main.dart` - 2 errores (Commit 4f3b492)
- [x] `lib/features/circle/presentation/widgets/in_circle_view.dart` - 3 errores (Commit 3a1822f)
- [x] `lib/core/widgets/quick_actions_config_widget.dart` - 3 errores (Commit 0ae0616)
- [x] `lib/core/widgets/status_widget.dart` - 1 error (Commit 6bbb3cd)
- [x] `lib/dev_test/mock_data.dart` - 2 errores (Commit 114b882)
- [x] `lib/notifications/notification_actions.dart` - 54 errores (Commit 1b03d1f)

## ⏳ Pendiente de Migración

### Migration Phase 2 (6 archivos adicionales - ~38 errores nuevos descubiertos)

#### 7. `lib/notifications/notification_service.dart` (1 error)
**Problema:** Usa `.name` getter que no existe
**Acción:** Cambiar a `.id`

#### 8. `lib/quick_actions/quick_actions_handler.dart` (12 errors)
**Problema:** Usa enum getters (StatusType.leave, .busy, .fine, etc.)
**Acción:** Cargar desde Firebase con IDs

#### 9. `lib/widgets/home_screen_widget.dart` (6 errors)
**Problema:** Usa enum getters hardcoded
**Acción:** Cargar desde Firebase

#### 10. `lib/widgets/sos_gps_test_widget.dart` (1 error)
**Problema:** Usa StatusType.sos
**Acción:** Cargar desde Firebase con ID 'sos'

#### 11. `lib/widgets/status_selector_overlay.dart` (12 errors)
**Problema:** Usa múltiples enum getters hardcoded
**Acción:** Cargar desde Firebase

#### 12. `lib/widgets/widget_service.dart` (6 errors)
**Problema:** Usa enum getters
**Acción:** Cargar desde Firebase

## ⏳ Pendiente de Migración (archivos originales - REFERENCIA)

### Archivos con errores de compilación (FASE 1 COMPLETADA)

#### 1. `lib/core/widgets/quick_actions_config_widget.dart` (3 errores)
**Problema:** Usa `getAvailableStatusTypes()` de forma síncrona, ahora es async
```dart
// ANTES (sync)
final available = QuickActionsPreferencesService.getAvailableStatusTypes();

// DESPUÉS (async)
final available = await QuickActionsPreferencesService.getAvailableStatusTypes();
```
**Acción:** Convertir método a async y usar await
**Backup:** ⏳ Pendiente

---

#### 2. `lib/core/widgets/status_widget.dart` (1 error)
**Problema:** Usa `StatusType.fine` (enum antiguo)
```dart
// Línea 68
StatusType.fine  // ❌ No existe

// Cambiar por:
StatusType.fallbackPredefined.firstWhere((s) => s.id == 'available')  // ✅
// O mejor: cargar desde Firebase
```
**Acción:** Cargar StatusType desde Firebase en initState
**Backup:** ⏳ Pendiente

---

#### 3. `lib/dev_test/mock_data.dart` (2 errores)
**Problema:** Usa `StatusType.values` y `StatusType.available`
```dart
// Línea 130
StatusType.values  // ❌ No existe
StatusType.available  // ❌ No existe

// Cambiar por:
StatusType.fallbackPredefined  // ✅ Para testing
```
**Acción:** Usar fallbackPredefined para datos mock
**Backup:** ⏳ Pendiente

---

#### 4. `lib/features/circle/presentation/widgets/in_circle_view.dart` (3 errores)
**Problema:** Usa `StatusType.values` y `StatusType.fine` (múltiples lugares)
```dart
// Líneas 322, 324, 577
StatusType.values
StatusType.fine
```
**Acción:** Cargar desde EmojiService en initState
**Backup:** ⏳ Pendiente

---

#### 5. `lib/main.dart` (2 errores)
**Problema:** Usa `StatusType.values` y `StatusType.available`
```dart
// Líneas 123, 125
StatusType.values
StatusType.available
```
**Acción:** Pre-cargar StatusTypes en app initialization
**Backup:** ⏳ Pendiente

---

#### 6. `lib/notifications/notification_actions.dart` (~54 errores)
**Problema:** Map `const` con valores de enum
```dart
const Map<String, StatusType> statusActions = {  // ❌ Const no puede tener objetos
  'leave': StatusType.leave,
  'busy': StatusType.busy,
  // ...
};

// Cambiar por:
final Map<String, StatusType> statusActions = {};  // ✅ No const
// O cargar en runtime
```
**Acción:** Remover `const`, inicializar en runtime o usar IDs
**Backup:** ⏳ Pendiente

---

## 🔥 Archivos de Alta Prioridad (bloquean funcionalidad)

1. **`main.dart`** - Bloquea inicio de app
2. **`in_circle_view.dart`** - Bloquea vista principal del círculo
3. **`notification_actions.dart`** - Bloquea notificaciones
4. **`quick_actions_config_widget.dart`** - Bloquea configuración de Quick Actions

## 📦 Backups Necesarios (ANTES de modificar)

- [ ] `lib/core/widgets/quick_actions_config_widget.dart`
- [ ] `lib/core/widgets/status_widget.dart`
- [ ] `lib/dev_test/mock_data.dart`
- [ ] `lib/features/circle/presentation/widgets/in_circle_view.dart`
- [ ] `lib/main.dart`
- [ ] `lib/notifications/notification_actions.dart`

## 🚀 Plan de Ejecución

### Fase 1: Backups (5 min)
```powershell
$files = @(
  "lib\core\widgets\quick_actions_config_widget.dart",
  "lib\core\widgets\status_widget.dart",
  "lib\dev_test\mock_data.dart",
  "lib\features\circle\presentation\widgets\in_circle_view.dart",
  "lib\main.dart",
  "lib\notifications\notification_actions.dart"
)

foreach ($file in $files) {
  $basename = Split-Path $file -Leaf
  Copy-Item $file "backups\${basename}_backup_20251129.dart"
}
```

### Fase 2: Firebase Seed (BLOQUEANTE)
**CRÍTICO:** Sin esto, la app NO funciona
- [ ] Opción A: Ejecutar `scripts/seed_predefined_emojis.dart` (si SDK se arregla)
- [ ] Opción B: Seed manual vía Firebase Console (ver `SEED_FIRESTORE_MANUAL.md`)

### Fase 3: Migración por prioridad
1. `main.dart` (app initialization)
2. `in_circle_view.dart` (vista principal)
3. `notification_actions.dart` (notificaciones)
4. `quick_actions_config_widget.dart` (config UI)
5. `status_widget.dart` (widget status)
6. `mock_data.dart` (solo testing)

### Fase 4: Testing
- [ ] `flutter analyze` sin errores
- [ ] App compila y corre
- [ ] Emojis cargan desde Firebase
- [ ] Quick Actions funcionan
- [ ] Notificaciones funcionan

### Fase 5: Commit
```bash
git add .
git commit -m "feat: migrate StatusType from enum to Firebase-loaded class

BREAKING CHANGE: StatusType is now a class loaded from Firebase instead of hardcoded enum.

- Migrated 6 core files to use Firebase StatusType
- Created EmojiService for Firebase integration
- Added fallback hardcoded emojis for offline mode
- Updated 16 predefined emojis (4x4 grid)

Files modified:
- lib/core/models/user_status.dart
- lib/core/services/emoji_service.dart (new)
- lib/core/services/status_service.dart
- lib/core/services/quick_actions_preferences_service.dart
- lib/core/widgets/emoji_modal.dart
- lib/main.dart
- lib/features/circle/presentation/widgets/in_circle_view.dart
- lib/notifications/notification_actions.dart
- lib/core/widgets/quick_actions_config_widget.dart
- lib/core/widgets/status_widget.dart

Firebase structure:
- /predefinedEmojis (16 global emojis)
- /circles/{id}/customEmojis (future: custom per circle)"
```

## ❓ Decisiones Pendientes

1. **¿Ejecutar seed script o manual?** → Depende de si se arregla SDK
2. **¿Mantener fallbackPredefined?** → SÍ, para offline mode
3. **¿Custom emojis en esta fase?** → NO, solo predefinidos por ahora

## 📊 Progreso
- Archivos completados: 5/11 (45%)
- Errores resueltos: 0/65 (0%)
- Firebase poblado: ❌ BLOQUEANTE

## 🐛 Problemas Conocidos
- Flutter SDK tiene errores al ejecutar scripts (solucionado: NO era SDK)
- 65 archivos más necesitan migración
- Firebase NO está poblado aún
