# Política de Privacidad — Nunakin

> Última actualización: [fecha de publicación]

## 1. Datos que recopilamos

- Correo electrónico y nickname, al registrarte.
- Ubicación GPS (incluida en segundo plano), para detectar automáticamente tu entrada/salida de zonas de confianza (geofencing) y para la función SOS.
- Estado de presencia que compartes con tu Círculo.

## 2. Para qué los usamos

Exclusivamente para el funcionamiento de tu Círculo cercano: mostrar tu estado a las personas de confianza que elijas, activar geofencing automático y habilitar SOS con tu ubicación en emergencias. Nunca vendemos ni compartimos tus datos con terceros ajenos a tu Círculo.

## 3. Con quién se comparte

Solo con los miembros de tu propio Círculo. Nadie fuera de él puede ver tu ubicación, estado o datos de contacto.

## 4. Retención

- Eventos de zona (`ZoneEvent`) y coordenadas de SOS: se conservan 90 días, luego se eliminan automáticamente.
- Tu último estado conocido: se conserva mientras tu cuenta exista.
- Al eliminar tu cuenta, todos tus datos personales se eliminan de forma permanente (ver sección "Eliminar tu cuenta" en Ajustes).

## 5. Seguridad

Tus datos viajan cifrados (TLS) y se almacenan en Firebase (Google Cloud), con reglas de acceso restringidas a ti y a tu Círculo.

## 6. Tus derechos

Puedes solicitar la eliminación de tu cuenta y datos en cualquier momento desde Ajustes → Cuenta → Eliminar cuenta.

## 7. Contacto

[correo de soporte a definir]

---

## Justificación `ACCESS_BACKGROUND_LOCATION` (Google Play Console)

> Nunakin usa la ubicación en segundo plano para detectar automáticamente, mediante geofencing, cuándo el usuario entra o sale de zonas de confianza previamente configuradas (ej. casa, colegio), actualizando su estado de presencia ante su Círculo cercano sin necesidad de abrir la app manualmente. También habilita la función SOS para compartir ubicación en emergencias.
