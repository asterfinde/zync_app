# Product — ZYNC

## Visión
ZYNC es una aplicación móvil de comunicación mínima y significativa
para círculos cercanos de confianza. Permite expresar presencia,
estado y emergencia sin fricción, con un solo gesto.

## Propósito
Resolver la necesidad de mantenerse conectado emocionalmente con
las personas más cercanas (familia, pareja, amigos íntimos) sin
la sobrecarga de los mensajes de texto o las redes sociales.

## Usuarios objetivo
- **Member:** persona que pertenece a un Circle. Envía y recibe Status.
- **Circle Owner:** Member que además administra su Circle (aprueba JoinRequests,
  gestiona CustomEmojis y Zones).
- **SOS Recipient:** cualquier Member que recibe una alerta SOSEvent.

## Propuesta de valor
- Comunicación con un solo tap (enviar un Status)
- Sin texto, sin conversación: solo presencia y estado
- Función crítica de SOS integrada con Location GPS
- Círculo cerrado: solo personas de confianza
- Actualizaciones automáticas de Status por zonas geográficas (geofencing)
- Accesos rápidos nativos (QuickActions) para enviar Status sin abrir la app

## Filosofía de diseño — "Estás o no estás"
La app no ofrece estados intermedios de pertenencia. Un usuario está en un
Circle o no lo está. No existe "salir del Circle" sin eliminar la cuenta.
Esta decisión refleja el propósito: conexión de confianza total o ninguna.

## Etapa actual
MVP — 90% completado. Android first.
Tests automatizados Fases 1–2 completos. Fases 3–5 en validación.

## Plataformas
- Android (activa — min SDK 21, Android 5.0)
- iOS (en roadmap — versión mínima por definir)

## Restricciones de negocio
- Un usuario pertenece a un solo Circle simultáneamente (v1.0)
- Los PredefinedEmojis son administrados centralmente — no por el usuario
- El SOS siempre adjunta Location GPS — no es opcional
- El Circle Owner es el único que puede aprobar JoinRequests
- No existe acción explícita "eliminar Circle": ocurre como efecto
  secundario cuando el Circle Owner elimina su cuenta
- Máximo 10 Zones por Circle

## Roadmap post-MVP
- iOS
- Múltiples Circles por usuario (v2.0)
- SOS con historial de Location en tiempo real
- Notificaciones push de alta prioridad para SOSEvent
- Ingeniería reversa del código MVP para generar specs formales (deuda técnica)

## Métricas de éxito (post-MVP)
- Retención a 30 días de Members activos
- Tasa de uso diario del Status
- Tiempo de respuesta ante un SOSEvent (objetivo: < 30 segundos)
- Tasa de adopción de QuickActions
