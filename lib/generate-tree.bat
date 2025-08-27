@echo off
setlocal EnableDelayedExpansion

:: Obtener la fecha actual en formato YYYY-MM-DD
for /f "tokens=2 delims==" %%a in ('wmic OS Get localdatetime /value') do set "dt=%%a"
set "YYYY=%dt:~0,4%"
set "MM=%dt:~4,2%"
set "DD=%dt:~6,2%"
set "fecha=%YYYY%-%MM%-%DD%"

:: Nombre del archivo de salida
set "output_file=tree-%fecha%.txt"

:: Mostrar información inicial
echo ================================================
echo  GENERADOR DE ESTRUCTURA DE DIRECTORIOS
echo ================================================
echo.
echo Ubicacion actual: %CD%
echo Archivo de salida: %output_file%
echo.
echo Generando estructura de archivos y carpetas...
echo.

:: Generar el árbol de directorios y archivos
echo ESTRUCTURA DE DIRECTORIOS Y ARCHIVOS > "%output_file%"
echo ========================================== >> "%output_file%"
echo. >> "%output_file%"
echo Ubicacion: %CD% >> "%output_file%"
echo Fecha de generacion: %fecha% >> "%output_file%"
echo Hora de generacion: %TIME% >> "%output_file%"
echo. >> "%output_file%"
echo ========================================== >> "%output_file%"
echo. >> "%output_file%"

:: Ejecutar tree con archivos incluidos
tree /F /A >> "%output_file%"

:: Agregar información adicional al final
echo. >> "%output_file%"
echo ========================================== >> "%output_file%"
echo Generado por: generate-tree.bat >> "%output_file%"
echo Sistema: %COMPUTERNAME% >> "%output_file%"
echo Usuario: %USERNAME% >> "%output_file%"
echo ========================================== >> "%output_file%"

:: Mostrar resultado
echo ================================================
echo  GENERACION COMPLETADA
echo ================================================
echo.
echo El archivo se ha guardado como: %output_file%
echo.
echo Presiona cualquier tecla para abrir el archivo...
pause >nul

:: Abrir el archivo generado
start notepad "%output_file%"

echo.
echo Presiona cualquier tecla para salir...
pause >nul