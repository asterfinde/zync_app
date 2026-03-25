# IMPACT_CIRCLE_RULES_ON_TESTS.md — Impacto en el Plan de Pruebas

> Análisis del efecto que los cambios de `WORK_PLAN_CIRCLE_RULES.md` tienen sobre
> los tests existentes en `TEST_PLAN.md`.
> Creado: 2026-03-22

---

## Resumen ejecutivo

Los cambios de las brechas 1 y 2 impactan directamente **4 tests existentes** y
requieren **3 tests nuevos**. Los detalles se documentan abajo y los cambios
correspondientes se agregaron al `TEST_PLAN.md`.

---

## Tests existentes afectados

### T1.10 — Eliminación de cuenta con círculo (miembro o creador)

**Estado actual en TEST_PLAN:** Sin ejecutar. Descripción genérica ("miembro o creador").

**Impacto:** El trabajo de Brecha 2 diferencia el comportamiento según el rol:
- Creador → el círculo entero se borra; todos los miembros quedan desvinculados.
- Miembro → solo ese usuario se remueve; el círculo y los demás quedan intactos.

**Acción en TEST_PLAN.md:** El caso T1.10 se divide en dos casos separados (T1.10 y T1.12)
para que puedan probarse y registrarse de forma independiente.

---

### T2.2 — Eliminación de un círculo (solo el creador puede hacerlo)

**Estado actual en TEST_PLAN:** ✅ — Test automatizado pasando 2026-03-20.

**Impacto:** El test pasa porque el mismo usuario que crea el círculo en el test
también intenta eliminarlo. Sin embargo, la validación real de que *solo el creador puede*
no está en el código — el campo `creatorId` no existe todavía en Firestore.

Tras implementar el campo `creatorId` (Brecha 2, paso 1), el test podría fallar si
el `Circle.fromFirestore()` no encuentra el campo y lanza una excepción. El test
necesita re-ejecutarse después del cambio.

**Acción en TEST_PLAN.md:** Cambiar estado de ✅ a sin estado (pendiente de re-verificar)
con observación explicando el motivo. Re-ejecutar tras implementar Brecha 2.

---

### T2.3 — Intento de crear más de un círculo

**Estado actual en TEST_PLAN:** Sin ejecutar. Nota: "Funcionalidad no implementada en MVP".

**Impacto:** Los cambios de las brechas 1 y 2 no implementan esta regla directamente,
pero el trabajo de refactorizar `circle_service.dart` es el momento natural para agregar
esta validación en `createCircle()`: verificar si el usuario ya tiene un `circleId`
antes de permitir crear uno nuevo.

**Acción en TEST_PLAN.md:** Agregar nota explícita de que esta validación debe incluirse
en el mismo sprint de trabajo de Brecha 2 (es un cambio de 2-3 líneas en `createCircle()`).

---

### T1.9 — Eliminación de cuenta — usuario sin círculo

**Estado actual en TEST_PLAN:** ✅ — Probado manualmente 2026-03-18.

**Impacto:** Indirecto. Tras los cambios en `deleteAccount()`, este flujo (sin círculo)
no debería cambiar, pero conviene re-verificar que no se rompa.

**Acción en TEST_PLAN.md:** Agregar nota de re-verificación recomendada post-implementación.

---

## Tests nuevos requeridos

### T2.7 — La UI no ofrece la opción de "Salir del Círculo"

**Tipo:** 👁 Manual

**Qué verifica:** Tras eliminar el botón de Settings (Brecha 1), confirmar que el
usuario dentro de un círculo no tiene ningún punto de acceso para salir sin eliminar
su cuenta.

**Dónde buscar:** Settings → tab "Cuenta" (o sección equivalente).

**Resultado esperado:** No existe botón, menú ni opción visible de "Salir del Círculo".

---

### T2.8 — Eliminar cuenta siendo creador del círculo

**Tipo:** 👁 Manual

**Qué verifica:** El comportamiento correcto cuando el creador elimina su cuenta y
quedan otros miembros activos.

**Pasos:**
1. Usuario A crea un círculo.
2. Usuario B se une con el código de invitación.
3. Usuario A elimina su cuenta.
4. Verificar en Firestore: el documento del círculo fue eliminado.
5. Verificar en Firestore: `circleId` del Usuario B fue eliminado.
6. Verificar en la app con la sesión del Usuario B: aparece "Aún no estás en un círculo".

**Resultado esperado:** Círculo eliminado. Todos los ex-miembros regresan a `NoCircleView`.

---

### T2.9 — Eliminar cuenta siendo miembro común del círculo

**Tipo:** 👁 Manual

**Qué verifica:** Que un miembro que elimina su cuenta no afecta al círculo ni
a los demás miembros.

**Pasos:**
1. Usuario A crea un círculo.
2. Usuario B se une con el código de invitación.
3. Usuario B elimina su cuenta.
4. Verificar en Firestore: el documento del círculo sigue existiendo.
5. Verificar en Firestore: la lista `members` del círculo ya no contiene el UID del Usuario B.
6. Verificar en la app con la sesión del Usuario A: el círculo sigue activo con sus propios datos.

**Resultado esperado:** Solo el Usuario B queda desvinculado. El círculo y el Usuario A
no se ven afectados.

---

## Tabla resumen de impacto

| Test | Tipo | Acción requerida |
|---|---|---|
| T1.9 | 👁 Manual ✅ | Re-verificar post-implementación (bajo riesgo) |
| T1.10 | 👁 Manual sin ejecutar | Dividir en T1.10 (miembro) y T1.12 (creador) |
| T2.2 | 🔗 Automático ✅ | Re-ejecutar tras agregar campo `creatorId` — podría fallar |
| T2.3 | 👁 Manual sin ejecutar | Agregar validación en `createCircle()` antes de probar |
| T2.7 (nuevo) | 👁 Manual | Verificar ausencia del botón "Salir del Círculo" en UI |
| T2.8 (nuevo) | 👁 Manual | Eliminar cuenta siendo creador → círculo y miembros desvinculados |
| T2.9 (nuevo) | 👁 Manual | Eliminar cuenta siendo miembro → solo ese usuario removido |
