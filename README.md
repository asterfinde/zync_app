# NunaKin — Internal Notes

App ID: `com.datainfers.zync` | Firebase project: `zync-app-a2712`

---

## GCP API Keys

> Regla: **nunca eliminar** las keys marcadas como NUNCA. Son gestionadas por Firebase SDK.
> Para Maps u otros servicios, crear keys separadas con nombre descriptivo.

| Nombre en GCP | Propósito | APIs que DEBE permitir | Tocar? |
|---------------|-----------|------------------------|--------|
| `iOS key (auto created by Firebase)` | Firebase iOS SDK | — | **NUNCA** |
| `Browser key (auto created by Firebase)` | Firebase Web SDK | — | **NUNCA** |
| `Android - Zync Maps` | Maps **+ Firebase Auth en runtime** (ver nota) | **Identity Toolkit API + Token Service API** + Cloud Firestore + Firebase Installations + Geocoding + Geolocation + Maps SDK | Solo agregar APIs, nunca quitar |
| `Android Firebase Key` *(AIzaSyAeS..., creada 2026-06-01)* | Key en `google-services.json` | — | **NUNCA** |

### ⚠️ Comportamiento clave: GMS elige la key por package + SHA-1

Google Play Services **NO usa la key del `google-services.json`** para Firebase Auth.
Cuando existe una key con restricción **"Apps para Android"** cuyo paquete (`com.datainfers.zync`)
y SHA-1 coinciden, GMS **prefiere esa key** para las llamadas de auth (`signInWithPassword`,
`GrantToken`). En este proyecto esa key es **`Android - Zync Maps`**.

→ Por eso `Android - Zync Maps` **debe incluir Identity Toolkit API y Token Service API**,
aunque "sea de Maps". Si le faltan, el refresh de token (`GrantToken`) devuelve **403** y la
app pierde sesión tras 1h (rompe Modo Silencio en background).

**Incidentes resueltos (2026-06-01/02):**
1. La key Firebase Android original (`AIzaSyB_SgnC...`) fue eliminada de GCP → reemplazada por
   `AIzaSyAeS...` en `android/app/google-services.json`.
2. **Causa raíz crónica (semanas):** `Android - Zync Maps` no tenía **Token Service API** en su
   allowlist → `GrantToken` 403 → token no refrescaba tras 1h → Modo Silencio fallaba en background.
   Fix: se agregó Token Service API a esa key. Verificado con write tras gap de 64 min ✅.

**Para evitar recurrencia:** GCP → IAM & Admin → Audit Logs → activar `DATA_WRITE` para
`Cloud API Keys API`. Diagnóstico futuro: GCP → Token Service API → Metrics → "Errores por credencial".

---

## Scripts de desarrollo

| Script | Uso |
|--------|-----|
| `.\clean_and_run.ps1` | Limpia Firebase (Auth + Firestore), reinstala app, lanza con logcat |
| `node C:\Users\dante\dev-scripts\zync\delete_firebase_users.js serviceAccount.json` | Elimina todos los usuarios de Firebase Auth |
