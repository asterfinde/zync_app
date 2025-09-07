@echo off
REM Script para limpiar las colecciones de Firestore para el proyecto Zync.
REM Asegúrate de haber iniciado sesión en Firebase CLI: firebase login

echo.
echo =======================================================
echo      Limpiando la Base de Datos de Firestore (Zync)
echo =======================================================
echo.

REM Elimina la colección 'circles' y todos sus documentos y sub-colecciones
echo Eliminando colección 'circles'...
firebase firestore:delete circles --recursive --project zync-app-a2712 --force

REM Verificar si el primer comando tuvo éxito
IF %ERRORLEVEL% NEQ 0 (
    echo ERROR: No se pudo eliminar la colección 'circles'
    goto error
)

REM Elimina la colección 'users' y todos sus documentos y sub-colecciones
echo Eliminando colección 'users'...
firebase firestore:delete users --recursive --project zync-app-a2712 --force

REM Verificar si el segundo comando tuvo éxito
IF %ERRORLEVEL% NEQ 0 (
    echo ERROR: No se pudo eliminar la colección 'users'
    goto error
)

echo.
echo =======================================================
echo      Colecciones 'circles' y 'users' eliminadas 
echo =======================================================
echo.
goto end

:error
echo.
echo =======================================================
echo      ERROR: No se pudo eliminar alguna colección.
echo =======================================================
echo.

:end
pause