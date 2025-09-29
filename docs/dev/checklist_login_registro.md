# Checklist de Pruebas de Login/Registro

## 1. Validación de Inputs
- [x] El email debe tener formato válido.
- [x] El nickname debe tener la longitud mínima requerida (mínimo 3 caracteres no vacíos).
- [x] La contraseña debe cumplir requisitos de seguridad (mínimo 6 y máximo 10 caracteres no vacíos).
- [x] Los campos obligatorios no pueden estar vacíos.
- [x] El botón de submit solo se habilita si el formulario es válido.

## 2. Mensajes y Feedback
- [x] Los errores se muestran en español y son claros para el usuario.
- [x] Se muestran Snackbars o alertas ante errores de autenticación:
    - Intenta iniciar sesión con email o contraseña incorrectos
    - Intenta registrarte con un email ya existente

## 3. Flujo de Login
- [x] Usuario puede iniciar sesión con credenciales válidas.
- [x] Usuario recibe mensaje de error si el email o contraseña son incorrectos.
- [x] Usuario no puede iniciar sesión si no está registrado.

## 4. Flujo de Registro
- [x] Usuario puede registrarse con datos válidos.
- [x] No se permite registro con email ya existente.

## 5. Recuperación de Contraseña
- [x] El modal de recuperación se muestra correctamente.
- [x] Se envía el email de recuperación si el correo es válido.
- [x] Se muestra mensaje de error si el correo no existe.

## 6. Sincronización de Datos
- [ ] Al registrar, se crea el usuario en Auth y Firestore.
- [ ] Al eliminar, se borra el usuario en Auth y Firestore (si aplica).

## 7. Seguridad
- [x] No se exponen datos sensibles en mensajes de error.
- [ ] Las reglas de Firestore y Auth están configuradas correctamente para el entorno.

## 8. UI/UX
- [x] Los colores, estilos y textos cumplen con el diseño solicitado.
- [x] El botón de submit es reactivo y cambia de estado correctamente.
- [x] El flujo de navegación es claro y sin bloqueos.

## 9. Pruebas de Casos Límite
- [x] Intentar registro con email inválido.
- [x] Intentar login con contraseña incorrecta.
- [x] Intentar recuperación con email no registrado.
- [x] Intentar registro con nickname demasiado corto.

## 10. Pruebas de HotRestart
- [x] La app compila y funciona tras HotRestart.
- [x] No hay errores de compilación ni warnings críticos.
