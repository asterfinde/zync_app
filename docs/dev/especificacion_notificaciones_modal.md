# Especificación Técnica: Sistema de Notificaciones y Gestión de Sesión

## 1. Reestructuración del Flujo de Cierre de Sesión

### 1.1. Relocalización de Función de Logout
- **Acción**: Eliminar opción "Cierre de sesión" del menú de 3 puntos (AppBar)
- **Nueva ubicación**: Integrar en pantalla de Configuración como elemento permanente
- **Comportamiento al ejecutar**:
  - Invalidar sesión de autenticación
  - Terminar todas las instancias de notificaciones activas
  - Limpiar tokens de notificación del dispositivo
  - Redirigir a pantalla de login

## 2. Sistema de Gestión de Permisos de Notificaciones Post-Autenticación

### 2.1. Flujo de Verificación de Permisos
- **Trigger**: Inmediatamente después de autenticación exitosa
- **Detección**: Verificar estado de permisos de notificación a nivel SO

### 2.2. Escenarios de Permisos

#### 2.2.1. Flujo Normal - Permisos Concedidos
- **Condición**: Permisos de notificación == concedidos
- **Comportamiento**:
  - Inicializar servicio de notificaciones
  - Mostrar notificaciones de forma permanente
  - Continuar flujo normal de la aplicación

#### 2.2.2. Flujo Excepcional - Permisos Denegados
- **Condición**: Permisos de notificación == denegados/no configurados
- **Acción**: Mostrar modal informativo con:
  - Explicación de consecuencias (modo Silent no funcionará)
  - Instrucciones para desbloquear permisos

### 2.3. Diseño del Modal de Permisos
- **Botón "Cerrar"**: 
  - Cierra el modal
  - No modifica permisos
  - Permite continuar con aplicación limitada

- **Botón "Permitir"**:
  - Redirige a configuración de permisos de notificación del SO
  - Navegación directa a settings del sistema
  - No garantiza concesión de permisos (depende del usuario)

### Tests
- ☐ Test 1: Login con permisos ✅ → NO modal → HomePage + notificación
- ☐ Test 2: Login sin permisos ⚠️ → SÍ modal → Texto correcto
- ☐ Test 3: Botón Cerrar → Modal cierra → HomePage sin notificación
- ☐ Test 4: Botón Permitir → Abre Settings Android → Permisos activables
- ☐ Test 5: Registro con permisos ✅ → NO modal → HomePage + notificación
- ☐ Test 6: Registro sin permisos ⚠️ → SÍ modal → Texto correcto
- ☐ Test 7: Logs correctos → Estados claros en consola
- ☐ Test 8: Modal bloqueado → No cierra tocando fuera
- ☐ Test 9: Point 1 intacto → Logout cancela TODO


## 3. Sistema de Notificaciones Permanentes

### 3.1. Comportamiento Post-Autenticación
- **Estado**: Notificaciones activas de forma continua
- **Persistencia**: Mantenerse activas independientemente del estado de la app:
  - App en primer plano
  - App en segundo plano (minimizada)
  - App cerrada/terminada

### 3.2. Condiciones de Terminación
- **Único caso de parada**: Cierre de sesión explícito desde Configuración
- **Excepción**: No se detienen por acciones del SO (excepto desinstalación)

## 4. Implementación del Modo "Silent"

### 4.1. Comportamiento al Interactuar con Notificación
- **Trigger**: Tap usuario en área/bandeja de notificaciones
- **Acción**: Abrir modal independiente
- **Restricción**: Bajo ninguna circunstancia abrir aplicación principal (Home)

### 4.2. Especificaciones del Modal
- **Requisito visual**: Réplica exacta del modal existente en Home
- **Funcionalidad**: Mismas capacidades de actualización de estados/emojis
- **Independencia**: Operación autónoma sin dependencia de instancia principal

### 4.3. Gestión de Notificaciones Duplicadas
- **Prohibición**: Evitar mostrar dos notificaciones simultáneas
- **Configuración**: 
  - Notificación del sistema → Abre modal específico
  - No generar notificación de aplicación estándar
  - Modal como único punto de entrada desde notificación

### 4.4. Consideraciones Técnicas
- **Manejo de intents/links**: Configurar deep linking específico para modal
- **Estado de aplicación**: Modal debe funcionar independientemente del estado de la app principal
- **Sincronización de datos**: Garantizar coherencia entre modal y aplicación principal
---

# Especificación: Manejo de Deep Linking para Modal

## 4.4.1. Concepto de Deep Linking Específico para Modal

### ¿Qué significa?
Configurar rutas/URLs exclusivas que abran **directamente el modal** sin pasar por la pantalla principal (Home) de la aplicación.

## 4.4.2. Implementación Técnica

### Para Android:
```
<intent-filter>
    <action android:name="android.intent.action.VIEW"/>
    <category android:name="android.intent.category.DEFAULT"/>
    <category android:name="android.intent.category.BROWSABLE"/>
    <data android:scheme="miapp" android:host="modal"/>
</intent-filter>
```

### Para iOS:
```
CFBundleURLTypes: miapp://modal
```

## 4.4.3. Flujo de Ejecución

### Escenario Normal (App Cerrada/Minimizada):
```
Usuario toca notificación → 
Sistema ejecuta: miapp://modal/notification123 → 
App se inicia/integra → 
Navegación DIRECTA al modal → 
Modal se muestra (sin pasar por Home)
```

### Escenario con App en Primer Plano:
```
Notificación recibida → 
Handler detecta intent específico → 
Override navegación normal → 
Mostrar modal sobre aplicación actual
```

## 4.4.4. Beneficios de Esta Configuración

- **Aislamiento**: El modal funciona como "mini-app" independiente
- **Rendimiento**: Evita carga innecesaria de pantallas principales
- **Experiencia Usuario**: Transición directa notificación → acción
- **Cumplimiento Requisito**: Garantiza que "NO se abre la app (Home) por ninguna circunstancia"

## 4.4.5. Diferenciación de Intents

| Tipo Intent | Destino | Comportamiento |
|-------------|---------|----------------|
| `miapp://home` | Pantalla principal | Flujo normal de app |
| `miapp://modal` | **Modal específico** | **Solo abre modal** |
| Intent por defecto | **Modal específico** | Override para notificaciones |

Esta configuración asegura que las notificaciones del sistema siempre disparen el intent específico del modal, nunca el flujo normal de la aplicación.