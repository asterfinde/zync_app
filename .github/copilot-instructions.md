# Zync App - AI Agent Instructions

## Project Overview
Zync is a Flutter location-sharing app that allows users to create/join circles and share status updates with emojis and geolocation. The project is currently in the `feature/silent-functionality` branch, implementing home screen widgets and quick actions.

## Architecture Philosophy
**CRITICAL: This project has learned from over-engineering and now favors simplicity over abstractions.**

### Current Architecture (Simplified)
```
lib/
├── core/
│   ├── services/           # Direct Firebase services (StatusService)
│   └── widgets/           # Reusable components
├── features/
│   ├── auth/              # Clean Architecture (stable, don't touch)
│   └── circle/            # MIXED: Simple services + legacy layers
└── widgets/               # New silent functionality widgets
```

### Architecture Migration Status
- **Auth feature**: Uses full Clean Architecture (Repository → UseCase → Provider)
- **Circle feature**: Currently migrating from Clean Architecture to simple Firebase services
- **New features**: Use simple service-based architecture

## Key Development Patterns

### 1. StatusType Enum Location
```dart
// IMPORTANT: StatusType is in the old domain layer
import '../features/circle/domain_old/entities/user_status.dart';

enum StatusType {
  fine, sos, meeting, ready, leave, happy, sad, busy, sleepy, excited, thinking, worried
}
```

### 2. Firebase Direct Access Pattern
```dart
// PREFERRED: Direct Firebase service calls
class StatusService {
  static Future<StatusUpdateResult> updateUserStatus(StatusType newStatus) async {
    // Direct Firestore calls, no repository layers
  }
}
```

### 3. State Management with Riverpod
- Use `flutter_riverpod: ^2.5.1`
- ConsumerStatefulWidget for complex state
- Simple providers for data streaming

### 4. Firebase Setup Pattern
```dart
// Critical: Check for existing Firebase apps to avoid duplicate initialization
if (Firebase.apps.isEmpty) {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}
```

## Current Development Focus
**Silent Functionality Implementation** (Phase 1 of 3):
1. ✅ Service extraction completed (`StatusService`)
2. 🔄 Home screen widgets (Android/iOS)
3. ⏳ Quick Actions (3D Touch/Long press)
4. ⏳ Silent notifications

## File Structure Conventions

### DO Use These Patterns:
- `lib/features/{feature}/services/` - Direct Firebase services
- `lib/core/services/` - Shared services across features
- `lib/widgets/` - New feature widgets (home screen, etc.)
- Suffix backup files with timestamps: `_backup_20251001.dart`

### DON'T Touch These (Legacy/Stable):
- `lib/features/auth/` - Stable Clean Architecture, leave as-is
- `lib/features/circle/domain_old/` and `data_old/` - Legacy backups
- `lib/core/di/injection_container.dart` - Many commented sections for migration

## Testing Strategy
- Integration tests with `patrol: ^3.4.6` framework
- Test files in `integration_test/`
- Database seeding via `scripts/seed.dart`
- Firebase project: `zync-app-a2712`

## Dependencies
Key packages for silent functionality:
- `home_widget: ^0.6.0` - Android/iOS home screen widgets
- `quick_actions: ^1.0.0` - App shortcuts (3D Touch)
- `flutter_local_notifications: ^17.2.2` - Silent notifications

## Development Workflow
```bash
# Run app
flutter run

# Integration tests
flutter test integration_test/

# Database seeding
flutter test scripts/seed.dart

# Clean Firestore (when needed)
./clean_firestore.bat  # Windows
```

## Critical Implementation Notes
1. **StatusService** is the centralized status update service - use it for all status changes
2. **Firebase apps check** - Always check `Firebase.apps.isEmpty` before initialization
3. **Architecture migration** - Don't add new Clean Architecture layers, use simple services
4. **StatusType imports** - Import from `domain_old/entities/user_status.dart` until migration completes
5. **Riverpod patterns** - Use ConsumerStatefulWidget for widgets needing provider access

## AI Coding Guidelines
- Favor simple, direct Firebase calls over repository abstractions
- Check existing service patterns in `lib/core/services/status_service.dart`
- Follow the simplified architecture for new features
- Don't refactor stable auth system
- Reference `docs/dev/silent-functionality-plan.md` for current implementation roadmap