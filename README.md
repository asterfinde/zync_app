# NunaKin — Internal Notes

App ID: `com.datainfers.zync` | Firebase project: `zync-app-a2712`

---

## GCP API Keys

> Regla: **nunca eliminar** las keys marcadas como NUNCA. Son gestionadas por Firebase SDK.
> Para Maps u otros servicios, crear keys separadas con nombre descriptivo.

| Nombre en GCP | Propósito | Tocar? |
|---------------|-----------|--------|
| `iOS key (auto created by Firebase)` | Firebase iOS SDK | **NUNCA** |
| `Browser key (auto created by Firebase)` | Firebase Web SDK | **NUNCA** |
| `Android - Zync Maps` | Google Maps Android | Solo config Maps |
| `Android Firebase Key` *(creada 2026-06-01)* | Firebase Android SDK — reemplaza la key eliminada accidentalmente | **NUNCA** |

**Incidente 2026-06-01:** La key Android auto-creada por Firebase (`AIzaSyB_SgnC...`) fue eliminada
de GCP Credentials, causando `securetoken.googleapis.com: GrantToken are blocked` en toda la app.
Fix: nueva key creada y `android/app/google-services.json` actualizado con `AIzaSyAeS...`.

**Para evitar recurrencia:** GCP → IAM & Admin → Audit Logs → activar `DATA_WRITE` para
`Cloud API Keys API`.

---

## Scripts de desarrollo

| Script | Uso |
|--------|-----|
| `.\clean_and_run.ps1` | Limpia Firebase (Auth + Firestore), reinstala app, lanza con logcat |
| `node C:\Users\dante\dev-scripts\zync\delete_firebase_users.js serviceAccount.json` | Elimina todos los usuarios de Firebase Auth |
