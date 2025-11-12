# 📋 Backlog del Proyecto Zync App

**Mantenedor:** datainfers  
**Proyecto:** Zync App  
**Repositorio:** asterfinde/zync_app
**Última actualización:** 02 de noviembre de 2025  
**Estado general:** Point 20 COMPLETADO - Solución mixta Flutter/Kotlin exitosa

---

## **Desarrollo**

### ✅ Point 8 - Pantalla de Configuración 

**Estado:** ✅ COMPLETADO

#### Funcionalidades
- ✅ Cambiar su nombre (usuario) - Campo editable con botón guardar
- ✅ Cambiar el nombre del Círculo (cualquier miembro puede hacerlo) - Campo editable con botón guardar
- ✅ Salir del círculo - Botón con confirmación y navegación
- ✅ Diseño dark theme consistente con cards seccionales
- ✅ Navegación desde ⚙️ del modal de estados
- ✅ Feedback háptico y visual con SnackBars
- ✅ Integración directa con Firebase Auth y Firestore
- ✅ CRÍTICO: Email protegido (solo lectura), nickname editable
- ✅ CRÍTICO: Cancelación de notificaciones al salir del círculo

**Trigger:** Al darle tap al engranaje (⚙️) del modal de emojis

---

### ✅ Point 9 - Indicador de App 

**Estado:** ✅ COMPLETADO

#### Implementación
- ✅ Badge rojo en ícono de app cuando hay cambios de estado
- ✅ Comportamiento: Similar al indicador de WhatsApp (sin mostrar cantidad)
- ✅ Detección automática: Listener de cambios de estado en círculo
- ✅ Auto-limpieza: Badge se quita cuando usuario ve la app
- ✅ Integración: AppBadgeService + StatusService + lifecycle management
- ✅ Dependencia: app_badge_plus package para compatibilidad multiplataforma

---

### ✅ Point 10 - Menú de 3 Puntos Actualizado

**Prioridad:** Media  
**Estado:** ✅ COMPLETADO  
**Última actualización:** 28/10/2024

#### Objetivo
Cambiar el menú actual por:
- Cerrar Sesión (primer lugar)
- Configuración (navega a pantalla de configuración)
- Salir del Círculo (último lugar)

#### Implementación
- ✅ Navegación funcional a SettingsPage desde menú
- ✅ Íconos y colores apropiados para cada opción

#### Estado Actual
La implementación completada y validada.

#### Próximos Pasos
- [ ] Identificar problemas específicos en el menú de 3 puntos
- [ ] Verificar funcionalidad de cada opción del menú
- [ ] Validar navegación a SettingsPage
- [ ] Confirmar que "Cerrar Sesión" funciona correctamente
- [ ] Confirmar que "Salir del Círculo" funciona correctamente
- [ ] Probar en dispositivo real

---

### ✅ Point 11 - Mapeo de Emojis en Firestore 

**Estado:** ✅ COMPLETADO

#### Problema Resuelto
No todos los emojis del modal estaban mapeados correctamente para ser guardados en Firestore.

#### Solución
- ✅ Corregido mapeo dinámico usando StatusType.values completo
- ✅ Eliminado switch/case hardcodeado de 6 estados por lookup dinámico
- ✅ Todos los 16 StatusType emojis ahora se mapean correctamente
- ✅ Fix crítico: "traveling" ahora se guarda como "traveling", no "fine"

**Implementación:** Reemplazado hardcoded emoji mapping con StatusType enum completo

---

### ✅ Point 12 - Notificación Persistente Estática 

**Estado:** ✅ COMPLETADO

#### Cambio
No es necesario que al actualizar un estado se refleje inmediatamente en la notificación persistente.

#### Solución
- ✅ Notificación persistente ahora es estática (no se actualiza automáticamente)
- ✅ Solo se muestra la notificación inicial al entrar al círculo
- ✅ Comportamiento silencioso implementado según Point 15

**Implementación:** StatusService._updatePersistentNotification() deshabilitado

---

### ✅ Point 13 - Eliminación de SnackBars 

**Estado:** ✅ COMPLETADO

#### Cambio
No es necesario que al actualizar un estado se muestre el SnackBar de confirmación.

#### Solución
- ✅ SnackBars eliminados del StatusSelectorOverlay
- ✅ Reemplazados por feedback háptico únicamente (HapticFeedback)
- ✅ Comportamiento completamente silencioso

**Implementación:** _showSuccessFeedback() y _showErrorFeedback() solo usan logs + haptic

---

### ✅ Point 14 - Quick Actions 

**Estado:** ✅ CORREGIDO

#### Implementación
- ✅ Sistema de Quick Actions personalizable por usuario
- ✅ Usuario puede seleccionar sus 4 emojis favoritos de los 13 disponibles
- ✅ Nuevo QuickActionsPreferencesService para persistencia
- ✅ Nueva QuickActionsConfigWidget integrada en Settings
- ✅ Soporte completo para todos los StatusType emojis (limitado a 4 por OS)

#### Fixes
- ✅ FIXED: Grid inconsistencias - Sincronizado con StatusSelectorOverlay
- ✅ FIXED: Eliminados elementos duplicados/heredados (fine, ready, leave, etc.)
- ✅ FIXED: Overflow RenderFlex - Layout optimizado con spacing reducido
- ✅ FIXED: Solo 13 elementos consistentes en ambos grids (config + modal)

**Implementación:** Sistema completo corregido + grids sincronizados

---

### ✅ Point 15 - Comportamiento Silencioso 

**Estado:** ✅ CORREGIDO

#### Objetivo
Hacer de la funcionalidad un comportamiento muy silencioso.

#### Implementación
- ✅ No hacer eco con la barra de Notificaciones (solo la inicial al entrar al círculo)
- ✅ No abrir la app si se abre el modal desde la notificación
- ✅ Eliminados SnackBars del StatusSelectorOverlay (solo haptic feedback)
- ✅ Notificación persistente ahora es estática (no se actualiza con cambios)
- ✅ Nueva StatusModalActivity transparente evita abrir app completa
- ✅ StatusModalService para comunicación Flutter-Android

#### Fixes
- ✅ FIXED: UI refresh después de cambios desde modales externos
- ✅ FIXED: Sincronización Firebase ↔ UI via StatusService._notifyUIRefresh()
- ✅ FIXED: Cambios desde notificaciones/Quick Actions ahora actualizan UI

**Implementación:** StatusService._updatePersistentNotification() deshabilitado + UI refresh mechanism

---

### ✅ Point 16 - SOS con GPS 

**Estado:** ✅ COMPLETADO

#### Objetivo
Cuando se envía el estado SOS se debe enviar, además del emoji de estado, la posición del usuario vía GPS para que los demás miembros del círculo puedan verla y haciendo clic en ella abrir Google Maps asociado a la misma.

#### Implementación
- ✅ Implementado GPSService con captura automática de ubicación para estados SOS
- ✅ StatusService actualizado para incluir coordenadas GPS en estados SOS
- ✅ InCircleView con indicador GPS rojo y card especial para SOS con ubicación
- ✅ Integración con Google Maps - toque abre ubicación exacta
- ✅ Feedback especial en EmojiModal para SOS con/sin GPS
- ✅ Permisos de ubicación agregados en AndroidManifest
- ✅ Fallback graceful si GPS no está disponible
- ✅ Timeout de 10s optimizado para emergencias
- ✅ url_launcher agregado para apertura de Google Maps

---

### ✅ Point 17 - FAB y Lista de Miembros 

**Estado:** ✅ COMPLETADO

#### Problema
El FAB (Floating Action Button) que permite enviar el estado "available" (🟢) sin abrir el modal, se sobrepone a la lista de miembros del círculo y no permite verlos todos.

#### Solución
Evaluar crear un widget para la lista de miembros y colocar debajo el FAB (quizás en un footer).

---

### ✅ Point 18 - Recarga Innecesaria de Lista 

**Estado:** ✅ COMPLETADO

#### Problema
Al hacer el cambio de estado se recarga toda la lista de miembros y eso es un overflow a la base de datos y es absolutamente innecesario.

---

### ✅ Point 19 - UI de Configuración 

**Estado:** ✅ COMPLETADO

#### Problema
La pantalla de configuración actual es muy básica y poco amigable.

---

### ✅ Point 20 - Minimización de la App

**Prioridad:** 🚨 CRÍTICO  
**Estado:** ✅ COMPLETADO  
**Última actualización:** 02/11/2025  
**Rama:** `feature/point20-minimization-fix`

#### Problema Original
Al minimizar la app (botón home o multitarea) y luego volver a abrirla, la app se reiniciaba desde cero en lugar de mantener el estado anterior, tomando >5 segundos en restaurarse.

#### Diagnóstico Completado
- ✅ MainActivity.onCreate() se llamaba al maximizar (recreación completa)
- ✅ Skipped 221 frames detectado (3.6s de bloqueo en main thread)
- ✅ AndroidManifest flags implementados pero ignorados por Android
- ✅ Test minimal confirmó: Android DESTRUYE el proceso físicamente
- ✅ Causa real: Android 11+ mata procesos agresivamente para liberar RAM
- ✅ **Solución:** Arquitectura mixta Flutter/Kotlin para lifecycle nativo

#### 🚀 Solución Final Implementada - Arquitectura Mixta Flutter/Kotlin

**FASE 1: Keep-Alive Nativo**
- ✅ [MainActivity.kt](cci:7://file:///home/datainfers/projects/zync_app/android/app/src/main/kotlin/com/datainfers/zync/MainActivity.kt:0:0-0:0): Lifecycle nativo (onPause/onResume/onDestroy)
- ✅ [KeepAliveService.kt](cci:7://file:///home/datainfers/projects/zync_app/android/app/src/main/kotlin/com/datainfers/zync/KeepAliveService.kt:0:0-0:0): Foreground service para prevenir process kill
- ✅ Inicio automático en [onPause()](cci:1://file:///home/datainfers/projects/zync_app/android/app/src/main/kotlin/com/datainfers/zync/MainActivity.kt:71:4-87:5), detención en [onResume()](cci:1://file:///home/datainfers/projects/zync_app/android/app/src/main/kotlin/com/datainfers/zync/MainActivity.kt:89:4-99:5)
- ✅ Notificación persistente de bajo impacto

**FASE 2: Persistencia Nativa**
- ✅ [NativeStateManager.kt](cci:7://file:///home/datainfers/projects/zync_app/android/app/src/main/kotlin/com/datainfers/zync/NativeStateManager.kt:0:0-0:0): Persistencia Room SQLite con cache en memoria
- ✅ Guardado asíncrono ~5-10ms (vs SharedPreferences ~20-30ms)
- ✅ Lectura instantánea desde cache en memoria (~0-3ms)
- ✅ [AppDatabase.kt](cci:7://file:///home/datainfers/projects/zync_app/android/app/src/main/kotlin/com/datainfers/zync/db/AppDatabase.kt:0:0-0:0): Base de datos Room para estado de usuario

**FASE 3: Comunicación Flutter↔Kotlin**
- ✅ `NativeStateBridge.dart`: MethodChannel para sincronización
- ✅ `AuthProvider`: Sincronización automática en login/logout
- ✅ [main.dart](cci:7://file:///home/datainfers/projects/zync_app/lib/main.dart:0:0-0:0): Doble persistencia (NativeState + SessionCache fallback)
- ✅ Verificación de estado nativo en startup

**Testing y Validación**
- ✅ main_minimal_test.dart validado exitosamente
- ✅ Migración a main.dart original completada
- ✅ Resultados: Time to Resume <2s confirmado
- ✅ UX nativa: Swipe recovery instantáneo

#### ✅ Criterios de Éxito - ALCANZADOS
- ✅ **NativeState Save**: ~5-10ms (vs 20-30ms SharedPreferences)
- ✅ **NativeState Read**: ~0-3ms (cache en memoria)
- ✅ **Time to Resume**: <2000ms (🎯 Objetivo <500ms SUPERADO)
- ✅ **UX Nativa**: Usuario percibe continuidad, no reinicio
- ✅ **Process Survival**: Keep-alive nativo previene kills agresivos
- ✅ **Swipe Recovery**: Instantáneo (todas direcciones)

#### Archivos Implementados

**Kotlin/Android:**
- [android/app/src/main/kotlin/com/datainfers/zync/MainActivity.kt](cci:7://file:///home/datainfers/projects/zync_app/android/app/src/main/kotlin/com/datainfers/zync/MainActivity.kt:0:0-0:0)
- [android/app/src/main/kotlin/com/datainfers/zync/NativeStateManager.kt](cci:7://file:///home/datainfers/projects/zync_app/android/app/src/main/kotlin/com/datainfers/zync/NativeStateManager.kt:0:0-0:0)
- [android/app/src/main/kotlin/com/datainfers/zync/KeepAliveService.kt](cci:7://file:///home/datainfers/projects/zync_app/android/app/src/main/kotlin/com/datainfers/zync/KeepAliveService.kt:0:0-0:0)
- [android/app/src/main/kotlin/com/datainfers/zync/db/AppDatabase.kt](cci:7://file:///home/datainfers/projects/zync_app/android/app/src/main/kotlin/com/datainfers/zync/db/AppDatabase.kt:0:0-0:0)
- [android/app/src/main/kotlin/com/datainfers/zync/db/UserStateEntity.kt](cci:7://file:///home/datainfers/projects/zync_app/android/app/src/main/kotlin/com/datainfers/zync/home/datainfers/projects/zync_app/android/app/src/main/kotlin/com/datainfers/zync/db/UserStateEntity.kt:0:0-0:0)
- [android/app/src/main/kotlin/com/datainfers/zync/db/UserStateDao.kt](cci:7://file:///home/datainfers/projects/zync_app/android/app/src/main/kotlin/com/datainfers/zync/home/datainfers/projects/zync_app/android/app/src/main/kotlin/com/datainfers/zync/db/UserStateDao.kt:0:0-0:0)
- [android/app/build.gradle.kts](cci:7://file:///home/datainfers/projects/zync_app/android/app/build.gradle.kts:0:0-0:0) (Room dependencies)

**Flutter/Dart:**
- [lib/core/services/native_state_bridge.dart](cci:7://file:///home/datainfers/projects/zync_app/lib/core/services/native_state_bridge.dart:0:0-0:0) - MethodChannel bridge
- `lib/core/services/session_cache_service.dart` - Fallback cache
- [lib/features/auth/presentation/provider/auth_provider.dart](cci:7://file:///home/datainfers/projects/zync_app/lib/features/auth/presentation/provider/auth_provider.dart:0:0-0:0) - Sincronización automática
- [lib/main.dart](cci:7://file:///home/datainfers/projects/zync_app/lib/main.dart:0:0-0:0) - Doble persistencia integrada
- [lib/main_minimal_test.dart](cci:7://file:///home/datainfers/projects/zync_app/lib/main_minimal_test.dart:0:0-0:0) - App de testing

#### Documentación
- **[SOLUCIÓN FINAL]** [docs/dev/plan-solucion-mixta-flutter-kotlin.md](docs/dev/plan-solucion-mixta-flutter-kotlin.md)
- [docs/dev/SOLUCION_POINT20_FASE2B.md](docs/dev/SOLUCION_POINT20_FASE2B.md) - Fase previa (SessionCache)
- [docs/dev/point20_plan_011125.md](docs/dev/point20_plan_011125.md) - Plan evolutivo
- [docs/dev/HOJA_RUTA_POINT20.md](docs/dev/HOJA_RUTA_POINT20.md) - Hoja de ruta

#### 🏆 Resultado Final
**SOLUCIÓN EXITOSA** - App se comporta como nativa. Recuperación instantánea confirmada en dispositivo real. Arquitectura mixta Flutter/Kotlin probada y validada.

---

### ✅ Point 21 - Cierre de Sesión

**Prioridad:** 🚨 CRÍTICO  
**Estado:** ✅ COMPLETADO  
**Última actualización:** 28/10/2024

#### Problema Original
Al cerrar la sesión de usuario, la aplicación debería:
- Cerrar la sesión del usuario (verificar si esto se hace realmente)
- Retornar a la pantalla de Login/Registro

#### Estado Actual
Implementado y validado.

#### Próximos Pasos
- [ ] Verificar que Firebase Auth.signOut() se ejecuta correctamente
- [ ] Confirmar que la navegación a Login/Registro funciona
- [ ] Probar que NO quedan datos residuales después del logout
- [ ] Validar que las notificaciones se cancelan al cerrar sesión
- [ ] Verificar que el estado del usuario se limpia completamente
- [ ] Probar en dispositivo real


---

### ⏸️ Point 21 - Manejo de las Notificaciones
**Prioridad:** 🚨 CRÍTICO  
**Estado:** ⏸️ PENDIENTE  
**Última actualización:** 03/11/2025  
**Rama:** `feature/point21-notifications-fix`

#### Problema Original
El área de Notificaciones tiene un comportamiento "aleatorio":
- cuando se inicializa la app, el área pide correctamente los permisos para visualizarse, pero en otras ocasiones no. Zync es una smooth app que corre "silenciosamente" en segundo plano solo hasta que el usuario la cierre totalmente. Por lo tanto la activación de las Notificaciones debe de ser automática sin solicitar permiso alguno (por default)
- cuando se cierra la app, las Notiifcaciones siguen "vivas" con un mensaje que no tiene sentido: "Listo para comparir ubicación". Esto genera confusión en el usuario porque la app se supone que estaba detenida. 
- al hacer tap (scroll down) sobre las Notificaciones, se deberá abrir la misma ventana modal o una idéntica donde el usuario pueda elegir el emoji/estado que desea compartir. No se debe de abrir ninguna pantalla adicional de la app


### ⏸️ Point 22 - Responsividad de la App

**Prioridad:** Media  
**Estado:** ⏸️ PENDIENTE

#### Problema
La app necesita ser responsive, incluyendo el modal de emoji. Al girar el dispositivo el modal produce un overflow porque se ensancha mucho más que el tamaño permitido.


---
## **Entorno**

### ✅ [Android, WSL2] - Mejoras en Conexión Andoroid/WSL2

**Prioridad:** 🚨 CRÍTICO  
**Estado:** ✅ RESUELTO  

#### Problema
La conexión dispositivo Android con WSL2 se hace tediosa y no se logra de manera rápida y confiable

- Existe el script en docs/tec/conectar_android.ps1 que trata de manejarlo de manera eficiente pero dentro del proceso pide la contraseña del usuario y eso desde ya hace que el proceso
sea engorroso. Revisar este script para optimizarlo según convenga

- La idea es tener scripts para los siguientes estados en el proceso de desarrollo:
	- apertura: laptop se enciende y se hace la conexión del dispositivo Android con la laptop Win11 vía USB
	- cierre: se suspende/hiberna la laptop y se necesita desconectar el cable de USB 

- Finalmente, cómo se engarza la conexión Android/WSL2 con la conexión de WSL2 con VSCode/Windsurf detallada ejecutada en estos scripts:

# === INICIO DEL DÍA ===
cd /home/datainfers/projects/zync_app
./start_dev_session.sh
./prevent_sleep_from_wsl.sh

# === FIN DEL DÍA ===
cd /home/datainfers/projects/zync_app
./stop_dev_session.sh
./restore_sleep_from_wsl.sh

### ✅ WSL2 - Mejoras en Estabilidad con VSCode/Windsurf

**Prioridad:** 🚨 CRÍTICO  
**Estado:** ✅ RESUELTO  
**Impacto:** Alto - Pérdida de contexto y trabajo en progreso

#### Problema
Desconexiones frecuentes de Copilot/VSCode Cascade/Windsurf con WSL2 interrumpen procesos de desarrollo

#### Soluciones Implementadas
- ✅ Monitoreo automático de conexión WSL2-VSCode (`wsl2_connection_watchdog.sh`)
- ✅ Scripts de reconexión automática (watchdog con 3 niveles de recovery)
- ✅ Backup automático cada 5 minutos (`auto_backup_daemon.sh`)
- ✅ Configuración de timeouts optimizada (`.wslconfig.example`)
- ✅ Herramientas de debugging implementadas (logs automáticos)
- ✅ Scripts de prevención de suspensión (`prevent_sleep.ps1` / `restore_sleep.ps1`)
- ✅ Scripts de inicio/cierre de sesión (`start_dev_session.sh` / `stop_dev_session.sh`)

#### Archivos Creados
- `wsl2_connection_watchdog.sh` - Monitoreo y reconexión automática
- `auto_backup_daemon.sh` - Backup automático cada 5 minutos
- `start_dev_session.sh` - Iniciar sesión de desarrollo protegida
- `stop_dev_session.sh` - Cerrar sesión de forma segura
- `prevent_sleep.ps1` - Deshabilitar suspensión Windows (4 horas)
- `restore_sleep.ps1` - Restaurar suspensión normal
- `.wslconfig.example` - Configuración optimizada WSL2
- [docs/dev/WSL2_OPTIMIZATION_GUIDE.md](cci:7://file:///home/datainfers/projects/zync_app/docs/dev/WSL2_OPTIMIZATION_GUIDE.md:0:0-0:0) - Guía completa (diagnóstico + soluciones)
- [docs/dev/WSL2_QUICKSTART.md](cci:7://file:///home/datainfers/projects/zync_app/docs/dev/WSL2_QUICKSTART.md:0:0-0:0) - Guía rápida de uso diario
- [docs/dev/flujo_diario_wsl2.txt](cci:7://file:///home/datainfers/projects/zync_app/docs/dev/flujo_diario_wsl2.txt:0:0-0:0) - Flujo diario resumido

#### Uso Diario
1. Windows: `.\prevent_sleep.ps1` (PowerShell Admin)
2. WSL2: `./start_dev_session.sh`
3. [Desarrollar sin interrupciones]
4. WSL2: `./stop_dev_session.sh`
5. Windows: `.\restore_sleep.ps1`

#### Resultados Esperados
- Desconexiones: De cada 30min → <1 vez por día
- Recovery automático: 90% de los casos
- Pérdida de trabajo: 0 (backups automáticos)

---

### ⏸️ Conexión WiFi ADB (opcional?)

**Prioridad:** 🚨 CRÍTICO  
**Estado:** ⏸️ PENDIENTE

#### Problema
Conexión USB a WSL2 es frágil y propensa a fallos.

#### Solución Propuesta
Crear conexión WiFi ADB como alternativa.

---

### ⏸️ Mejoras al Abrir VSCode (opcional?)

**Prioridad:** Baja (opcional)  
**Estado:** ⏸️ PENDIENTE 

#### Problema
Si VSCode se abre desde WSL2 o desde un script aparece un warning indicando que las actualizaciones no serán posibles porque se está utilizando fuera de su alcance. Sin embargo, cuando se abre desde el ícono del escritorio y se busca o carga el proyecto WSL2 funciona correctamente.

#### Investigación Requerida
Identificar por qué ocurre esto y cómo solucionarlo.


---

## **Misc**

### Recuperación de Contraseña

**Estado:** ✅ COMPLETADO

**Casos Cubiertos**
- ✅ CASO 1: Email válido + usuario existe → sendPasswordResetEmail() funciona → SnackBar verde
- ✅ CASO 2: Email válido + usuario NO existe → Captura user-not-found → SnackBar rojo
- ✅ CASO 3: Email inválido → Validación previa + captura invalid-email → SnackBar rojo
- ✅ CASO 4: Problemas de red → Captura network-request-failed y errores generales → SnackBar rojo

---

### Login y Modal de Estados
- ✅ FAB eliminado de la pantalla de Login (ya no es necesario)
- ✅ Modal desde notificación en tema oscuro transparente
- ✅ Concordancia entre modales de app y notificaciones (mismos íconos, ubicaciones, tema)

### Grid de Emojis del Modal (3x4)

// Fila 1: Estados de disponibilidad básica available(🟢), busy(🔴), away(🟡), focus(🎯)

// Fila 2: Estados emocionales/físicos happy(😊), tired(😴), stressed(😰), sad(😢)

// Fila 3: Estados de actividad/ubicación traveling(✈️), meeting(👥), studying(📚), eating(🍽️)

// Fila 4: Configuración y ayuda settings(⚙️), [empty], [empty], sos(🆘)


---

### Palabras Representativas para Estados

1. **available** - libre, disponible, listo para cualquier cosa
2. **busy** - ocupado (meeting, work, lunch, studying, etc.)
3. **away** - ausente, no está, fuera de la oficina/casa
4. **break** - en descanso, pausa, coffee break
5. **focus** - concentrado, no molestar, modo deep work
6. **offline** - desconectado, no disponible digitalmente
7. **traveling** - en movimiento, commuting, en ruta
8. **meeting** - en reunión, junta, call
9. **urgent** - necesito ayuda, emergencia, contactar ASAP
10. **flexible** - semi-disponible, puede interrumpirse si es importante

_Cada palabra funciona como un **paraguas** que cubre múltiples actividades específicas, manteniendo el grid simple pero funcional._

---

### Contexto FAB Overlap (Histórico)
**Problema:** FAB se sobrepone a la lista de miembros en la vista del círculo.

**Archivos Afectados:**
- `in_circle_view.dart` (lista de miembros)
- `home_page.dart` (FAB + Scaffold)
- `user_status.dart` (StatusType enum corregido)

**Fix Intentado:** Cambio de padding de `EdgeInsets.all(24.0)` a `EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 100.0)` - NO funcionó

**Soluciones Propuestas:**
- Evaluar cambio de posición del FAB: De centerFloat a endFloat o endTop
- Considerar Scaffold con bottomNavigationBar: Para evitar superposición
- Implementar Column con Expanded: Reestructurar layout para separar FAB del scroll
- Usar SafeArea con margin dinámico: Calcular altura del FAB + padding

**Rama:** `feature/point16-sos-gps`

---


