# WORK_PLAN_CIRCLE_RULES.md — Plan de Trabajo: Reglas de Negocio de Círculos

> Documento técnico que describe el trabajo necesario para cerrar las brechas identificadas
> en el análisis de reglas de negocio previo al lanzamiento de ZYNC v1.0.
> Creado: 2026-03-22

---

## Contexto

El análisis de reglas de negocio identificó dos brechas entre lo que el negocio define
y lo que el código actualmente implementa. Este documento describe qué cambiar, en qué
archivos, y en qué orden.

---

## Brecha 1 — Botón "Salir del Círculo" activo en Settings

### Descripción del problema

La regla de negocio dice: una vez que un usuario crea o se une a un círculo, no puede
salir de él. La única salida es eliminar la cuenta.

Sin embargo, `settings_page.dart` tiene un botón activo **"Salir del Círculo"**
(`Key('btn_leave_circle')`, línea 1005) que ejecuta `_leaveCircle()` (línea 347), la cual
desvincula al usuario del círculo sin eliminar su cuenta. Esto viola la regla.

### Trabajo a realizar

**Archivo:** `lib/features/settings/presentation/pages/settings_page.dart`

**Acción:** Eliminar el bloque "Zona de peligro — Salir del círculo" de la UI de Settings.
Eso incluye:
- El `OutlinedButton.icon` con key `btn_leave_circle`
- El método `_showLeaveCircleDialog()`
- El método `_leaveCircle()`
- Los textos explicativos asociados ("Zona de peligro", "Salir del círculo eliminará tu acceso...")

**Lo que NO se toca:**
- El método `leaveCircle()` en `circle_service.dart` — sigue siendo necesario internamente
  para el flujo de `deleteAccount()`.
- El botón de eliminar cuenta, que sí es la vía correcta para desvincularse.

**Resultado esperado:** Settings ya no ofrecerá la opción de salir del círculo.
El usuario que quiera desvincularse deberá eliminar su cuenta.

---

## Brecha 2 — Sin distinción creador/miembro al eliminar cuenta

### Descripción del problema

La decisión técnica del 2026-03-17 establece:
- El **creador** puede eliminar el círculo. Al hacerlo, todos los miembros quedan
  desvinculados y regresan a la pantalla "Aún no estás en un círculo".
- Un **miembro común** solo puede abandonarlo (vía eliminación de cuenta).

El problema actual tiene dos capas:

**Capa de datos:** El modelo `Circle` y el documento de Firestore no tienen campo
`creatorId`. Sin ese campo es imposible identificar quién es el creador.

**Capa de lógica:** El método `deleteAccount()` en `circle_service.dart` llama a
`leaveCircle()` para ambos casos (creador y miembro), sin distinción. Si el creador
elimina su cuenta y quedan otros miembros, el círculo queda activo en Firestore sin
dueño — estado indefinido ("círculo zombie").

### Trabajo a realizar

#### 2.1 — Modelo de datos: agregar `creatorId`

**Archivo:** `lib/services/circle_service.dart`

**Cambio en `createCircle()`:** agregar `'creatorId': user.uid` al mapa `circleData`
que se escribe en Firestore.

**Cambio en la clase `Circle`:** agregar el campo `final String creatorId` y su lectura
en `Circle.fromFirestore()`.

```dart
// Clase Circle — agregar campo:
final String creatorId;

// Constructor — agregar parámetro requerido:
required this.creatorId,

// fromFirestore — agregar lectura:
creatorId: data['creatorId'] ?? '',
```

#### 2.2 — Lógica: diferenciar `deleteAccount()` según rol

**Archivo:** `lib/services/circle_service.dart`

El método `deleteAccount()` debe:

1. Leer el documento del círculo del usuario.
2. Comparar `circle.creatorId == uid`.
3. Si es **creador**:
   - Leer la lista completa de `members` del círculo.
   - Usar un batch de Firestore para:
     - Eliminar el documento del círculo.
     - Actualizar todos los documentos de los miembros: `circleId → FieldValue.delete()`.
4. Si es **miembro común**:
   - Comportamiento actual: solo removerlo de `members` y limpiar su `circleId`.

```
deleteAccount()
  └─ obtener userDoc → circleId
  └─ obtener circleDoc → creatorId, members[]
  └─ if uid == creatorId
       └─ batch:
            delete circles/{circleId}
            for each memberId: update users/{memberId} { circleId: delete }
     else
       └─ leaveCircle() (comportamiento actual)
  └─ delete users/{uid}
  └─ delete Firebase Auth user
```

#### 2.3 — Reglas de Firestore: no son necesarios cambios

Las reglas actuales ya permiten al usuario autenticado leer y escribir en `circles/`
y en `users/`. El batch de borrado funciona dentro de esos permisos.

---

## Versionado — Proceso para v1.0 y adelante

### Estado actual

`pubspec.yaml` tiene `version: 1.0.0+1`. Es correcto para el primer release.

### Formato

```
version: MAJOR.MINOR.PATCH+BUILD_NUMBER
```

| Parte | Qué significa | Cuándo cambia |
|---|---|---|
| `MAJOR` | Versión principal | Cambio de arquitectura o ruptura de compatibilidad |
| `MINOR` | Feature release | Se agregan funcionalidades nuevas |
| `PATCH` | Fix release | Solo correcciones de bugs |
| `BUILD_NUMBER` | Número interno de build | **Siempre incrementa** en cada APK/AAB que se sube a Play Store |

### Regla práctica para ZYNC

Dado que no hay CI/CD, el proceso es manual:

1. **Antes de cada release**, abrir `pubspec.yaml` y actualizar la versión.
2. El `BUILD_NUMBER` (+N) **siempre debe incrementar** respecto al último build publicado.
   Play Store rechaza builds con el mismo número o inferior.
3. Hacer el cambio en un commit separado: `chore: bump version to X.Y.Z+N`.

### Tabla de referencia rápida

| Situación | Acción en pubspec.yaml |
|---|---|
| Primera salida a producción | `1.0.0+1` (ya está) |
| Fix post-lanzamiento | `1.0.1+2` |
| Segunda corrección | `1.0.2+3` |
| Feature menor nuevo (ej: zona geofencing mejorada) | `1.1.0+4` |
| Feature mayor / nueva arquitectura | `2.0.0+N` |

### Regla adicional: versión visible vs. interna

- La versión visible para el usuario en Play Store es `MAJOR.MINOR.PATCH` (ej: `1.0.1`).
- El `BUILD_NUMBER` es invisible para el usuario pero crítico para Google Play.
- Ambos deben mantenerse sincronizados en el mismo commit de `pubspec.yaml`.

---

## Orden de ejecución recomendado

| Paso | Tarea | Archivos |
|---|---|---|
| 1 | Agregar `creatorId` a `createCircle()` y al modelo `Circle` | `circle_service.dart` |
| 2 | Actualizar `deleteAccount()` con lógica creador/miembro | `circle_service.dart` |
| 3 | Eliminar "Zona de peligro — Salir del círculo" de Settings | `settings_page.dart` |
| 4 | Bump de versión a `1.0.0+1` (ya está, confirmar antes del build) | `pubspec.yaml` |

El paso 1 debe ir antes del 2 porque la lógica depende del campo `creatorId`.
Los pasos 3 y 4 son independientes entre sí y del 1-2.

---

## Archivos impactados (resumen)

| Archivo | Tipo de cambio |
|---|---|
| `lib/services/circle_service.dart` | Modelo + lógica de servicio |
| `lib/features/settings/presentation/pages/settings_page.dart` | Eliminación de UI |
| `pubspec.yaml` | Solo confirmar versión antes del release |
