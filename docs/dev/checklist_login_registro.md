# Checklist de Pruebas de Login/Registro

## 1. Validación de Inputs
- [x] El email debe tener formato válido.
- [x] El nickname debe tener la longitud mínima requerida (mínimo 3 caracteres no vacíos).
- [x] La contraseña debe cumplir requisitos de seguridad (mínimo 6 y máximo 10 caracteres no vacíos).
- [x] Los campos obligatorios no pueden estar vacíos.
- [x] El botón de submit solo se habilita si el formulario es válido.

## 2. Mensajes y Feedback
- [ ] Los errores se muestran en español y son claros para el usuario.
- [ ] Se muestran Snackbars o alertas ante errores de autenticación.
- [ ] Mensajes de éxito tras registro/login correcto.

## 3. Flujo de Login
- [ ] Usuario puede iniciar sesión con credenciales válidas.
- [ ] Usuario recibe mensaje de error si el email o contraseña son incorrectos.
- [ ] Usuario no puede iniciar sesión si no está registrado.

## 4. Flujo de Registro
- [ ] Usuario puede registrarse con datos válidos.
- [ ] Se crea el usuario en Firebase Auth y el documento en Firestore.
- [ ] Se muestra mensaje de éxito tras registro.
- [ ] No se permite registro con email ya existente.

## 5. Recuperación de Contraseña
- [ ] El modal de recuperación se muestra correctamente.
- [ ] Se envía el email de recuperación si el correo es válido.
- [ ] Se muestra mensaje de error si el correo no existe.

## 6. Sincronización de Datos
- [ ] Al registrar, se crea el usuario en Auth y Firestore.
- [ ] Al eliminar, se borra el usuario en Auth y Firestore (si aplica).

## 7. Seguridad
- [ ] No se exponen datos sensibles en mensajes de error.
- [ ] Las reglas de Firestore y Auth están configuradas correctamente para el entorno.

## 8. UI/UX
- [ ] Los colores, estilos y textos cumplen con el diseño solicitado.
- [ ] El botón de submit es reactivo y cambia de estado correctamente.
- [ ] El flujo de navegación es claro y sin bloqueos.

## 9. Pruebas de Casos Límite
- [ ] Intentar registro con email inválido.
- [ ] Intentar login con contraseña incorrecta.
- [ ] Intentar recuperación con email no registrado.
- [ ] Intentar registro con nickname demasiado corto.

## 10. Pruebas de HotRestart
- [ ] La app compila y funciona tras HotRestart.
- [ ] No hay errores de compilación ni warnings críticos.
