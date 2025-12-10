# ZYNC Geofencing Phase 0 (MVP) - Development Backlog

**Fecha:** Diciembre 10, 2025  
**Branch:** `feature/geofencing-phase0-mvp`  
**Objetivo:** Implementar geofencing básico sin romper funcionalidad existente  
**Enfoque:** MVP sin IA - Solo detección de entrada/salida de zonas

---

## 📋 BACKLOG - User Stories

### Epic: Geofencing Base System

---

### **US-GEO-001: Crear y gestionar zonas geográficas**

**Como** usuario de ZYNC  
**Quiero** crear zonas geográficas (Casa, Colegio, Trabajo)  
**Para** recibir notificaciones cuando mis familiares entren/salgan de esas zonas

**Criterios de Aceptación:**
- [ ] Puedo crear una zona con nombre, ubicación (lat/lng) y radio (50-500m)
- [ ] Puedo editar nombre, ubicación y radio de zonas existentes
- [ ] Puedo eliminar zonas (con confirmación)
- [ ] La zona se muestra visualmente en el mapa como círculo
- [ ] El radio es ajustable con slider visual
- [ ] Solo miembros del círculo pueden ver/gestionar zonas del círculo
- [ ] Máximo 10 zonas por círculo (limitación MVP)
- [ ] Persistencia en Firestore bajo `/circles/{circleId}/zones/{zoneId}`

**Prioridad:** P0 (Crítica)  
**Estimación:** 5 puntos  
**Dependencias:** Ninguna

---

### **US-GEO-002: Detección de entrada a zona**

**Como** sistema de ZYNC  
**Quiero** detectar cuando un usuario entra a una zona configurada  
**Para** actualizar su estado y notificar al círculo

**Criterios de Aceptación:**
- [ ] Background service monitorea ubicación GPS cada 5 minutos
- [ ] Al detectar entrada, se registra evento en Firestore: `/circles/{circleId}/zone_events/{eventId}`
- [ ] Evento contiene: `userId`, `zoneId`, `eventType: "enter"`, `timestamp`, `accuracy`
- [ ] Estado del usuario se actualiza automáticamente basado en la zona
- [ ] Solo se dispara si la precisión GPS es <100m
- [ ] No se dispara evento duplicado si ya está dentro de la zona
- [ ] Funciona en background (app minimizada)
- [ ] Funciona en Android e iOS

**Prioridad:** P0 (Crítica)  
**Estimación:** 8 puntos  
**Dependencias:** US-GEO-001

---

### **US-GEO-003: Detección de salida de zona**

**Como** sistema de ZYNC  
**Quiero** detectar cuando un usuario sale de una zona configurada  
**Para** actualizar su estado y notificar al círculo

**Criterios de Aceptación:**
- [ ] Al detectar salida, se registra evento en Firestore: `/circles/{circleId}/zone_events/{eventId}`
- [ ] Evento contiene: `userId`, `zoneId`, `eventType: "exit"`, `timestamp`, `accuracy`, `duration` (tiempo en zona)
- [ ] Estado del usuario se actualiza a "En camino" o similar
- [ ] Solo se dispara si estuvo dentro al menos 2 minutos (evita GPS drift)
- [ ] No se dispara evento duplicado si ya está fuera
- [ ] Funciona en background
- [ ] Funciona en Android e iOS

**Prioridad:** P0 (Crítica)  
**Estimación:** 8 puntos  
**Dependencias:** US-GEO-002

---

### **US-GEO-004: Actualización automática de estado basado en zona**

**Como** usuario  
**Quiero** que mi estado se actualice automáticamente cuando entro/salgo de zonas  
**Para** que mi círculo sepa dónde estoy sin que yo tenga que actualizar manualmente

**Criterios de Aceptación:**
- [ ] Al entrar a zona "Casa" → Estado cambia a "En casa" 🏠
- [ ] Al entrar a zona "Colegio" → Estado cambia a "En el colegio" 🏫
- [ ] Al entrar a zona "Trabajo" → Estado cambia a "En el trabajo" 💼
- [ ] Al salir de cualquier zona → Estado cambia a "En camino" 🚗
- [ ] El cambio de estado se refleja en tiempo real en la app de otros miembros
- [ ] El estado manual del usuario se preserva si no hay detección de zona
- [ ] Registro en Firestore: `/users/{userId}/status` se actualiza automáticamente
- [ ] Timestamp del último cambio se guarda

**Prioridad:** P0 (Crítica)  
**Estimación:** 5 puntos  
**Dependencias:** US-GEO-002, US-GEO-003

---

### **US-GEO-005: Notificaciones de entrada a zona (silenciosas)**

**Como** miembro del círculo  
**Quiero** ver en la app cuando un familiar entra a una zona importante  
**Para** saber que llegó bien sin tener que preguntarle

**Criterios de Aceptación:**
- [ ] Al entrar a zona, se actualiza el estado en la app en tiempo real
- [ ] NO se envía push notification (filosofía ambient awareness)
- [ ] Badge (🔵) aparece en el avatar del usuario indicando cambio reciente
- [ ] El badge desaparece después de 5 minutos
- [ ] En la lista de miembros, se muestra "🏠 En casa - Hace 2 min"
- [ ] Tap en el miembro muestra timeline con evento de entrada
- [ ] Funciona incluso si la app está cerrada (actualización al abrir)

**Prioridad:** P1 (Alta)  
**Estimación:** 5 pontos  
**Dependencias:** US-GEO-004

---

### **US-GEO-006: Notificaciones de salida de zona (silenciosas)**

**Como** miembro del círculo  
**Quiero** ver en la app cuando un familiar sale de una zona importante  
**Para** estar al tanto de su movimiento sin molestarlo

**Criterios de Aceptación:**
- [ ] Al salir de zona, se actualiza el estado en la app en tiempo real
- [ ] NO se envía push notification por default
- [ ] Badge (🔵) aparece indicando cambio reciente
- [ ] Se muestra "🚗 En camino - Hace 3 min"
- [ ] Timeline muestra evento de salida con duración en la zona
- [ ] Usuario puede configurar (opcional) recibir push para salidas específicas

**Prioridad:** P1 (Alta)  
**Estimación:** 3 puntos  
**Dependencias:** US-GEO-004

---

### **US-GEO-007: Visualización de zonas en mapa**

**Como** usuario  
**Quiero** ver las zonas configuradas en el mapa  
**Para** entender visualmente dónde están las áreas importantes

**Criterios de Aceptación:**
- [ ] Cada zona se muestra como círculo semi-transparente en el mapa
- [ ] Color diferente por tipo de zona (Casa=verde, Colegio=azul, Trabajo=naranja)
- [ ] Label con nombre de la zona centrado en el círculo
- [ ] Tap en zona muestra detalles (nombre, radio, creador, fecha creación)
- [ ] Opción para mostrar/ocultar zonas en mapa (toggle)
- [ ] Zonas persisten visibles al navegar por el mapa
- [ ] Performance: No lag con hasta 10 zonas simultáneas

**Prioridad:** P1 (Alta)  
**Estimación:** 5 puntos  
**Dependencias:** US-GEO-001

---

### **US-GEO-008: Historial de eventos de zona (Timeline)**

**Como** usuario  
**Quiero** ver el historial de entradas/salidas de mi círculo  
**Para** entender los patrones de movimiento de mi familia

**Criterios de Aceptación:**
- [ ] Timeline muestra eventos de zona ordenados cronológicamente
- [ ] Cada evento muestra: Usuario, Zona, Tipo (entrada/salida), Timestamp
- [ ] Para salidas, muestra duración en la zona
- [ ] Filtro por usuario (ver solo eventos de Sebastián)
- [ ] Filtro por zona (ver solo eventos de "Casa")
- [ ] Filtro por fecha (hoy, última semana, último mes)
- [ ] Paginación: Carga inicial 20 eventos, "load more" para antiguos
- [ ] Scroll infinito con lazy loading

**Prioridad:** P2 (Media)  
**Estimación:** 5 puntos  
**Dependencias:** US-GEO-002, US-GEO-003

---

### **US-GEO-009: Permisos de ubicación en background**

**Como** sistema  
**Quiero** solicitar permisos de ubicación en background correctamente  
**Para** poder detectar zonas incluso cuando la app está cerrada

**Criterios de Aceptación:**
- [ ] Al activar geofencing, se solicita permiso de ubicación "Always" (Android)
- [ ] En iOS, se solicita "Always Allow" después de "When In Use"
- [ ] Explicación clara al usuario: "Necesario para detectar llegadas automáticamente"
- [ ] Si usuario rechaza, se muestra mensaje explicando limitaciones
- [ ] Opción de reabrir configuración del sistema para cambiar permiso
- [ ] App funciona en modo degradado sin permiso (detección solo con app abierta)
- [ ] Documentación de permisos en configuración

**Prioridad:** P0 (Crítica)  
**Estimación:** 8 puntos (complejo en iOS)  
**Dependencias:** Ninguna

---

### **US-GEO-010: Optimización de batería**

**Como** usuario  
**Quiero** que el geofencing no consuma mucha batería  
**Para** poder usarlo todo el día sin problemas

**Criterios de Aceptación:**
- [ ] Consumo de batería <5% en 24 horas con uso normal
- [ ] GPS se activa solo cada 5 minutos (no continuo)
- [ ] Si usuario está quieto (no se mueve), frecuencia reduce a 10 min
- [ ] Usa geofencing nativo de Android/iOS (más eficiente que polling)
- [ ] Logs de consumo de batería en debug mode
- [ ] Pruebas en dispositivos reales (no solo emulador)
- [ ] Compatible con battery optimization de Android

**Prioridad:** P1 (Alta)  
**Estimación:** 8 puntos  
**Dependencias:** US-GEO-002

---

### **US-GEO-011: Manejo de precisión GPS variable**

**Como** sistema  
**Quiero** manejar correctamente la precisión variable del GPS  
**Para** evitar falsos positivos (GPS drift)

**Criterios de Aceptación:**
- [ ] Solo procesar ubicaciones con precisión <100m
- [ ] Ignorar ubicaciones con precisión >200m
- [ ] Si detecta entrada/salida 3+ veces en 5 minutos → Ignorar (GPS drift)
- [ ] Requiere al menos 2 minutos dentro de zona antes de confirmar entrada
- [ ] Logs de precisión GPS en eventos para debugging
- [ ] Métrica: Tasa de falsos positivos <10%

**Prioridad:** P1 (Alta)  
**Estimación:** 5 puntos  
**Dependencias:** US-GEO-002, US-GEO-003

---

### **US-GEO-012: Configuración de geofencing por usuario**

**Como** usuario  
**Quiero** poder activar/desactivar geofencing para mí  
**Para** tener control sobre mi privacidad

**Criterios de Aceptación:**
- [ ] Toggle en configuración: "Activar detección automática de zonas"
- [ ] Si desactivo, no se detectan entradas/salidas para mí
- [ ] Otros miembros del círculo siguen funcionando normalmente
- [ ] Al desactivar, se muestra advertencia: "Tu círculo no verá tus llegadas automáticamente"
- [ ] Puedo reactivar en cualquier momento
- [ ] Estado persiste en Firestore: `/users/{userId}/settings/geofencingEnabled`

**Prioridad:** P2 (Media)  
**Estimación:** 3 puntos  
**Dependencias:** US-GEO-002

---

### **US-GEO-013: Tests de integración de geofencing**

**Como** desarrollador  
**Quiero** tener tests automatizados de geofencing  
**Para** asegurar que no se rompa con futuros cambios

**Criterios de Aceptación:**
- [ ] Test: Crear zona → Verificar persistencia en Firestore
- [ ] Test: Simular entrada a zona → Verificar evento generado
- [ ] Test: Simular salida de zona → Verificar duración calculada
- [ ] Test: Entrada/salida rápida (<2 min) → Verificar ignorado
- [ ] Test: Múltiples entradas/salidas → Verificar GPS drift detectado
- [ ] Test: Precisión baja → Verificar ubicación ignorada
- [ ] Test: Actualización de estado automático
- [ ] Coverage >80% en lógica de geofencing

**Prioridad:** P1 (Alta)  
**Estimación:** 8 puntos  
**Dependencias:** Todas las US anteriores

---

## 📊 Resumen del Backlog

**Total User Stories:** 13  
**Puntos totales:** 75 puntos  

**Por Prioridad:**
- P0 (Crítica): 5 stories - 39 puntos
- P1 (Alta): 6 stories - 33 puntos  
- P2 (Media): 2 stories - 8 puntos

**Velocidad estimada:** 10-15 puntos/semana  
**Duración estimada:** 5-7 semanas

---

## ⚠️ Principios de No Regresión

**CRÍTICO: La implementación NO debe romper:**

✅ Funcionalidad existente de estados manuales  
✅ Sistema de notificaciones persistentes (Quick Actions)  
✅ Sincronización de emojis  
✅ Silent functionality coordinator  
✅ Session cache  
✅ Auth system  
✅ Circle management  

**Estrategia:**
1. Geofencing es OPCIONAL (se puede desactivar)
2. Estados manuales tienen PRIORIDAD sobre automáticos
3. Tests de regresión antes de cada commit
4. Feature flags para rollback rápido
5. Monitoring de errores en producción

---

**Siguiente paso:** Revisar y aprobar backlog antes de comenzar desarrollo.
