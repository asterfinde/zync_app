# Deuda Técnica — Nunakin

> La IA puede detectar y proponer ítems, pero solo se agregan con aprobación del desarrollador.
> La IA no corrige deuda técnica por iniciativa propia.
> Referenciado desde CLAUDE.md §13.

---

| Problema | Prioridad | Notas |
|----------|-----------|-------|
| Archivos legacy de auth sin uso: `sign_in_page.dart`, `auth_form.dart`, `auth_provider.dart`, `auth_service.dart` | Media | Flujo activo usa `auth_final_page.dart`. Evaluar eliminación post-MVP. |
| Scripts `.ps1` en raíz: `launch_emulator.ps1`, `run_devices.ps1`, `clean_and_run.ps1` | Media | No son parte del código fuente. Mover fuera del repo una vez validados. |
| Archivos de desarrollo dentro de `lib/`: `main_test.dart`, `main_minimal_test.dart`, `dev_auth_simple/`, `dev_auth_test/`, `dev_test/`, `dev_utils/` | **Alta** | `dev_utils/` contiene `clean_auth.dart` y `clean_firestore.dart` — riesgo de ejecución accidental en producción. Eliminar antes del build de release. Cubierto en plan de refactor Sem 10. |
| API Key de Anthropic — ubicación desconocida | **Alta** | No encontrada en ningún archivo Dart. Antes del lanzamiento: confirmar ubicación. Si está en el cliente (hardcodeada o en assets), mover a Cloud Function. Ver CLAUDE.md §15. Cubierto en plan de refactor Sem 9. |
| Edición de emojis personalizados — no existe `updateCustomEmoji()` | Baja | Workaround: borrar + crear. ~50 líneas en 3 archivos. Post-MVP. |
| Validación de correos al registro | Media | Sin definir aún. |
| State Management — solución no documentada en CLAUDE.md §5 | Media | Completar antes de agregar nueva lógica de estado. |
| Feature: ejercicio de respiración guiada (v2.0) | Baja | Esfera animada sobre camino trapezoidal (inspirar/aguantar/exhalar). Encuadrar como acceso desde estado de pánico/SOS, no como sección autónoma. Implementación: `CustomPainter` + `AnimatedBuilder` + `Path`. Sin dependencias nuevas. |
| Cierre remoto de sesión — equipo perdido o robado | **Alta** | Hoy no existe mecanismo para cerrar sesión desde otro dispositivo. Modelo de amenaza idéntico a WhatsApp: quien tenga el equipo desbloqueado con sesión activa tiene acceso completo al Círculo. **Caso crítico: si el que pierde el equipo es el Creador del Círculo**, ningún miembro puede eliminarlo ni disolver el Círculo — el padre/tutor quedaría sin control. Opciones a evaluar: (1) transferencia de rol de Creador desde otro dispositivo; (2) token de sesión con TTL corto + re-auth periódica; (3) logout remoto via Cloud Function (invalida el token Firebase). Pendiente definir cuál se implementa antes del lanzamiento. |
| **[POST-SEM3]** Limpiar §12 y §13 de CLAUDE.md | Media | Al cerrar Sem 3 (flip de `USE_LEGACY_BRIDGE=false` + todos los handlers migrados): archivar decisiones técnicas obsoletas de §12 y resolver/eliminar ítems de deuda resueltos. También eliminar la regla de feature flag de CLAUDE.md §2 si ya no aplica. |
